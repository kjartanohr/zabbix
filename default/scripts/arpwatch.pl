#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;
use Net::SMTP;

$0 = "perl start arpwatch VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

our $debug          = 0;
my $mail_to         = 'kjartan@kjartanohr.no';
my $mail_from       = 'checkpoint@kjartanohr.no';
my $file_arp        = "/tmp/arp.db";
my $file_arp_tmp    = "/tmp/arp.db.tmp";
my $file_mac        = "/var/arpwatch/ethercodes.dat";


#End of standard header

kill_old_version_running();

#fork a child and exit the parent
#Don't fork if $debug is true
unless ($debug){
  fork && exit;
}

#Closing so the parent can exit and the child can live on
#The parent will live and wait for the child if there is no close
#Don't close if $debug is true
unless ($debug) {
  close STDOUT;
  close STDIN;
  close STDERR;
}

#system "rpm -Uvh http://vault.centos.org/5.1/os/i386/CentOS/arpwatch-2.1a13-18.el5.i386.rpm";

#system "curl_cli -k https://linuxnet.ca/ieee/oui/ethercodes.dat -o /var/arpwatch/ethercodes.dat &>/dev/null";

my $date;

while (1) {
  foreach (get_new_arp()){
    my ($ip,$int,$mac) = split/,/;
    my $vendor = get_vendor_from_mac($mac);
    chomp ($date = `date +"%Y.%m.%d %H:%M"`);

    my $mail = <<"EOF";
From: $mail_from
To: $mail_to
Subject: new device $ip $int $mac $vendor

      ip address: $ip
ethernet address: $mac
 ethernet vendor: $vendor
            time: $date
EOF

    debug("Mail\n$mail\n");
    send_mail($mail);

  }
  sleep 10;
}


exit;
my $interfaces;
my $networks;

$networks   .= "-n \"$_\" " foreach get_networks();

my %int;
foreach (get_interfaces()) {
  s/\..*//;
  $int{$_} = 1;
}
$interfaces .= "-i \"$_\" " foreach keys %int;

my $cmd = qq#arpwatch $interfaces $networks -e '$mail_to' -s '$mail_from' 2>&1#;
debug("$cmd\n");
exit;

open my $cmd_r,"-|", $cmd or die "Can't run $cmd: $!\n";

my $start = 0;
my $data;

while (<$cmd_r>) {
  next if /arpwatch: bogon/;
  next if /unknown/;
  
  if (/timestamp: / && $data) {
    debug("From found and data in \$data\n");
    $start = 0;

    my ($ip)  = $data =~ /ip address: (.*)/;
    my ($mac) = $data =~ /ethernet address: (.*)/;
    my ($ven) = $data =~ /ethernet vendor: (.*)/;
    $ven      = "" unless $ven;

    my $subject = "Subject: new $ip $mac $ven";

    $data =~ s/Subject: .*/$subject/;

    debug("sending mail $data\n");
    send_mail($data);
    $data = "";
  }

  $start = 1 if /^From/;
  next unless $start;

  $data .= $_;

  
}

sub send_mail {
  my $mail = shift || die "Need some data to send email\n";

  my $smtp            = Net::SMTP->new('10.0.3.12', Timeout => 60);
  $smtp->mail($mail_from);
  $smtp->to($mail_to);

  $smtp->data();
  $smtp->datasend($mail);
  $smtp->dataend();

  $smtp->quit;
}

sub get_interfaces {
  my @return;
  my $data;

  foreach (`ip a`) {

    if (/^\d/ && $data) {
      {

      my $inet  = $data =~ /inet/;
      my $state = $data =~ /state UP/;
      my ($int) = $data =~ /^\d{1,}: (.*?)@/;
      next unless $inet;
      next unless $state;
      next unless $int;

      push @return, $int;
      }
      $data = "";
    }
    $data .= $_;

  }
  return @return;
}

sub get_networks {
  my @return;
  my $data;

  foreach (`ip a`) {
    if (/^\d/ && $data) {
      $data .= $_;

      next unless $data =~ /inet/;
      next unless $data =~ /state UP/;

      my ($net) = $data =~ /inet (.*?) brd/;
      next unless $net;

      push @return, $net;
      $data = "";

    }
    $data .= $_;

  }
  return @return;
}

sub get_arp {
  my $return;

  foreach (sort `ip neighbour`){
    chomp;
    my ($ip, $dev, $int, $lladdr, $mac, $state) = split/\s{1,}/;

    next unless $ip && $mac;

    $return .= "$ip,$int,$mac\n";
    
  }
  return $return;
}

sub get_new_arp {
  my $arp_cur = get_arp();
  my @return;

  unless (-f $file_arp) {
    open my $fh_w, ">", $file_arp or die "Can't write to $file_arp: $!\n";
    print $fh_w $arp_cur;
    close $fh_w;

    return $arp_cur; 
  }

  open my $fh_w, ">", $file_arp_tmp or die "Can't write to $file_arp_tmp: $!\n";
  print $fh_w $arp_cur;
  close $fh_w;

  foreach (`diff $file_arp $file_arp_tmp`) {
    next unless /^\>/;
    s/^\> //;
    chomp;
    
    push @return, $_;
  }

  return unless @return;

  my $arp_db = `cat $file_arp $file_arp_tmp | sort -u`;
  open my $fh_w_db, ">", $file_arp or die "Can't write to $file_arp: $!\n";
  print $fh_w_db $arp_db;
  close $fh_w;

  return @return;

}

sub get_vendor_from_mac {
  my $mac = shift || die "Need a MAC address to lookup\n";

  my ($mac_vendor) = $mac =~ /(.{8})/;
  my $mac_vendor_uc = uc $mac_vendor;

  open my $fh_r, "<", $file_mac or die "Can't open $file_mac: $!\n";

  foreach (<$fh_r>) {
    my ($mac, $name) = split/\x09/;
    $name =~ s/^\s{1,}//;

    #print "MAC $mac, NAME $name\n";
    #print "\"$mac\" eq \"$mac_vendor_uc\"\n";
    
    if ($mac eq $mac_vendor_uc) {
      chomp $name;
      return $name;
    }
  }
}
