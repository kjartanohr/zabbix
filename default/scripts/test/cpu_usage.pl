[Expert@gw-cp-kfo:0]# cat cpu_usage.pl
#!/bin/perl
BEGIN{push @INC,"/usr/share/zabbix/bin/perl-5.10.1/lib"}
require "/usr/share/zabbix/repo/files/auto/lib.pm";

use warnings;
use strict;

$0 = "perl cpu usage average VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

if (defined $ARGV[0] && $ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

#using our so the external subrutines can read the var
my  $cmd_mpstat  = "mpstat  1 1";
our $debug       = 0;
my  $dir_tmp     = "/tmp/zabbix/cpu_usage_total";
our $file_debug  = "$dir_tmp/cpu_usage.log";

create_dir($dir_tmp);

#Delete log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);

foreach (run_cmd($cmd_mpstat,"a")) {
  next unless /Average:/;
  my @split = split/\s{1,}/;

  my $cpu_idle = $split[9]; #Average CPU idle for the last 1 second
  my $cpu_usage = int (100-$cpu_idle);
  print $cpu_usage;

  debug("CPU usage is $cpu_usage");
}

