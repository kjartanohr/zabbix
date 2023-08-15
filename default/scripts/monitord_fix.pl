#!/bin/perl
BEGIN{push @INC,"/usr/share/zabbix/bin/perl-5.10.1/lib"}

use warnings;
use strict;

$0 = "perl monitord fix";
$|++;

if (defined $ARGV[0] && $ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

my $debug = 0;
my $high_cpu = 0;

foreach (`top -b -n 4`){
  #Remove whitespace in the beginning of the line
  s/^\s{1,}//;

  #Remove new line in the end of the line
  chomp;

  #Split the line in to an array. Split char is 1 og more whitespace
  my @line = split/\s{1,}/;

  #Skip if process name is not monitord
  next unless $line[11] && $line[11] eq "monitord";

  print "All lines with the process monitord $_\n" if $debug;

  #Skip if CPU usage is not more than 40%
  next unless $line[8] && $line[8] > 40;

  print "After CPU higher than 40 $_\n" if $debug;

  #+1 if the CPU usage is high
  $high_cpu++; 

  #If monitord is running high on all the top checks. Kill it
  #The first CPU output from top will sometimes show 0 CPU usage for the process. 
  if ($high_cpu >= 3) {

    print "Killing Process $line[11] PID $line[0] CPU $line[8]\n";  

    #killing the monitord process the correct check point way SK101141
    system "tellpm process:monitord &>/dev/null"; 
  }

}
