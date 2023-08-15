#!/bin/perl

$debug             = 0;

#Zabbix test that will have to print out zabbix test ok. If not, the script will not download
if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

#Exit if this is a mamagement
if (`cpprod_util CPPROD_IsMgmtMachine 2>&1` =~ /1/){
  debug("This is a MGMT, exit");  
  exit;
}

debug("$0 Input data ".join " ",@ARGV);

$vsid              = shift @ARGV || 0;                                     #VSID 
$percentage_alert  = shift @ARGV || 50;                                    #Print tables that are more than N
$read_log          = shift @ARGV || 0;                                     #If this is defined, it will print the last log and exit
$log_file          = shift @ARGV || "/tmp/zabbix/fw_tab/fw_tab_vs$vsid";   #What log file to use
($log_dir)         = $log_file =~ /(.*)\//;                                #Extract directory from log file path
@exclude           = qw(
  fa_free_disk_space
  dns_reverse_domains_tbl
  mal_stat_src_week
  mal_stat_src_day
  mal_stat_src_hour
  dns_reverse_domains
  cptls_server_cn_cache
);

debug("This will run on VSID $vsid\n$output tables with more than $percentage_alert in use\nWrite to log file $log_file");
debug("This will not run a new fw tab check. It will only output from log file") if $read_log;

#Create zabbix tmp directory
system "mkdir -p $log_dir" unless -d $log_dir;

#If there a log file, print it
if (-f $log_file) {
  debug("Log file found. Will read and output data");
  foreach (`cat $log_file`){
    ($name,$percentage) = split/: /;
    $percentage =~ s/%//;

    next if $percentage < $percentage_alert;
    print;
  }
}

#Exit the script if this is running for the old log output only
if ($read_log){
  debug("The script is started in read log file only mode. Exit");
  exit;
}

#fork a child and exit the parent
#This script can run for minutes, so we need to fork the rest of the script. It will run in the background
#Don't fork if debug is running. 
unless ($debug){
  fork && exit;
}

#Eveything after here is the child

#Open log file
open $fh_w,">", $log_file or die "Can't write to $log_file: $!";

#Closing so the parent can exit and the child can live on
#The parent will live and wait for the child if there is no close 
#Don't close if debug is running. 
unless ($debug) {
  close STDOUT;
  close STDIN;
  close STDERR;
}

#Listing all the local kernel tables
MAIN: foreach (`source /etc/profile.d/vsenv.sh; vsenv $vsid &>/dev/null ; fw tab -s`){
  next unless /localhost/;
  chomp;

  debug("foreach fw tab -s $_");

  #Split the output and insert the data in variables
  ($host,$name,$id,$vals,$peak,$slinks) = split/\s{1,}/;

  #Skip table if in @exclude
  foreach $exclude (@exclude){
    if ($exclude eq $name){
      debug("Exclude check. Skip if $exclude eq $name");
      next MAIN;
    }
  }


  #Skip if peak is 0
  if ($peak < 10){
    debug("Peak is 10, skip");
    next;
  }

  #Run the fw tab command and save the output to this variable
  $fw_tab_cmd = "source /etc/profile.d/vsenv.sh; vsenv $vsid &>/dev/null ; fw tab -t $name -m 1 2>&1";
  $fw_tab_out = `$fw_tab_cmd`;

  debug("cmd: $fw_tab_cmd");
  debug("out: $fw_tab_out");

  #Get table limit, max values
  ($limit) = $fw_tab_out =~ / limit (\d{1,})/;

  #Skip if not limit found
  unless ($limit =~ /\d/) {
    debug("Could not find a limit. Skipping");
    next;
  }
  debug("Found limit $limit");

  #Get table entry count
  ($count) = $fw_tab_out =~ / num ents (\d{1,})/;

  #Skip table unless entry count found
  unless ($count =~ /\d/) {
    debug("Could not find an entry count. Skipping");
    next;
  }
  debug("Found table count $count");

  #Skip if entry $count is 0
  if ($count == 0){
    debug("Entry count is 0. Skipping");
    next;
  }

  #Calculate the percentage
  $in_use_percentage = int ($count / $limit * 100);

  #Print the name and percentage to the log file
  print $fh_w "$name: $in_use_percentage%\n";
  debug("$name: $in_use_percentage%\n");

}

sub debug {
  print "DEBUG: $_[0]\n" if $debug;
}
