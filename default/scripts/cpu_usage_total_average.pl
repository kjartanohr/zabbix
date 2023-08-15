#!/bin/perl
BEGIN{push @INC,"/usr/share/zabbix/bin/perl-5.10.1/lib"}
require "/usr/share/zabbix/repo/files/auto/lib.pm";

use warnings;
use strict;

$0 = "perl cpu usage average VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

#using our so the external subrutines can read the var
my  $cmd_mpstat  = "mpstat  1 1";
our $debug       = 0;
my  $dir_tmp     = "/tmp/zabbix/cpu_usage_total";
our $file_debug  = "$dir_tmp/cpu_usage.log";
my  $idle_count  = 0;

create_dir($dir_tmp);

#Delete log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);

my @out = run_cmd($cmd_mpstat,"a");

foreach (@out) {
  next unless /CPU.*idle/;
  s/^\s{1,}//;
  my @split = split/\s{1,}/;

  foreach (@split) {
    if (/%idle/) {
      debug("Found idle in $idle_count. Data: $_\n");
      last;
    }

    $idle_count++;
  }
  
}

foreach (@out) {
  next unless /Average:/;
  s/^\s{1,}//;
  my @split = split/\s{1,}/;

  my $cpu_idle = $split[$idle_count]; #Average CPU idle for the last 1 second

  my $cpu_usage = int (100-$cpu_idle);
  print $cpu_usage;

  debug("CPU usage is $cpu_usage");
}
