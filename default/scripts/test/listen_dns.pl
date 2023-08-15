#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;
use IO::Socket::INET;

$0 = "perl DNS listener VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

our $debug         = 1;

use IO::Socket::INET;

# Send data immediately without buffering
$| = 1;


my $socket = new IO::Socket::INET (
    LocalPort => 53,
    Proto     => 'udp',
) or die "ERROR creating socket : $!\n";


my ($datagram,$flags);
while (1) {
  $socket->recv($datagram,1024);

  print "Data: $datagram\n";
  next;

  my $safe = $datagram;
  $safe =~ s/\W/ /g;
  $safe =~ s/\s{2,}/ /g;

  my $msg = "Source IP: ".$socket->peerhost.substr($safe, 0, 100)."\n";


}

$socket->close();
