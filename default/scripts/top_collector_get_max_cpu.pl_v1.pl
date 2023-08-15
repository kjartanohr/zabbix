#!/usr/bin/perl5.32.0
#bin
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;
use Fcntl qw(SEEK_SET SEEK_CUR SEEK_END);

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

my $process_file = $process;
$process_file    =~ s/\W/_/g;
my $file = "$dir_tmp/$process_file";

#End of standard header


#Eveything after here is the child

print int get_cpu_usage($process);

set_timestamp($file);


sub get_last_check_timestamp {
  my $name = shift || die "Need a process name to get last check";
  my $timestamp;

  if (-f $file) {
    $timestamp = readfile("$dir_tmp/$name");
  }
  else {
    set_timestamp($file);
  }

}

sub get_cpu_usage {
  my $process = shift || die "Need a process name to get cpu usage";
  my $timestamp_last = get_last_check_timestamp($process_file);
  my $timestamp_log  = 0; 
  my $cpu_max        = 0;

  open my $fh_r_top, "<", $top_log or die "Can't open $top_log: $!\n";
  seek $fh_r_top, -1*1024*1024, SEEK_END;

  my $split_count_cpu = 0;
  while (<$fh_r_top>) {
    s/^\s{1,}//;   

    #Get the array index for CPU
    if (!$split_count_cpu and /^PID/) {
      #PID USER      PR  NI    VIRT    RES    SHR S %CPU %MEM     TIME+ COMMAND
      foreach (split/\s{1,}/) {
        last if /CPU/;
        $split_count_cpu++;
      }
    }


    if (/TIME: \d{4,}/) {
      ($timestamp_log) = /TIME: (\d{1,})/;
    }

    next unless $timestamp_log;

    if ($timestamp_last && $timestamp_log) {
      next if $timestamp_last > $timestamp_log;
    }


    #22664 admin     20   0    2420    716    616 S  0.0  0.0   0:00.00 mpstat 1 1
    #my ($pid, $user, $pr, $ni, $virt, $res, $shr, $s, $cpu, $mem, $time, $command) = split/\s{1,}/;

    my @split = split/\s{1,}/;
  
    next unless /$process/;
    debug("$_\n");

    debug("Found split index for CPU usage in top.log: $split_count_cpu\n");

    if ($split_count_cpu == 0) {
      $split_count_cpu = 8;
      debug("Could not find index value for CPU. Setting \$split_count_cpu to 8\n");
    }

    next unless $split[$split_count_cpu];
    $cpu_max = $split[$split_count_cpu] if $split[$split_count_cpu] > $cpu_max;  

  }

  return $cpu_max;
}

sub set_timestamp {
  my $file = shift || die "need a filename to set timestamp";

  open my $fh_w,">", $file or die "Can't write to $file: $!\n";
  print $fh_w time;
  close $fh_w;
}
