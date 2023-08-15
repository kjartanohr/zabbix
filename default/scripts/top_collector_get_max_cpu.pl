#!/usr/bin/perl5.32.0
#bin
BEGIN{

  #init global pre checks
  #init_local_begin('version' => 1);

  #Global var
  our %config;

  require "/usr/share/zabbix/repo/files/auto/lib.pm";
  #require "./lib.pm";

  #Zabbix health check
  zabbix_check($ARGV[0]) if defined $ARGV[0] and $ARGV[0] eq "--zabbix-test-run";


  #init global pre checks
  init_global_begin('version' => 1);
}

#TODO

#Changes

#BUGS

#Feature request

use warnings;
no warnings qw(redefine);
use strict;


$0 = "perl top collector get cpu usage VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

my  $process       = shift @ARGV || die "Need process name to fetch data";  
my  $top_log       = "/tmp/zabbix/top_collector/top.log";
my  $dir_tmp       = "/tmp/zabbix/top_collector_get_data";
our $file_debug    = "$dir_tmp/debug.log";
our $debug         = 0;

create_dir($dir_tmp);

#Delete log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);

#End of standard header


#Eveything after here is the child

#print int get_cpu_usage($process);

debug("get_cpu_usage()", "debug", \[caller(0)] ) if $debug;

my $cpu = get_cpu_usage(
  'process' => $process,
  'id'      => 'top_collector_get_max_cpu.pl',
);

if (defined $cpu) {
  debug("Data from get_cpu_usage(). \$cpu: '$cpu'", "debug", \[caller(0)] ) if $debug;
  print int $cpu;
}
else {
  debug("No data from get_cpu_usage(). print 0", "debug", \[caller(0)] ) if $debug;
  print 0;
}


