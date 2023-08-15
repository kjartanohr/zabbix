#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;

$0 = "perl nmap VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

my $dir_tmp         = "/tmp/zabbix/nmap";
our $file_debug     = "$dir_tmp/debug.log";
our $debug          = 0;

create_dir($dir_tmp);

#Delete log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);


#End of standard header

foreach my $net (@ARGV) {
  foreach my $i (1 .. 254){
    fork && next;
    my $ip_msg;
    my $dns_msg;
    my $mac_msg;

    my $msg;
    my $ip = "$net.$i";
    debug("IP: $ip ");

    my $found = 0;
    my $out_ping = `ping -W1 -c1 $ip `;

    if ($out_ping =~ /100% packet loss/){
      debug("FAILED");
    }
    else {
      $ip_msg = "IP: $ip";
      debug("OK");
    }

    my $cmd = qq#dig -x $ip#;
    my $out = `$cmd`;
    if ($out =~ /status: NOERROR/){
      my ($name) = $out =~ /PTR\s{1,}(.*?)\./;
      $dns_msg = "DNS: $name"
    }

    my $mac = get_mac($ip);
    $mac_msg .= "MAC: $mac " if $mac;

    if ($ip_msg or $dns_msg or $mac_msg) {
      $ip_msg ||= "IP: $ip";
      $dns_msg ||= "";
      $mac_msg ||= "";

      $msg .= "$ip_msg";
      $msg .=  ", $dns_msg" if $dns_msg;
      $msg .=  ", $mac_msg" if $mac_msg;
      $msg .= "\n";
      print $msg;
      debug($msg);


    }
    exit;
  }
}

sub get_mac {
  my $input_ip  = shift || return;
  my $arp = `ip nei`;

  #10.201.100.20 dev bond1.902 lladdr 2c:5a:0f:c1:84:fe REACHABLE

  my ($ip, $dev, $int, $lladdr, $mac, $status) = split/\s{1,}/, $arp;
  return unless $status;
  return unless $mac =~ /:/;

  if ($input_ip eq $ip) {
    return $mac;
  }
}

