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
use Fcntl qw(SEEK_SET SEEK_CUR SEEK_END);

$0 = "perl top collector get cpu usage VER 101";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

my  $cpu            = shift @ARGV || "all";
my  $top_log        = "/tmp/zabbix/top_collector/top.log";
my  $dir_tmp        = "/tmp/zabbix/top_collector_get_data";
my  $dir_sessions   = "$dir_tmp/sessions";
our $file_debug     = "$dir_tmp/debug.log";
our $debug          = 0;
my  $file           = "$dir_sessions/$cpu.time";
my  $file_value     = "$dir_sessions/$cpu.value";

create_dir($dir_tmp);
create_dir($dir_sessions);

#Delete log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);


#End of standard header


#Eveything after here is the child

my $cpu_max = int get_cpu_usage();
print $cpu_max;


save_to_file($file_value, $cpu_max);
save_to_file($file, time);


sub get_last_check_timestamp {
  my $name = shift || die "Need a process name to get last check";
  my $timestamp;

  if (-f $file) {
    $timestamp = readfile($name);
  }
  else {
    save_to_file($file, time);
  }
  return $timestamp;

}

sub get_cpu_usage {
  debug("sub get_cpu_usage start") if $debug;
  my $timestamp_last = get_last_check_timestamp($file);
  my $timestamp_log  = 0;
  my $cpu_max        = 0;

  $cpu_max = readfile($file_value) if -f $file_value;


  debug("opening $top_log") if $debug;
  open my $fh_r_top, "<", $top_log or die "Can't open $top_log: $!\n";
  seek $fh_r_top, -1*1024*1024, SEEK_END;

  while (<$fh_r_top>) {
    s/^\s{1,}//;

    if (/TIME: \d{4,}/) {
      ($timestamp_log) = /TIME: (\d{1,})/;
      debug("Found TIME:. $timestamp_log.  $_") if $debug;
    }

    next unless $timestamp_log;

    if ($timestamp_last && $timestamp_log) {
      if ($timestamp_last >= $timestamp_log) {
        debug("timestamp_last $timestamp_last > timestamp_log $timestamp_log. next") if $debug;
        next;
      }
      else {
        debug("timestamp_last $timestamp_last < timestamp_log $timestamp_log.") if $debug;
      }
    }

   #%Cpu(s): 18.4 us, 21.6 sy,  0.0 ni, 15.2 id, 28.8 wa,  0.8 hi,  7.2 si,  8.0 st
   #%Cpu1  :  0.2 us,  0.2 sy,  0.0 ni, 98.2 id,  0.8 wa,  0.2 hi,  0.2 si,  0.2 st
   if (/^%Cpu|^Cpu/) {
     debug("Found ^%Cpu|^Cpu") if $debug;

     if ($cpu =~ /^\d{1,}$/) {
      if (/%Cpu$cpu/) {
        debug("CPU in input is $cpu and %Cpu$cpu found: $_") if $debug;
      }
      else {
        debug("No match on %Cpu$cpu: $_") if $debug;
        next;
      }
    }


   }
   else {
     debug("No match on ^%Cpu|^Cpu: $_") if $debug;
     next;
   }

   debug("Looking for idle value in line: $_\n");

   #my ($idle) = /, (.*?)\.\d{1,}.*?id,/;
   my ($idle) = /.*,\s{1,}(.*?)\s{1,}id,/;

   unless (defined $idle and $idle =~ /^\d{1,}$/) {
     debug("Could not extract idle CPU digit. Something is wrong with the parser. Fatal error. next") if $debug;
     next;
   }

   $idle = int $idle;

   if (defined $idle) {
    debug("Found idle: $idle. $_") if $debug;
   }
   else {
    debug("No idle found. next. $_") if $debug;
    next;
   }

   $idle = 100 unless $idle;

   debug("Idle value found: $idle\n");

   if ($idle =~ /\D/) {
     debug("Something is wrong. Can't extract idle value for line: $_\n");
     next;
   }

   my $cpu_usage = (100-$idle);
   $cpu_max = $cpu_usage if $cpu_usage > $cpu_max;




  }

  return $cpu_max;
}

sub save_to_file {
  my $file = shift // die "need a filename to set timestamp";
  my $data = shift // die "need data to write";

  open my $fh_w,">", $file or die "Can't write to $file: $!\n";
  print $fh_w $data;
  close $fh_w;
}

