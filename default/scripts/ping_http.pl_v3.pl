#!/bin/perl

#Version 3

#Changelog
#25.03.2020 - alekatea - Changed print statements at bottom, original commented out
#07.01.2021 - Kjartan - la til print igjen. Denne sjekken/scriptet har ikke virket siden 25.03.2020

BEGIN{push @INC,"/usr/share/zabbix/bin/perl-5.10.1/lib"}

use Fcntl qw(:flock SEEK_END);

my $vsid         = $ARGV[0];
my $file_log     = "/tmp/zabbix/ping_http/ping_http_VSID-$vsid.log";
my $file_stop    = "/tmp/zabbix/ping_http/ping_http_VSID-$vsid.stop";
my $file_failed  = "/tmp/zabbix/ping_http/ping_http_VSID-$vsid.failed";
my $log_max_size = 10; #N in MB
my $dir          = "/tmp/zabbix/ping_http";
my $url          = "http://zabbix.kjartanohr.no/cgi-bin/ping.cgi";
my $cmd          = "source /etc/profile.d/vsenv.sh; vsenv $vsid &>/dev/null ; curl_cli -N -S -s $url &>/dev/null";
my $debug        = 0;

$0 = "HTTP ping VSID $vsid";


if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

die "Need VSID" unless defined $vsid;

#Create directory
system "mkdir -p $dir &>/dev/null" unless -d $dir;

#Trunk the log file if it's too big
if (-s $file_log > $log_max_size*1024*1024){
  print "Log file more than max, trunkating\n" if $debug;
  system "echo >$file_log &>/dev/null";
}

#Read the log file and truck it
if (-f $file_failed){
  print 9999;
  unlink $file_failed;
}
else {
  print 1;
}

#fork a child and exit the parent
#Don't fork if $debug is true
unless ($debug){
  fork && exit;
}

#Eveything after here is the child

#Closing so the parent can exit and the child can live on
#The parent will live and wait for the child if there is no close
#Don't close if $debug is true
unless ($debug) {
  close STDOUT;
  close STDIN;
  close STDERR;
}


#Open log file
open my $fh_w, ">>", $file_log or die "Can't write to $file_log: $!";

#Exit if it takes more than 1 sec to lock the log file.
#Don't start the script if it's already running
local $SIG{ALRM} = sub { die "\n" };
alarm 1;

#Lock the log file
flock($fh_w, LOCK_EX) || die "Cannot lock $file_log $!\n";

alarm 0;

#Start main loop
while (1) {
  print "Starting curl $url\n" if $debug;
  print "$cmd\n" if $debug;
  system $cmd;

  if ($file_stop){
    sleep 60;
    next;
  }

  chomp (my $date = `date +"%Y-%m-%d %H:%m:%S"`);
  print $fh_w "$date HTTP ping failed $url\n";
  print "$date HTTP ping failed $url\n" if $debug;

  #print $fh_w 9999;
  system "echo >$file_failed &>/dev/null";

  sleep 10;

}

