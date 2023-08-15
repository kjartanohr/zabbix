#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;
use IO::Socket::INET;

$0 = "perl mdns forward VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

our $debug         = 5;

# Send data immediately without buffering
$| = 1;

#  Create a new UDP socket
print "start listening on UDP 5353 all interfaces\n" if $debug;

my $socket = new IO::Socket::INET (
    LocalPort => 5353,
    #LocalAddr => "224.0.0.251",
    #PeerAddr => "224.0.0.251",
    Proto        => 'udp',
    #ReusePort => 1,
    #Broadcast   => 1,
    MultiHomed    => 1,
) or die "ERROR creating socket : $!\n";
$socket->autoflush(1);

my ($socket2, $data2);
print "start socket on 10.0.12.1\n" if $debug;
$socket2 = new IO::Socket::INET (
    LocalAddr => "10.0.12.1",
    #PeerPort => 5355,
    PeerAddr => "224.0.0.251",
    #LocalPort => "5353",
    #ReusePort => 1,
    Proto        => 'udp',
) or die "ERROR creating socket : $!\n";

my ($socket3, $data3);
print "start socket on 10.0.5.1\n" if $debug;
$socket3 = new IO::Socket::INET (
    LocalAddr => "10.0.5.1",
    #PeerPort => 5355,
    PeerAddr => "224.0.0.251",
    #LocalPort => "5353",
    #ReusePort => 1,
    Proto        => 'udp',
) or die "ERROR creating socket : $!\n";

my ($datagram,$flags);

#my $cmd_tcpdump = qq#tcpdump -i any port 5353 and host 224.0.0.251 -w -#;
my $cmd_tcpdump = qq#tcpdump -i any port 5353  -w -#;
open my $fh_tcpdump, "-|", $cmd_tcpdump or die "Can't run $cmd_tcpdump: $!";

debug("data while 1", "debug", \[caller(0)] ) if $debug > 1;
DATA:
while (1) {
    print "waiting for datagram\n" if $debug > 1;
    #print Dumper $socket;
    #$socket->recv($datagram, 100);
    $datagram = readline $fh_tcpdump;

    next unless defined $datagram;

    #print "received: $datagram\n" if $debug > 1;

    if (0 and $socket->peerhost =~ /1$/) {
      print "skip: $datagram\n" if $debug > 1;
      next DATA;
    }

    #print "datagram: $datagram\n" if $debug > 1;
    my $safe = $datagram;
    $safe =~ s/\W/ /g;
    $safe =~ s/\s{2,}/ /g;
    print "datagram safe: $safe\n" if $debug > 1;

    #my $msg = "Source IP: ".$socket->peerhost.substr($safe, 0, 100)."\n";
    #print "msg: $msg\n" if $debug > 1;

    #print to 10.0.5.0/24
    print $socket3 $datagram;

    #print to 10.0.12.0/24
    print $socket2 $datagram;

    next;

    if ($socket->peerhost =~ /10\.0\.5\./) {
      #print "DST: 10.0.12.0 $msg";
      print $socket2 $datagram;
    }
    #elsif ($socket->peerhost =~ /10\.0\.12\./) {
      #print "DST: 10.0.5.0 $msg";
      print $socket3 $datagram;
    #}
}

$socket->close();

