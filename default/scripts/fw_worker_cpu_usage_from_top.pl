#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;

$0 = "perl fw worker cpu usage devided by corexl VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

my  $action         = shift @ARGV || die "Need a action";
my  $vsid           = shift @ARGV || 0;
my  $dir_tmp        = "/tmp/zabbix/fw_worker_cpu/$vsid/";
our $file_debug     = "$dir_tmp/debug.log";
our $debug          = 0;

create_dir($dir_tmp);

my @workers;

foreach (`/usr/share/zabbix/repo/scripts/auto/fw_worker.pl discovery`) {
  next unless /"\{#VSID\}":"$vsid"/;
  next if /_dev_/;

  debug("$_\n");
  
  push @workers, /"\{#NAME\}":"(.*?)"/;

}

my $cpu_total = 0;

foreach my $worker (@workers) {
  my $cmd_out = `/usr/share/zabbix/repo/scripts/auto/top_collector_get_max_cpu.pl $worker`;
  next unless $cmd_out =~ /\d/;

  debug("$worker $cmd_out\n");

  next if $cmd_out > 100;
  $cpu_total += $cmd_out;
}

debug($cpu_total."\n");

if ($action eq "total") {
  if ($cpu_total) {
    print int $cpu_total;
  }
  else {
    print 0;
  }
  
}

elsif ($action eq "devided-by-corexl") {
  my $corexl = get_corexl_count($vsid);

  if ($cpu_total) {
    print int ($cpu_total / $corexl);
  }
  else {
    print 0;
  }
  debug($cpu_total / $corexl."\n");
}

