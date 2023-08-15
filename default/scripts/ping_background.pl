#!/bin/perl

BEGIN{push @INC,"/usr/share/zabbix/bin/perl-5.10.1/lib"}

#use warnings;
use Time::Piece;
use Fcntl qw(:flock SEEK_END);

$|++;

#Zabbix test that will have to print out zabbix test ok. If not, the script will not download
if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}


debug("$0 Input data ".join " ",@ARGV);

$debug             = 0;
$version           = 112;
$vsid              = shift @ARGV || 0;                                     #VSID 
$read_log          = shift @ARGV || 0;                                     #If this is defined, it will print the last log and exit
$log_file          = shift @ARGV || "/tmp/zabbix/ping/ping_vs$vsid";       #What log file to use
($log_dir)         = $log_file =~ /(.*)\//;                                #Extract directory from log file path
$0                 = "Internet check ICMP/PING VSID $vsid VER $version";
@ip_destination    = qw(
  8.8.8.8 
  8.8.4.4 
  vg.no 
  bt.no 
  172.217.21.174 
  216.58.207.227
);                      #ping all the addresses in the array

#Check if the running process is older than this version
is_old_version_running();

#Create zabbix tmp directory
system "mkdir -p $log_dir" unless -d $log_dir;

#If there a log file, print it
if (-f $log_file) {
  debug("Log file found. Will read and output data");
  foreach (`cat $log_file`){
    print;
  }
  #Trunk the log file
  system "echo -n >$log_file";

}

#Exit the script if this is running for the old log output only
if ($read_log){
  debug("The script is started in read log file only mode. Exit");
  exit;
}

#fork a child and exit the parent
#Don't fork if debug is running. 
unless ($debug){
  fork && exit;
}

#Eveything after here is the child

#Closing so the parent can exit and the child can live on
#The parent will live and wait for the child if there is no close 
#Don't close if debug is running. 
unless ($debug) {
  close STDOUT;
  close STDIN;
  close STDERR;
}

#Open log file
open $fh_w,">>", $log_file or die "Can't write to $log_file: $!";

#Exit if it takes more than 1 sec to lock the log file.
#Don't start the script if it's already running
local $SIG{ALRM} = sub { die "\n" };
alarm 1;

#Lock the log file
flock($fh_w, LOCK_EX) || die "Cannot lock $file_log $!\n";

alarm 0;


#Listing all the local kernel tables
MAIN: while (1) {
  $failed = 0;
  foreach $ip (@ip_destination){
    $out = `ping -w1 -c1 $ip 2>&1`;
    debug($out);

    #Skip if 0% loss
    if ($out =~ m#, 0% packet loss,#){
      debug("0% loss, next");
      $failed = 0;
      last;
    }

    #Ping failed
    $failed = 1;


  }
  if ($failed) {
    #Print the name and percentage to the log file
    $date = localtime(time)->strftime('%F %T');
    print $fh_w "$date\n";
    debug("$date\n");
  }

  sleep 1;
}

sub debug {
  print "DEBUG: $_[0]\n" if $debug;
}

sub is_old_version_running {
  $name = $0;
  $name =~ s/ VER.*//;

  $cmd = qq#ps xa|grep "$name"#;
  debug($cmd);

  foreach (`$cmd`){
    s/^\s{1,}//;

    #PID TTY      STAT   TIME COMMAND
    ($pid,$tty,$stat,$time,$command) = split /\s{1,}/;

    next if $$ == $pid;
    next if /grep /;
    
    ($ver) = /VER (\d{1,})/;

    unless ($ver) {
      debug("Found an old version of the script without version. Will kill it: $pid");
      system "kill $pid";
    }
   
   
    if ($ver && $ver < $version){
      debug("Found an old version of the script Will kill it: $pid");
      system "kill $pid";
    }
  }

}
