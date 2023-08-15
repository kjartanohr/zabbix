#!/bin/perl
BEGIN{push @INC,"/usr/share/zabbix/bin/perl-5.10.1/lib"}
require "/usr/share/zabbix/repo/files/auto/lib.pm";

use warnings;
use strict;

$0 = "perl interrutps total VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

my  $dir_tmp         = "/tmp/zabbix/interrupts_total";
our $file_debug      = "$dir_tmp/debug.log";
our $debug           = 0;
my  $file_interrupts = "/proc/interrupts";

create_dir($dir_tmp);

#Delete log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);


my $total;
foreach my $line (readfile($file_interrupts,"a")) {
  next if $line =~ /CPU0|NMI|LOC|ERR|MIS|edge/;
  
  debug("Lines after skipping unwanted data $line");

  my @split = split /\s{1,}/, $line;

  foreach my $interrupt (@split) {
    next if $interrupt =~ /\D/; 
    next unless $interrupt;
    next if $interrupt == 0;
    
    debug("Interrupt number found in array. Adding to \$total $interrupt\n");
    
    $total += $interrupt;
  } 
  
}

print $total;
