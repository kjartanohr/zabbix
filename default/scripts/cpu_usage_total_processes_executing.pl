#!/bin/perl
BEGIN{push @INC,"/usr/share/zabbix/bin/perl-5.10.1/lib"}
require "/usr/share/zabbix/repo/files/auto/lib.pm";

use warnings;
use strict;

$0 = "perl cpu usage total processes_executing VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

my  $dir_tmp         = "/tmp/zabbix/cpu_usage_total_processes_executing";
our $file_debug      = "$dir_tmp/debug.log";
our $debug           = 0;
my  $file_cpu_stat   = "/proc/stat";

create_dir($dir_tmp);


my $total;
foreach my $line (readfile($file_cpu_stat,"a")) {
  next unless $line =~ /cpu /;

  debug("Lines after skipping unwanted data $line");

  my @split = split /\s{1,}/, $line;

  my $split_count = 0;
  foreach my $interrupt (@split) {
    next if $interrupt =~ /\D/;
    next unless $interrupt;
    next if $interrupt == 0;
    next if $split_count == 4;

    debug("Interrupt number found in array. Adding to \$total $interrupt\n");

    $total += $interrupt;
    $split_count++;
  }

}

print $total;
