#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;
use IO::Socket::INET;

my $cmd_tcpdump = "tcpdump -e -w - -U -s 0 --dont-verify-checksums --immediate-mode -i bond1.112 not net 10.0.5.0/24 and not net 10.0.6.0/24 and not port 5353 and not host 10.0.12.252 and not host 10.0.12.8 and not icmp and not port 123 and not arp and not broadcast and not multicast| nc 10.0.12.252 3333";

my $cmd_nc_test = "echo test | nc --tcp 10.0.12.252 3333";

while (1) {
  my $start = 0;
  sleep 1;

  #eval {
  #  local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
  #  alarm 2;
  #  system $cmd_nc_test;
  #  alarm 0;
  #};

  #if ($@) {
  #  print "port open\n";
  #  $start = 1;
  #}
  #else {
  #  print "port not listening\n";
  #}


  #next unless $start;
  system $cmd_tcpdump;


}
