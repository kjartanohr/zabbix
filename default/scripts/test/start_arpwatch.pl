#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;
use Net::SMTP;
use Data::Dumper;

$0 = "perl start arpwatch VER 100";
$|++;
$SIG{CHLD} = "IGNORE";
$SIG{INT} = \&ctrl_c;

zabbix_check($ARGV[0]);

#Get default config
our %config                     = get_config();



our $debug          = 0;
my $fork            = 0;
my $mail_to         = 'kjartan@kjartanohr.no';
my $mail_from       = 'checkpoint@kjartanohr.no';
my $file_arp        = "/tmp/arp.db";
my $file_arp_tmp    = "/tmp/arp.db.tmp";
my $file_mac        = "/var/arpwatch/ethercodes.dat";
my $file_stats      = "/tmp/arp_stats.db";
my $arp_time        = 10;

#log config
$config{'log'}{'debug'}       = {
  "enabled"       => 1,     #0/1
  "level"         => 1,     #0-9
  "print"         => 1,     #Print to STDOUT
  "log"           => 0,     #Save to log file
  "die"           => 0,     #Die/exit if this type of log is triggered
};
$config{'log'}{'info'}       = {
  "enabled"       => 1,     #0/1
  "level"         => 9,     #0-9
  "print"         => 1,     #Print to STDOUT
  "log"           => 1,     #Save to log file
};
$config{'log'}{'warning'}       = {
  "enabled"       => 1,     #0/1
  "level"         => 9,     #0-9
  "print"         => 1,     #Print to STDOUT
  "log"           => 1,     #Save to log file
};
$config{'log'}{'error'}       = {
  "enabled"       => 1,     #0/1
  "level"         => 9,     #0-9
  "print"         => 1,     #Print to STDOUT
  "log"           => 1,     #Save to log file
};
$config{'log'}{'fatal'}       = {
  "enabled"       => 1,     #0/1
  "level"         => 9,     #0-9
  "print"         => 1,     #Print to STDOUT
  "log"           => 1,     #Save to log file
  "die"           => 1,     #Die/exit if this type of log is triggered
};



#legacy debug on/off
$debug = $config{'log'}{'debug'}{'level'} if $config{'log'}{'debug'}{'enabled'};

$config{'config'}       = {
  "skip-ipv6"       => 1,     #0/1
};



my %stats;
$stats{'stats'}{'saved_time'} = time;
$stats{'stats'}{'save_every'} = 10;
$stats{'stats'}{'ping-startup'} = 0;
$stats{'stats'}{'ping_every'} = 5;
$stats{'stats'}{'ping_time'}  = time;
$stats{'stats'}{'ping_ignore_after'}  = 10; #Min. Don't ping this IP if it has not answered the last N min
$stats{'stats'}{'ping-ignore-send-mail'}  = 1;
$stats{'stats'}{'ignore-ip'}    = "";
$stats{'stats'}{'ignore-mac'}   = "";
#$stats{'stats'}{'ignore-int'}   = "bond1.104";
$stats{'stats'}{'ignore-int'}   = "^eth0";

stats_get(\%stats);

#End of standard header

