#!/bin/perl

#Set the path for modules
BEGIN{push @INC,"/usr/share/zabbix/bin/perl-5.10.1/lib"}

#TODO
#Sjekk først at GW er active med cphaprob state
#Sjekk så at BGP er Established

#use warnings;
use Fcntl qw(:flock SEEK_END); #Module for file lock 

#Print the data immediately. Don't wait for full buffer
$|++;

#Zabbix test that will have to print out zabbix test ok. If not, the script will not download
if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

#Exit unless BGP is running
#Print the input the script is started with
debug("$0 Input data ".join " ",@ARGV);

$debug             = 0;                                                            #Set to 1 if you want debug data and no fork
$version           = 100;                                                          #Version of the script. If the version runnin is older than this, kill the old script
$0                 = "show bgp peers VER $version";                                #Set the process name
$cmd               = 'clish -c "show bgp peers"';                                  #fw ctl debug command
$configuration     = "";

unless (`grep "bgp on" /etc/routed0.conf 2>/dev/null`){
  debug("BGP is not running. Exiting");
  exit;
}


#Run the command and loop every line
foreach (`$cmd`){

  #Print debug 
  debug("$_");

  #Remove all space in the beginning of the line
  s/^s\{1,}//;

  #Split line in to variables
  #PeerID           AS           Routes  ActRts  State             InUpds  OutUpds  Uptime
  ($peerid,$as,$routes,$actrts,$state,$inupds,$outupds,$uptime) = split/\s{1,}/;

  #Skip unless $peerid is an IP-address
  next unless $peerid =~ /^\d/;

  #Skip where state is Established
  next if $state eq "Established";

  #Get configuration. Running down here only if there is a bgp peer down
  unless ($configuration) {
    $configuration     = `clish -c "show configuration"` 
  }

  #Get peer comment
  ($comment) = get_peer_comment($peerid);

  #Skip if comment is "NA$"
  next if $comment =~ /NA$/; 

  #Print to zabbix
  print "State: $state, PeerID: $peerid, AS: $as $comment\n";
}


sub debug {
  print "DEBUG: $_[0]\n" if $debug;
}

sub get_peer_comment {
  $peer          = shift or die "Need a PEER ID to fetch a comment";
  
  ($comment) = $configuration =~ /peer $peer comment (.*)/;
  $comment =~ s/"//g;
  $comment =~ s/ /-/g;

  return $comment;
 
}





__DATA__



[Expert@tv2-cp-fw6-1:0]# clish -c "show bgp peers"
CLINFR0771  Config lock is owned by admin. Use the command 'lock database override' to acquire the lock.

Flags: R - Peer restarted, W - Waiting for End-Of-RIB from Peer

PeerID           AS           Routes  ActRts  State             InUpds  OutUpds  Uptime
10.90.254.107    65333        16      16      Established       17      14       5d23h
10.90.254.108    65333        16      0       Established       17      14       5d23h
10.91.231.6      65401        69      69      Established       70      12       5d23h
10.91.231.14     65401        68      0       Established       68      12       5d23h
10.207.255.62    65500        3       3       Established       2       3        3d13h
[Expert@tv2-cp-fw6-1:0]# cphaprob^C
[Expert@tv2-cp-fw6-1:0]# cphaprob state

Cluster Mode:   High Availability (Active Up) with IGMP Membership

ID         Unique Address  Assigned Load   State          Name

1          10.90.1.146     0%              STANDBY        tv2-cp-fw6-2
2 (local)  10.90.1.145     100%            ACTIVE         tv2-cp-fw6-1


Active PNOTEs: None

Last member state change event:
   Event Code:                 CLUS-114904
   State change:               ACTIVE(!) -> ACTIVE
   Reason for state change:    Reason for ACTIVE! alert has been resolved
   Event time:                 Fri Mar 11 09:38:04 2022

Last cluster failover event:
   Transition to new ACTIVE:   Member 1 -> Member 2
   Reason:                     Reboot
   Event time:                 Fri Mar 11 09:37:02 2022

Cluster failover count:
   Failover counter:           5
   Time of counter reset:      Thu Aug 19 00:03:13 2021 (reboot)


[Expert@tv2-cp-fw6-1:0]#

