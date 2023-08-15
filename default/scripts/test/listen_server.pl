#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
  }

use warnings;
use strict;

$0 = "perl mdns forward VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

  zabbix_check($ARGV[0]);

  our $debug         = 5;

  # Send data immediately without buffering
  $| = 1;

use Socket;
use Net::Pcap ;

my $sock;

socket($sock, PF_INET, SOCK_DGRAM, getprotobyname('udp'))   || die "socket: $!";
setsockopt($sock, SOL_SOCKET, SO_REUSEADDR, pack("l", 1))   || die "setsockopt: $!";
bind($sock, sockaddr_in(5353, inet_aton('10.0.12.1')))  || die "bind: $!";

# just loop forever listening for packets
while (1) {
    my $datastring = '';
    my $hispaddr = recv($sock, $datastring, 64, 0); # blocking recv
    if (!defined($hispaddr)) {
        print("recv failed: $!\n");
        next;
    }
    print "$datastring";
}