#fork a child and exit the parent
#Don't fork if $debug is true
if ($debug == 0 and $fork == 1){
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

#CHeck if the remote file is updated
#system "curl_cli -k https://linuxnet.ca/ieee/oui/ethercodes.dat -o /var/arpwatch/ethercodes.dat &>/dev/null";

my $date;

while (1) {
  foreach (get_new_arp()){
    debug("foreach get_new_arp(): '$_'", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
    my ($ip,$int,$mac) = split/,/;
    #chomp ($date = `date +"%Y.%m.%d %H:%M"`);
    $date = get_date_time();

    send_mail($ip,$int,$mac);

  }
  if ($stats{'stats'}{'ping-startup'} == 0 or time - $stats{'stats'}{'ping_time'} > $stats{'stats'}{'ping_every'}*60) {
    debug("Time to ping all", 'info', \[caller(0)]) if $config{'log'}{'info'}{'enabled'} and $config{'log'}{'info'}{'level'} > 1;
    $stats{'stats'}{'ping-startup'} = 1;
    ping_all();
    $stats{'stats'}{'ping_time'} = time;
  }

  #send_error_mail();

  sleep $arp_time;
}


sub send_mail {
  debug("start", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 2;

  my $ip      = shift;
  my $int     = shift;
  my $mac     = shift;
  my $vendor  = get_vendor_from_mac($mac);

  unless ($ip and $int and $mac) {
    debug("Missing input", 'fatal', \[caller(0)]) if $config{'log'}{'fatal'}{'enabled'} and $config{'log'}{'fatal'}{'level'} > 1;
    return;
  }

  my $mail = <<"EOF";
From: $mail_from
To: $mail_to
Subject: new device $ip $int $mac $vendor

      ip address: $ip
ethernet address: $mac
 ethernet vendor: $vendor
            time: $date
EOF

  debug("mail: $mail", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

  my $smtp            = Net::SMTP->new('kjartanohr.no', Timeout => 60);
  $smtp->mail($mail_from);
  $smtp->to($mail_to);

  $smtp->data();
  $smtp->datasend($mail);
  $smtp->dataend();

  $smtp->quit;

  my $smtp_nr            = Net::SMTP->new(
    '10.0.12.7',
    #'Host' => '10.0.12.7',
    'Port' => 1025,
    'Timeout' => 60,
  );
  print Dumper $smtp_nr;

  $smtp_nr->mail($mail_from);
  $smtp_nr->to($mail_to);

  $smtp_nr->data();
  $smtp_nr->datasend($mail);
  $smtp_nr->dataend();

  $smtp_nr->quit;

}

sub get_interfaces {
  debug("start", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 2;
  my @return;
  my $data;

  my @out_ip_a = run_cmd({
    'cmd'             => 'ip a',
    'return-type'     => 'a',
    'refresh-time'    => 1*60*60,
    'timeout'         => 10,
  });

  foreach (@out_ip_a) {

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
  debug("start", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 2;
  my @return;
  my $data;

  my @out_ip_a = run_cmd({
    'cmd'             => 'ip a',
    'return-type'     => 'a',
    'refresh-time'    => 1*60*60,
    'timeout'         => 10,
  });


  foreach (@out_ip_a) {
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
  debug("start", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 2;
  my $return;

  my @out_ip_nei = `ip neighbour`;

  if (@out_ip_nei < 10){
      debug("\@out_ip_nei is less than 10 lines. something is wrong.".Dumper(@out_ip_nei), 'error', \[caller(0)]) if $config{'log'}{'error'}{'enabled'} and $config{'log'}{'error'}{'level'} > 1;
  }
  #my @out_ip_nei = run_cmd({
  #  'cmd'             => 'ip neighbour',
  #  'return-type'     => 'a',
  #  'refresh-time'    => 1,
  #  'timeout'         => 10,
  #});

  foreach (sort @out_ip_nei){
    chomp;
    debug("\@out_ip_nei: \$_: '$_'", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 3;

    if (/(FAILED|INCOMPLETE|STALE)$/){
      debug("$1 found in line. next", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 2;
      next;
    }

    my %ip_nei;
    #fe80::4456:afff:fea0:3b40 dev bond1.105 lladdr 46:56:af:a0:3b:40 STALE
    ($ip_nei{'ip'}, $ip_nei{'dev'}, $ip_nei{'int'}, $ip_nei{'lladdr'}, $ip_nei{'mac'}, $ip_nei{'state'}) = split/\s{1,}/;

    if ($config{'config'}{'skip-ipv6'} and $ip_nei{'ip'} =~ /^fe\d\d::/) {
      debug("IPv6 found. Skipping. \$ip: '$ip_nei{'ip'}'. \$_: '$_'", 'info', \[caller(0)]) if $config{'log'}{'info'}{'enabled'} and $config{'log'}{'info'}{'level'} > 1;
      next;
    }

    if ($ip_nei{'int'} =~ /$stats{'stats'}{'ignore-int'}/) {
      debug("Ignore INT. $ip_nei{'int'} found in int ignore. Skipping. \$_: '$_'", 'info', \[caller(0)]) if $config{'log'}{'info'}{'enabled'} and $config{'log'}{'info'}{'level'} > 1;
      next;
    }

    my @validate_keys = qw( ip dev int lladdr mac state );
    foreach my $validate_key (@validate_keys) {

      if (defined $ip_nei{$validate_key}) {
        debug("validate db data success. $validate_key is found", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 3;

      }
      else {
        debug("validate db data FAILED. $validate_key is not found in ".Dumper(%ip_nei), 'error', \[caller(0)]) if $config{'log'}{'error'}{'enabled'} and $config{'log'}{'error'}{'level'} > 1;
        next;
      }
    }

    stats_update("$ip_nei{'ip'}-$ip_nei{'mac'}", $ip_nei{'ip'}, $ip_nei{'mac'}, "arp");


    $return .= "$ip_nei{'ip'},$ip_nei{'int'},$ip_nei{'mac'}\n";

  }
  return $return;
}

sub get_new_arp {
  debug("start", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 2;
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
  debug("start", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 2;
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


sub ping {
  debug("start", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 2;
  my $ip  = shift;
  my $mac = shift;

  unless ($ip) {
    debug("Need IP address to ping", 'fatal', \[caller(0)]) if $config{'log'}{'fatal'}{'enabled'} and $config{'log'}{'fatal'}{'level'} > 1;
    return;
  }
  debug("input ip: $ip", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

  unless ($mac) {
    debug("missing input \$mac", 'fatal', \[caller(0)]) if $config{'log'}{'fatal'}{'enabled'} and $config{'log'}{'fatal'}{'level'} > 1;
    return;
  }
  debug("\$mac: '$mac'", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

  my $int = get_interface_for_ip($ip);

  unless ($int) {
    debug("missing data from get_interface_for_ip()", 'fatal', \[caller(0)]) if $config{'log'}{'fatal'}{'enabled'} and $config{'log'}{'fatal'}{'level'} > 1;
    return;
  }
  debug("Resolved interface $int", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

  my $cmd_arping = "arping -b -f -w 2 -I $int $ip 2>&1";
  debug("CMD: $cmd_arping", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

  #my $out_arping = `$cmd_arping`;
  my $out_arping = run_cmd({
    'cmd'             => $cmd_arping,
    'return-type'     => 's',
    'refresh-time'    => 10,
    'timeout'         => 3,
  });

  debug("\$out_arping: $out_arping", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

  if ($out_arping =~ /unknown host/) {
      debug("unknown host from arping. return 3. \$cmd_arping: '$cmd_arping'. \$out_arping: $out_arping", 'error', \[caller(0)]) if $config{'log'}{'error'}{'enabled'} and $config{'log'}{'error'}{'level'} > 1;
      return 3;
  }


  my ($response) = $out_arping =~ /Received (\d{1,}) response/;

  unless (defined $response) {
    debug("Could not parse arp output. \$cmd_arping: '$cmd_arping'. \$out_arping: $out_arping", 'fatal', \[caller(0)]) if $config{'log'}{'fatal'}{'enabled'} and $config{'log'}{'fatal'}{'level'} > 1;
    return;
  }

  if ($response == 0) {
    debug("Received 0 response(s)", 'info', \[caller(0)]) if $config{'log'}{'info'}{'enabled'} and $config{'log'}{'info'}{'level'} > 1;
    #debug("Received 0 response(s) $out_arping", 'info', \[caller(0)]) if $config{'log'}{'info'}{'enabled'} and $config{'log'}{'info'}{'level'} > 1;
    return 0;
  }
  if ($response > 0) {
    debug("Received response(s) $out_arping", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 0;

    my ($out_mac) = $out_arping =~ / \[(.*?)\] /;
    unless ($out_mac) {
      debug("Could not extract MAC adress from: $out_arping", 'fatal', \[caller(0)]) if $config{'log'}{'fatal'}{'enabled'} and $config{'log'}{'fatal'}{'level'} > 1;
      return 0;
    }
    $mac = lc $mac;
    $out_mac = lc $out_mac;

    if ($out_mac eq $mac) {
      debug("Found matching MAC address. arping MAC $out_mac == $mac", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
      return 1;
    }
    else {
      debug("Could not find matching MAC address arping MAC $out_mac == $mac", 'warning', \[caller(0)]) if $config{'log'}{'warning'}{'enabled'} and $config{'log'}{'warning'}{'level'} > 1;
      return 0;
    }
  }
  else {
    debug("Something is wrong with the output from arping: $out_arping", 'fatal', \[caller(0)]) if $config{'log'}{'fatal'}{'enabled'} and $config{'log'}{'fatal'}{'level'} > 1;
    return 0;
  }
  debug("I should not be here", 'fatal', \[caller(0)]) if $config{'log'}{'fatal'}{'enabled'} and $config{'log'}{'fatal'}{'level'} > 1;
}

sub get_interface_for_ip {
  debug("start", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 2;
  my $ip = shift || return;

  unless ($ip) {
    debug("Missing input \$ip. \@_: ".Dumper(@_), 'fatal', \[caller(0)]) if $config{'log'}{'fatal'}{'enabled'} and $config{'log'}{'fatal'}{'level'} > 1;
    return;
  }

  my $cmd_ip_route = "ip route get $ip";

  my $out_ip_route = run_cmd({
    'cmd'             => $cmd_ip_route,
    'return-type'     => 's',
    'refresh-time'    => 1*60*60,
    'timeout'         => 10,
  });


  my ($int) = $out_ip_route =~ /dev (.*?) /;

  unless ($int) {
    debug("Could not extract interface from $out_ip_route", 'fatal', \[caller(0)]) if $config{'log'}{'fatal'}{'enabled'} and $config{'log'}{'fatal'}{'level'} > 1;
    return;
  }

  return $int;
}

sub stats_update {
  debug("start", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 2;
  my $id      = shift;
  my $ip      = shift;
  my $mac     = shift;
  my $action  = shift;

  my $save_db = 0;

  debug("INPUT. ID $id, IP $ip, MAC $mac, Action $action", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 2;

  unless ($id and $ip and $mac and $action) {
    debug("Missing input data", 'fatal', \[caller(0)]) if $config{'log'}{'fatal'}{'enabled'} and $config{'log'}{'fatal'}{'level'} > 1;
    return;
  }

  unless ($stats{$id}) {
    debug("New ID found. Creating new ID in hash: $id, $ip, $mac", 'info', \[caller(0)]) if $config{'log'}{'info'}{'enabled'} and $config{'log'}{'info'}{'level'} > 1;

    $save_db = 1;

    $stats{$id} = {
      "id"                => $id,
      "ip"                => $ip,
      "mac"               => $mac,
      "arp-count"         => 0,
      "arp-count"         => 0,
      "arp-mtime"         => time,
      "arp-ctime"         => time,
      "ping-ignore"       => 0,
      "ping-time"         => time,
      "ping-ok-count"     => 0,
      "ping-ok-mtime"     => 0,
      "ping-failed-count" => 0,
      "ping-failed-mtime" => 0,
      "mail"              => 1,
      "mtime"             => time,
      "ctime"             => time,
    };
  }

  $stats{$id}{'mtime'}            = time;
  $stats{$id}{"$action-mtime"}    = time;
  $stats{$id}{"$action-count"}   += 1;

  if ($stats{$id}{"$action-count"} > 1_000_000) {
    debug("Count is more than 1 mill, count mill ++ and count = 0", 'warning', \[caller(0)]) if $config{'log'}{'warning'}{'enabled'} and $config{'log'}{'warning'}{'level'} > 1;
    $stats{$id}{"$action-count-million"}++;
    $stats{$id}{"$action-count"}  = 0;
  }

  if ($save_db or time - $stats{'stats'}{'saved_time'} > ($stats{'stats'}{'save_every'}*60)) {
    debug("Time to save hash to file", 'info', \[caller(0)]) if $config{'log'}{'info'}{'enabled'} and $config{'log'}{'info'}{'level'} > 1;
    write_hash(\%stats,$file_stats);
    $stats{'stats'}{'saved_time'} = time;
  }

  if ($action eq "arp" and $stats{$id}{'ping-ignore'} == 1) {
    debug("ID $id found in arp. Setting ping-ignore to 0", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
    $stats{$id}{'ping-ignore'}    = 0;
  }


  if (0 and $debug == 3) {
    debug(((caller(0))[3])." Updated data added to hash\n");
    foreach my $key (keys %{$stats{$id}}) {
      my $value = $stats{$id}{$key};
      debug(((caller(0))[3])." ID $id $key $value\n");
    }

  }

}

sub ping_all {
  debug("start", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 2;

  foreach my $id (keys %stats) {

    next if $id eq "stats";

    if ($stats{$id}{'ping-ignore'}) {
      debug("ID $id has ping-ignore. Skipping", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
      next;
    }

    my @validate_keys = qw( ip mac );
    foreach my $validate_key (@validate_keys) {

      if (defined $stats{$id}{$validate_key}) {
        debug("validate db data success. $validate_key is found in %stats. $stats{$id}{$validate_key}", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 3;

      }
      else {
        debug("validate db data FAILED. $validate_key is not found in %stats. \$id: '$id'. \$stats{$id}: ".Dumper($stats{$id}), 'error', \[caller(0)]) if $config{'log'}{'error'}{'enabled'} and $config{'log'}{'error'}{'level'} > 1;
        next;
      }

    }

    $stats{$id}{'ping-time'} = time;

    my $ping = ping($stats{$id}{'ip'},$stats{$id}{'mac'});

    if ($ping == 3) {
      debug("ping() returned status 3. deleting id from database", 'error', \[caller(0)]) if $config{'log'}{'error'}{'enabled'} and $config{'log'}{'error'}{'level'} > 1;
      delete $stats{$id};
      next;
    }

    if ($ping) {
      $stats{$id}{'ping-ok-count'}++;
      $stats{$id}{'ping-ok-total-count'}++;
      $stats{$id}{'ping-ok-mtime'}  = time;
      $stats{$id}{'ping-ignore'}    = 0;
      debug("ID $id ping OK", 'info', \[caller(0)]) if $config{'log'}{'info'}{'enabled'} and $config{'log'}{'info'}{'level'} > 1;
    }
    else {
      $stats{$id}{'ping-failed-count'}++;
      $stats{$id}{'ping-failed-total-count'}++;
      $stats{$id}{'ping-failed-mtime'} = time;
      debug("ID $id ping FAILED. Ping failed count: $stats{$id}{'ping-failed-count'}", 'info', \[caller(0)]) if $config{'log'}{'info'}{'enabled'} and $config{'log'}{'info'}{'level'} > 1;
    }

    if (time - $stats{$id}{'ping-ok-mtime'} > $stats{'stats'}{'ping_ignore_after'}*60) {
      debug("ID $id has not answered in a while. Setting ping ignore", 'warning', \[caller(0)]) if $config{'log'}{'warning'}{'enabled'} and $config{'log'}{'warning'}{'level'} > 1;
      $stats{$id}{'ping-ignore'} = 1;
      next;
    }
  }

}

sub stats_get {
  debug("start", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 2;
  my $hash_ref  = shift || die "sub write_hash. Need a hash ref\n";
  my $id_input  = shift;

  if ($id_input) {
    debug("Found input ID: $id_input. Returning data for this ID", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
    my $found = $stats{$id_input};

    unless ($found) {
      debug("Could not find any match for this ID $id_input", 'info', \[caller(0)]) if $config{'log'}{'info'}{'enabled'} and $config{'log'}{'info'}{'level'} > 1;
      return;
    }

    my %found = stats_to_hash($found);
    return $found;
  }

  unless (-f $file_stats) {
    debug("Could not find file $file_stats", 'fatal', \[caller(0)]) if $config{'log'}{'fatal'}{'enabled'} and $config{'log'}{'fatal'}{'level'} > 1;
    return;
  }

  open my $fh_stats_r, "<", $file_stats or die "Can't read $file_stats: $!";
  LINE:
  while (<$fh_stats_r>) {
    chomp;

    my $id;
    foreach my $data (split/;;;;/) {

      if ($config{'config'}{'skip-ipv6'} and $data =~ /fe\d\d::/) {
        debug("IPv6 found. Skipping", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
        next LINE;
      }

      my ($key, $value) = split/::::/, $data;

      if (length $key == 0) {
        debug("\$key is length == 0. \$data: $data", 'error', \[caller(0)]) if $config{'log'}{'error'}{'enabled'} and $config{'log'}{'error'}{'level'} > 1;
        next LINE;
      }

      if (length $value == 0) {
        debug("\$value is length == 0. \$data: $data", 'error', \[caller(0)]) if $config{'log'}{'error'}{'enabled'} and $config{'log'}{'error'}{'level'} > 1;
        next LINE;
      }


      if ($key eq "id") {
        $id = $value;
        next;
      }
      #next LINE if $id eq "stats";

      $$hash_ref{$id}{$key} = $value;
    }
  }
  #delete $$hash_ref{'stats'};
  #print Dumper $hash_ref;

  #validate db data
  #my @validate_keys = qw( arp-mtime arp-ctime mtime ip ping-failed-mtime ctime mail ping-time ping-ok-count mac ping-ok-mtime arp-count ping-failed-count ping-ignore  );
  my @validate_keys = qw( ip ctime ping-time ping-ok-count mac arp-count );
  foreach my $stats_key (keys %{$hash_ref}){

    next if $stats_key eq "stats";

    #print "\$stats_key: '$stats_key'. ".Dumper($$hash_ref{$stats_key});

    foreach my $validate_key (@validate_keys) {

      if (defined $$hash_ref{$stats_key}{$validate_key}) {
        debug("validate db data success. $validate_key is found in %stats", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 3;

      }
      else {
        debug("validate db data FAILED. $validate_key is not found in %stats.: ".Dumper($$hash_ref{$stats_key}), 'error', \[caller(0)]) if $config{'log'}{'error'}{'enabled'} and $config{'log'}{'error'}{'level'} > 1;
        exit;
      }
    }
  }



}

sub write_hash {
  debug("start", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 2;
  my $hash_ref  = shift || die "sub write_hash. Need a hash ref\n";
  my $filename  = shift || die "sub write_hash. Need a fileame\n";

  if (-f $filename) {
    rename $filename, "$filename.old" or die "Can't rename $filename -> $filename.old";
  }

  open my $fh_stats_w, ">", $filename or die "Can't read $filename: $!";

  while (my ($id, $hash) = each %$hash_ref) {
    my $line = "id::::$id;;;;";

    while (my ($key,$value) = each %$hash ) {
      $line .= $key."::::".$value.";;;;";
    }

    debug("Will write line $line to file", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 3;
    print $fh_stats_w "$line\n";

  }
  close $fh_stats_w;
}

sub stats_to_hash {
  debug("start", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 2;
  my $data = shift;

  unless ($data) {
    debug("Missing input data \$data", 'fatal', \[caller(0)]) if $config{'log'}{'fatal'}{'enabled'} and $config{'log'}{'fatal'}{'level'} > 1;
    return;
  }

  my ($id, $ip, $mac, $found_arp, $found_arp_mtime, $ping_ok_count, $ping_ok_count_mtime, $ping_nok_count, $ping_nok_count_mtime, $mtime, $ctime) = split/;;;;/, $data;

  my %data;
  $data{'id'}                    = $id;
  $data{'ip'}                    = ip$;
  $data{'mac'}                   = $mac;
  $data{'found_arp'}             = $found_arp;
  $data{'found_arp_mtime'}       = $found_arp_mtime;
  $data{'ping_ok_count'}         = $ping_ok_count;
  $data{'ping_ok_count_mtime'}   = $ping_ok_count_mtime;
  $data{'ping_nok_count'}        = $ping_nok_count;
  $data{'ping_nok_count_mtime'}  = $ping_nok_count_mtime;
  $data{'mtime'}                 = $mtime;
  $data{'ctime'}                 = $ctime;

  return %data;
}

sub ctrl_c {
  debug("start", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 2;
  write_hash(\%stats,$file_stats);
  exit;

}

sub send_error_mail {
  debug("start", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 2;

  foreach my $id (keys %stats) {
    foreach my $key (keys %{$stats{$id}}) {
      my $value = $stats{$id}{$key};
      debug(((caller(0))[3])." ID $id $key $value\n");


    }

  }

}



sub get_date_time {
  #debug("start", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  my $time = time();
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
  my $timestamp = sprintf ( "%04d-%02d-%02d %02d:%02d:%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec);
  return $timestamp;
}

