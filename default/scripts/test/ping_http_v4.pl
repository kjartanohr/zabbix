#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

#Changelog
#25.03.2020 - alekatea - Changed print statements at bottom, original commented out

#07.01.2021 - Kjartan
# la til print igjen. Denne sjekken/scriptet har ikke virket siden 25.03.2020

# Sjekk om brannmuren i det heletatt har tilgang til internett før en alarm sendes

# Lagt til versjon. Hvis et eldre script kjører, drep det

#hvis brannmuren har mistet tilgang til internett mer enn $cmd_max_error_count, ikke send alarm



my $version = 104;

use Fcntl qw(:flock SEEK_END);
use warnings;
use strict;

zabbix_check($ARGV[0]);

my  $vsid                 = $ARGV[0]; die "Need a VS to run on" unless defined $vsid;
my  $input_url            = $ARGV[1] || "";
my  $dir                  = "/tmp/zabbix/ping_http";
my  $file_log             = "/tmp/zabbix/ping_http/ping_http_VSID-$vsid.log";
my  $file_stop            = "/tmp/zabbix/ping_http/ping_http_VSID-$vsid.stop";
my  $file_failed          = "/tmp/zabbix/ping_http/ping_http_VSID-$vsid.failed";
my  $file_givenup         = "$dir/ping_http_VSID-$vsid.givenup";
my  $file_online          = "$dir/ping_http_VSID-$vsid.online";
our $file_debug           = "$dir/ping_http_VSID-$vsid.debug";
my  $log_max_size         = 10; #N in MB
my  $url                  = "http://zabbix.kjartanohr.no/cgi-bin/ping.cgi";
my  $cmd                  = "source /etc/profile.d/vsenv.sh; vsenv $vsid &>/dev/null ; curl_cli -k -N -v $url &>/dev/null";
my  $cmd_internet_check   = "source /etc/profile.d/vsenv.sh; vsenv $vsid &>/dev/null ; curl_cli -m 1 -k -N -S -v $url 2>&1";
our $debug                = 0;
my  $cmd_min_run_time     = 120;  #N Sec. The minimum time the curl command has to run before something is wrong. If the VS does not have access to DNS og internet.
my  $cmd_max_error_count  = 20;   #N. How many times before the script gives up and creates $file_givenup
my  $sleep_givenup        = 24;   #H. Sleeping for N hours if retry counter is higer than $cmd_max_error_count
my  $sleep_retry          = 60;   #S. Hvor many seconds to sleep before running cmd again
my  $online_time_minimum  = 48;   #H. URL check command need to run for more than 48 hours before this GW is marked as online. Stopping the alarm spam

$SIG{CHLD} = sub { wait };
#$SIG{CHLD}  = "IGNORE";
$SIG{INT}   = \&ctrl_c;
$|++;

my $old_name = $0;
$0 = "perl HTTP ping VSID $vsid VER $version";

debug("Changing process name from $old_name to $0\n");

debug("Checking if older version of this script is already running\n");
is_old_version_running();

if ($input_url) {
  debug("Script started with a different URL. \$url = $input_url\n");
  $url = $input_url;
}

#Create directory
create_dir($dir);

#Delete log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);

#Trunk the log files if it's too big
if (-s $file_log > $log_max_size*1024*1024){
  debug("Log file is more than $log_max_size. Trunking the file\n");
  touch($file_log);
}

if (-s $file_debug > $log_max_size*1024*1024){
  debug("Debug file is more than $log_max_size. Trunking the file\n");
  touch($file_debug);
}

#Read the log file and truck it
if (-f $file_log){

  debug("Found $file_log. Printing the content back to zabbix and trunking the file\n");
  open my $fh_r, "<", $file_log or die "Can't read $file_log: $!";
  print join "", <$fh_r>;
  close $fh_r;

  touch($file_log);
}
else {
  debug("Could not find $file_log\n");
}

#fork a child and exit the parent
#Don't fork if $debug is true
unless ($debug){
  debug("\$debug is not true. Forking the child and exiting the main script\n");
  fork && exit;
}

debug("The child process is started and ready for action\n");

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
debug("Opening $file_log for appending data\n");
my $file_log_state = open my $fh_w, ">>", $file_log;

unless ($file_log_state) {
  my $msg = "Can't write to $file_log: $!";
  debug("$msg\n");
  exit;
}

#Exit if it takes more than 1 sec to lock the log file.
#Don't start the script if it's already running
debug("Trying to lock the log file. This will fail if this script is already running\n");
local $SIG{ALRM} = sub { debug("Could not lock $file_log. Exiting\n"); die "\n" };

debug("Setting 2 second alarm\n");
alarm 2;

#Lock the log file
flock($fh_w, LOCK_EX) || die "Cannot lock $file_log $!\n";

debug("Resetting alarm\n");
alarm 0;

debug("Locking the log file is OK\n");


