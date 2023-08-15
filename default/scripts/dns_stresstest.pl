#!/usr/bin/perl5.32.0
#bin
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;
use Parallel::ForkManager;
use Net::DNS;

$0 = "perl dns stresstest VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

my $file_dns = "/usr/share/zabbix/repo/files/auto/domain_list_500.txt";

 
my $pm = Parallel::ForkManager->new(100);
 
my @dns = readfile($file_dns,"a");
DATA_LOOP:
while (@dns) {

  my @dns_fork;
  foreach (1 .. 100){
    last unless $_;
    push @dns_fork, shift @dns;
  }

  # Forks and returns the pid for the child:
  my $pid = $pm->start and next DATA_LOOP;
 
  my $res   = Net::DNS::Resolver->new;

  foreach my $dns (@dns_fork) {
    chomp $dns;
    my $reply = $res->search($dns, "A");

    if ($reply) {
      foreach my $rr ($reply->answer) {
        print "$dns ".$rr->address, "\n" if $rr->can("address");
      }
    } 
    else {
      warn "$dns query failed: ", $res->errorstring, "\n";
    }
  }
 
  $pm->finish; # Terminates the child process
}
