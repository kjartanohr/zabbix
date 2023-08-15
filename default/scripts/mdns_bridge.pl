#!/usr/bin/perl

BEGIN {
  if ($ARGV[0] eq "--zabbix-test-run"){
    print "ZABBIX TEST OK";
    exit;
  }
}

use strict;
use IO::Socket::INET;
$0 = "perl NAME OF SCRIPT VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

our $debug         = 1;

use IO::Socket::INET;
 
# Send data immediately without buffering
$| = 1;
 
my ($socket,$data);
 
#  Create a new UDP socket
$socket = new IO::Socket::INET (
    LocalPort => 5353,
    #LocalAddr => "10.0.5.1",
    #PeerAddr => "224.0.0.251",
    Proto        => 'udp',
    #ReusePort => 1,
) or die "ERROR creating socket : $!\n";

my ($socket2, $data2);
$socket2 = new IO::Socket::INET (
    LocalAddr => "10.0.12.1",
    PeerPort => 5353,
    PeerAddr => "224.0.0.251",
    #LocalPort => "5353",
    #ReusePort => 1,
    Proto        => 'udp',
) or die "ERROR creating socket : $!\n";

my ($socket3, $data3);
$socket3 = new IO::Socket::INET (
    LocalAddr => "10.0.5.1",
    PeerPort => 5353,
    PeerAddr => "224.0.0.251",
    #LocalPort => "5353",
    #ReusePort => 1,
    Proto        => 'udp',
) or die "ERROR creating socket : $!\n";
 
my ($datagram,$flags);
while (1) {
    $socket->recv($datagram,5000,$flags);

    next if $socket->peerhost =~ /1$/;

    if ($socket->peerhost =~ /10\.0\.5\./) {
      print "IP: ".$socket->peerhost."\n";
      print $socket2 $datagram;
    }
    elsif ($socket->peerhost =~ /10\.0\.12\./) {
      print "IP: ".$socket->peerhost."\n";
      print $socket3 $datagram;
    }
}
 
$socket->close();
