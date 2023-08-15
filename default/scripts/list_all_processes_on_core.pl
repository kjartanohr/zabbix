#!/usr/bin/perl5.32.0
#bin
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;

$0 = "perl NAME OF SCRIPT VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

my %history;

zabbix_check($ARGV[0]);

my $core_input = shift @ARGV;

unless (defined $core_input and $core_input =~ /\d/) {
  print "Press ENTER to show all processes on all cores\n";
  print "List process on core: ";
  chomp($core_input = <>); 
}

unless ($core_input =~ /\d/) {
  system "ps -o psr,pid,command -A|sort -n";
  exit;
}

while (1) {

  system "clear";

  foreach (`ps -o psr,pid,command -A`) {
    s/^\s{1,}//; 
  
    my ($core, $pid) = split /\s{1,}/; 
  
    next unless $core =~ /\d/;
    next unless $core == $core_input; 
  
    print; 
  
    s/\d{1,}.*?\d{1,}\s//;
  
    $history{$_} = 1;
  }
  
  print "\n\nHistory\n";
  foreach (sort keys %history) {
    chomp; 
    print "$_, ";
  }

  sleep 2;
}