debug("Checking if there is an old $file_givenup file\n");
if (-f $file_givenup) {
  debug("Found an old $file_givenup\n");
  debug("Checking if URL is still down\n");

  my $cmd_internet_check_out = `$cmd_internet_check`;
  if ($cmd_internet_check_out =~ /200 OK/) {
    debug("Got HTTP 200 OK from command. URL is up: $cmd_internet_check_out\n");
    debug("Deleting $file_givenup\n");

    unlink $file_givenup;
  }
  else {
    debug("Did not get HTTP 200 OK from command. URL is still down. Exiting\n");
    exit;
  }

}
else {
  debug("Could not find $file_givenup\n");
}

my $cmd_error_count     = 0;
my $url_check_ok_count  = 0;

#Start main loop
debug("Starting main while loop\n");

while (1) {
  debug("Inside the main loop\n");

  if (-f $file_stop){
    debug("$file_stop file is found. Sleeping for 60s and checking again\n");
    sleep 60;
    next;
  }
  debug("$file_stop file is not found\n");

  if ($cmd_error_count > $cmd_max_error_count) {
    debug("have tried to run the command too many times now. Creating $file_givenup and sleeping for $sleep_givenup hours. Setting \$cmd_max_error_count = 0\n");
    touch($file_givenup);
    $cmd_error_count = 0;

    sleep $sleep_givenup*60*60;
    next;
  }

  my $cmd_time = time;
  debug("Setting the current time to \$cmd_time = $cmd_time\n");

  debug("Starting command $cmd\n");
  debug("Will wait here until curl dies\n");

  my $pid = fork;

  if ($pid) {
    #Parent code

    debug("Parent: Will check if PID is active\n");

    debug("Parent: fork is alive. PID: $pid\n") if kill 0, $pid;

    my $sleep = 1;
    my $count = 0;

    while (kill 0, $pid) {

      debug("Child PID $pid is still alive\n") if $debug;

      my $cmd_time_running = (time - $cmd_time);
      if ($cmd_time_running > $online_time_minimum *60*60) {
        debug("URL check has been running for $cmd_time_running seconds. This is good. Creating $file_online \n");
        touch($file_online);
      }

      if ($count == 10) {
        debug("Counter is more than 10. \$sleep = 10\n") if $debug;
        $sleep = 10
      }

      $count++;
      sleep $sleep;
    }
    debug("Parent: The child process $pid is dead\n");

  }
  else {
    #The code for the child

    $0 = $0." fork/child $cmd";
    debug("Fork: Will start command\n");
    my $cmd_out = `$cmd`;
    debug("Fork: $cmd died: $cmd_out\n");
    exit;
  }



  my $cmd_time_running = (time - $cmd_time);
  debug("The command was running for $cmd_time_running seconds\n");

  if (!(-f $file_online) and $cmd_time_running < $cmd_min_run_time) {
    $cmd_error_count++;
    debug("The command did not run the minimum required time. Something is wrong. \$cmd_error_count++: $cmd_error_count\n");
    sleep $sleep_retry;
    next;
  }
  else {
    debug("cmd_max_error_count: $cmd_max_error_count. Setting \$cmd_max_error_count = 0. \n");
    $cmd_max_error_count = 0;
  }


  debug("Checking if $file_online exists\n");
  if (-f $file_online) {

    debug("Online file exists. This GW has been online for more than $online_time_minimum hours\n");

    chomp (my $date = `date +"%Y-%m-%d %H:%m:%S"`);
    debug("Getting date and time from the command date: $date\n");

    debug("Writing error message to $file_log. Zabbix will read this error file and trunk it\n");
    my $msg_error = "$date HTTP lost connection";

    print $fh_w "$msg_error\n";

    debug("Writing to file: \"$msg_error\". URL: $url\n");

    debug("Creating $file_failed\n");
    touch($file_failed);

    sleep $sleep_retry;

  }
  else {
    debug("Online file noes not exists. This GW has NOT been online for more than $online_time_minimum hours. Will not log this downtime\n");
  }

}

sub is_old_version_running {
  my $name = $0;
  $name =~ s/ VER.*//;

  my $cmd = qq#ps xa|grep "$name"#;
  debug("Running command: $cmd\n");

  foreach (`$cmd`){
    s/^\s{1,}//;

    #PID TTY      STAT   TIME COMMAND
    my ($pid,$tty,$stat,$time,$command) = split /\s{1,}/;

    next if $$ == $pid;
    next if /grep /;

    debug("Found a process to check: $_\n");

    my ($ver) = /VER (\d{1,})/;

    unless (defined $ver) {
      debug("Could not find the version of the running script. \$ver = 0\n");
      $ver = 0;
    }

    debug("Version of the running script: $ver\n");

    debug("Cheking if \$ver ($ver) is lower than this \$version ($version)\n");

    if ($ver < $version){
      debug("Found an old version of the script Will kill it: $pid\n");

      my @pid = get_child_processes($pid);

      kill "KILL", @pid;
    }
  }
}


sub ctrl_c {

  close $fh_w;
  debug("Someone is killing me. Bye\n");
  exit;

}

sub get_child_processes {
  my $pid = shift || die "Need a PID to check";
  my @pid;

  push @pid, $pid;

  my $pid_found;

  while (my $pid_child = `pgrep -P $pid`) {
    chomp $pid_child;
    $pid = $pid_child;

    debug("Found child process $pid\n");
    push @pid, $pid;
  }

  return @pid;
}
