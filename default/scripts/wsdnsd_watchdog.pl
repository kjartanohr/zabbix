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
use JSON;


$0 = "perl watchdog wsdns VER 100";
$|++;
#$SIG{CHLD} = "IGNORE";

my $dir_tmp        = "/tmp/zabbix/watchdog/wsdns";
our $file_debug    = "$dir_tmp/debug.log";
my $debug         = 1;

create_dir($dir_tmp);

#Delete log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);


#End of standard header


#fork a child and exit the parent
#Don't fork if $debug is true
unless ($debug){
  fork && exit;
}

#Closing so the parent can exit and the child can live on
#The parent will live and wait for the child if there is no close
#Don't close if $debug is true
unless ($debug) {
  close STDOUT;
  close STDIN;
  close STDERR;
}

#Eveything after here is the child

my %started;
my %pid;

MAIN:
while (1) {
  print "Sleep 10\n";
  sleep 10;

  CPWD:
  foreach (run_cmd("cpwd_admin list", "a")) {
    chomp;
    s/^\s{1,}//;

    #APP        CTX        PID    STAT  #START  START_TIME             MON  COMMAND
    my ($app, $ctx, $pid, $stat, $start, $start_time, $start_date, $mon, $command) = split/\s{1,}/,$_,9;
    $command =~ s/\s{1,}$//;


    if ($stat eq "T") {
      print "Process terminated on VS $ctx. Command: $command \n";

      if ($started{"$ctx-$command"}) {
        print "This process is already started. Will not start again: $ctx $command\n";
        next;
      }

      #Kill childs not needed
      foreach my $pid (keys %pid) {
        my $process = $pid{$pid};

        if ($started{$process}) {
          print "Found terminated process listet from cpwd_admin list in %fork. Will not do anything\n";
        }
        else {
          print "Found running fork in %fork, but not in cpwd_admin list. Killing the child: $pid $process\n";
          kill -9, $pid;
          delete $pid{$process};
        }
      }

      $started{"$ctx-$command"} = 1;
      my $cmd = "source /etc/profile.d/vsenv.sh; vsenv $ctx &>/dev/null ; $command";
      $pid{"$ctx-$command"} = fork && next;

      #Fork
      my $name = "$0 VSID $ctx Command $command";
      my $start_count = 1;
      while (1) {
        my $time_start = time;

        my $date = get_date_time();
        $0 = "$name start count $start_count date $date";
        print "$cmd\n";
        my $out = `$cmd`;
        $start_count++;

        print "VSID $ctx command: $command. out: $out\n";

        if ( (time - $time_start) <= 1) {
          print "The process stopped running after 1 second. Adding a sleep 1 sec befor startting again\n";
        }

      }
    }
  }
}

sub get_date_time {
  my $time = time();
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
  my $timestamp = sprintf ( "%04d-%02d-%02d %02d:%02d:%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec);
  return $timestamp;
}


