#!/usr/bin/perl5.32.0
BEGIN{
  #require "/usr/share/zabbix/repo/files/auto/lib.pm";
  require "/usr/share/zabbix/repo/scripts/auto/lib-2022.10.03.pm";
  #require "/usr/share/zabbix/repo/scripts/auto/lib-dev.pm";
  #require "./lib.pm";
  #require "./lib-2022.10.03.pm";
}

#require "./lib.pm";
use warnings;
use strict;
use Fcntl qw(:flock SEEK_END); #Module for file lock
use Data::Dumper;
use JSON;

#TODO

#Changes
#2022.02.01 - New syntax for the debug command. -v all to debug all VS
#2022.02.17 - More debug, verify, reusing code and tuning
#2022.02.18 - Fixed a bug/change for R80.40
#2022.12.06 - added more debug

#TODO
#Add timestamp for last update
#Remove data older than 90 days


#Print the data immediately. Don't wait for full buffer
$|++;

#Zabbix test that will have to print out zabbix test ok. If not, the script will not download


#Print the input the script is started with

KFO::lib::zabbix_check($ARGV[0]) if defined $ARGV[0] and $ARGV[0] eq "--zabbix-test-run";

our $debug            = 0;                                                            #Set to 1 if you want debug data and no fork
our $info             = 0;
our $warning          = 0;
our $error            = 9;
our $fatal            = 9;

our $dir_tmp          = "/tmp/zabbix/fw_ctl_debug_drop";
our $file_error       = "$dir_tmp/error.log";
our $file_debug       = "$dir_tmp/debug.log";


my $version           = 102;                                                          #Version of the script. If the version runnin is older than this, kill the old script
my $run_time          = 5;                                            #Run the fw debug for NN minutes
my $log_file          = "/tmp/zabbix/fw_ctl_debug_drop/drop.log";      #What log file to use
my $lock_file         = "/tmp/zabbix/fw_ctl_debug_drop/drop.lock";     #What lock file to use
my $time_file         = "/tmp/zabbix/fw_ctl_debug_drop/dbg_time.log";  #debug drop timestamp file
my $stop_file         = "/tmp/zabbix/fw_ctl_debug_drop/stop";          #STOP file
my $parsing_file      = "/tmp/zabbix/fw_ctl_debug_drop/parsing_error.log";
my ($log_dir)         = $log_file =~ /(.*)\//;                                        #Extract directory from log file path
$0                    = "fw ctl debug drop VER $version";                             #Set the process name
my $file_gzip         = "$dir_tmp/command_output.gz";

#fw ctl debug -h
my $cmd_fw            = get_fw_ctl_command();

my $cmd_fw_debug_off  = "fw ctl debug 0 &>/dev/null";                                 #Disable debug
my $cmd_gzip          = "gzip -9 >$file_gzip";

my $error_count_min   = 100;


my $kill_time         = ($run_time + 120);                                            #Kill the fw ctl debug if it's older than N hours
my $cpu_count_minimum = 4;
my %db                = ();                                                           #Set an empty hash
my %ip                = ();                                                           #Set an empty hash
my %tmp               = ();                                                           #Set an empty hash

my %config;
#my $config = \%config;


#Directories
$config{'dir'}{'home'}        ||= $dir_tmp;

$config{'dir'}{'home'}        =~ s/\.\///;
$config{'dir'}{'tmp'}         = "$config{'dir'}{'home'}/tmp";
$config{'dir'}{'log'}         = "$config{'dir'}{'home'}/log";
$config{'dir'}{'data'}        = "$config{'dir'}{'home'}/data";
$config{'dir'}{'config'}      = "$config{'dir'}{'home'}/config";
$config{'dir'}{'cache'}       = "$config{'dir'}{'home'}/cache";

#Files
$config{'file'}{'database'}   = "$config{'dir'}{'data'}/database.json";
$config{'file'}{'stop'}       = "$config{'dir'}{'config'}/stop";

$config{'log'}{'options'}   = {
  'dir' => $config{'dir'}{'log'},

};

#Default output data
$config{'default-output'}   = {
  'error'         => 9999,                                                      # If something goes wrong for any reason. print this back to the zabbix agent
  'na'            => 8888,                                                      # Missing function, blade. print this if the check if for a function/blade that is not running
  'no-result'     => 0,                                                         #If no result/data is found. print this value
};

#Init config
$config{'init'}   = {
  'is_cp_gw'        => 0,
  'is_cp_mgmt'      => 0,

  'cpu_count'       => 2,
};



$config{'log'}{'default'}       = {
  "enabled"       => 0,     #0/1
  "level"         => 9,     #1-9
  "print"         => 1,     #Print to STDOUT
  "print-warn"    => 0,     #Print to STDERR
  "log"           => 0,     #Save to log file
  "file"          => "$config{'dir'}{'log'}/default.log", #Log file
  "file-fifo"     => 0,     #Create a fifo file for log
  "file-size"     => 10,    #MB max log file size
  "cmd"           => "",    #Run CMD if log. Variable: _LOG_
  "lines-ps"      => 10,    #Max lines pr second
  "die"           => 0,     #Die/exit if this type of log is triggered
};

$config{'log'}{'debug'}       = {
  "enabled"       => 0,     #0/1
  "level"         => 9,     #1-9
  "print"         => 1,     #Print to STDOUT
  "print-warn"    => 0,     #Print to STDERR
  "log"           => 0,     #Save to log file
  "file"          => "$config{'dir'}{'log'}/debug.log", #Log file
  "file-fifo"     => 0,     #Create a fifo file for log
  "file-size"     => 100*1024*1024,    #MB max log file size
  "cmd"           => "",    #Run CMD if log. Variable: _LOG_
  "lines-ps"      => 10,    #Max lines pr second
  "die"           => 0,     #Die/exit if this type of log is triggered
};

$config{'log'}{'info'}       = {
  "enabled"       => 0,     #0/1
  "level"         => 5,     #1-9
  "print"         => 1,     #Print to STDOUT
  "print-warn"    => 0,     #Print to STDERR
  "log"           => 1,     #Save to log file
  "file"          => "$config{'dir'}{'log'}/info.log", #Log file
  "file-fifo"     => 0,     #Create a fifo file for log
  "file-size"     => 100*1024*1024,    #MB max log file size
  "cmd"           => "",    #Run CMD if log. Variable: _LOG_
  "lines-ps"      => 10,    #Max lines pr second
  "die"           => 0,     #Die/exit if this type of log is triggered
};

$config{'log'}{'warning'}       = {
  "enabled"       => 0,     #0/1
  "level"         => 5,     #1-9
  "print"         => 1,     #Print to STDOUT
  "print-warn"    => 0,     #Print to STDERR
  "log"           => 1,     #Save to log file
  "file"          => "$config{'dir'}{'log'}/warning.log", #Log file
  "file-fifo"     => 0,     #Create a fifo file for log
  "file-size"     => 100*1024*1024,    #MB max log file size
  "cmd"           => "",    #Run CMD if log. Variable: _LOG_
  "lines-ps"      => 10,    #Max lines pr second
  "die"           => 0,     #Die/exit if this type of log is triggered
};

#debug("", "error", \[caller(0)] ) if $config{'log'}{'error'}{'enabled'};
$config{'log'}{'error'}       = {
  "enabled"       => 1,     #0/1
  "level"         => 5,     #1-9
  "print"         => 1,     #Print to STDOUT
  "print-warn"    => 0,     #Print to STDERR
  "log"           => 1,     #Save to log file
  "file"          => "$config{'dir'}{'log'}/error.log", #Log file
  "file-fifo"     => 0,     #Create a fifo file for log
  "file-size"     => 100*1024*1024,    #MB max log file size
  "cmd"           => "",    #Run CMD if log. Variable: _LOG_
  "lines-ps"      => 10,    #Max lines pr second
  "die"           => 0,     #Die/exit if this type of log is triggered
};

$config{'log'}{'fatal'}       = {
  "enabled"       => 1,     #0/1
  "level"         => 5,     #1-9
  "print"         => 1,     #Print to STDOUT
  "print-warn"    => 0,     #Print to STDERR
  "log"           => 1,     #Save to log file
  "file"          => "$config{'dir'}{'log'}/fatal.log", #Log file
  "file-fifo"     => 0,     #Create a fifo file for log
  "file-size"     => 100*1024*1024,    #MB max log file size
  "cmd"           => "",    #Run CMD if log. Variable: _LOG_
  "lines-ps"      => 10,    #Max lines pr second
  "die"           => 0,     #Die/exit if this type of log is triggered
};

$config{'log'}{'main::get_discovery'}       = {
  "enabled"       => 0,     #0/1
  "level"         => 9,     #1-9
  "print"         => 1,     #Print to STDOUT
  "print-warn"    => 0,     #Print to STDERR
  "log"           => 0,     #Save to log file
  "file"          => "$config{'dir'}{'log'}/sub-get-discovery.log", #Log file
  "file-fifo"     => 0,     #Create a fifo file for log
  "file-size"     => 10*1024*1024,    #MB max log file size
  "cmd"           => "",    #Run CMD if log. Variable: _LOG_
  "lines-ps"      => 10,    #Max lines pr second
  "die"           => 0,     #Die/exit if this type of log is triggered
};

$config{'log'}{'main::get_db'}       = {
  "enabled"       => 0,     #0/1
  "level"         => 9,     #1-9
  "print"         => 1,     #Print to STDOUT
  "print-warn"    => 0,     #Print to STDERR
  "log"           => 0,     #Save to log file
  "file"          => "$config{'dir'}{'log'}/sub-get-db.log", #Log file
  "file-fifo"     => 0,     #Create a fifo file for log
  "file-size"     => 10*1024*1024,    #MB max log file size
  "cmd"           => "",    #Run CMD if log. Variable: _LOG_
  "lines-ps"      => 10,    #Max lines pr second
  "die"           => 0,     #Die/exit if this type of log is triggered
};

$config{'log'}{'KFO::lib::parse_command_line'}       = {
  "enabled"       => 0,     #0/1
  "level"         => 9,     #1-9
  "print"         => 1,     #Print to STDOUT
  "print-warn"    => 0,     #Print to STDERR
  "log"           => 0,     #Save to log file
  "file"          => "$config{'dir'}{'log'}/lib-sub-parse_command_line.log", #Log file
  "file-fifo"     => 0,     #Create a fifo file for log
  "file-size"     => 10*1024*1024,    #MB max log file size
  "cmd"           => "",    #Run CMD if log. Variable: _LOG_
  "lines-ps"      => 10,    #Max lines pr second
  "die"           => 0,     #Die/exit if this type of log is triggered
};

#Set default config
KFO::lib::get_config('config' => \%config, 'init' => 1);


#$debug = $config{'log'}{'debug'}{'level'};

debug("\@ARGV: ".Dumper(@ARGV),  'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
my %argv = KFO::lib::parse_command_line('argv' => \@ARGV, 'config' => \%config);
debug("\%argv: ".Dumper(%argv), 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

#Set debug flag if found on command line
$debug = $argv{'debug'} if defined $argv{'debug'};

my %drop_reason       = (
  'rulebase'                                                  => 'Rule drop',
  'on layer'                                                  => 'Rule drop',
  #'Reject'                                                   => 'Rule drop',
  'MATCH on rule'                                             => 'Rule drop',

  #App & URL
  #'CMI APP 2(APPI).*Reject'                                  => 'rulebase app&url',
  'CMI APP.*Error_page'                                       => 'app&url error page',
  'CMI APP.*Reject'                                           => 'app&url reject',
  'APPI.*Reject'                                              => 'app&url reject',
  #'CMI APP'                                                  => 'app&url other',
  #'APPI'                                                     => 'app&url other',
  
  #VPN
  'vpn.*policy.*decrypted'                                    => 'VPN config error',
  #'vpn_drop_and_log'                                         => 'VPN other',
  'VPN.*replay counter verification failed'                   => 'VPN replay counter verification failed',
  'Decryption Failed'                                         => 'VPN Decryption Failed',
  'Encryption Failed'                                         => 'VPN Encryption Failed',
  'drop due vpn_ipsec_encrypt returns PKT_DROP'               => 'VPN other',
  'ipsec_encrypt failed: failed to find SA'                   => 'VPN config error. failed to find SA',
  'no error - tunnel is not yet established'                  => 'VPN tunnel is not yet established',
  'clear text packet should be encrypted'                     => 'VPN config error. clear text packet should be encrypted',

  #spoofing
  'spoofed address'                                           => 'anti-spoofing',
  'Anti-Spoofing'                                             => 'anti-spoofing',
  'Monitored Spoofed'                                         => 'anti-spoofing',

  #templates
  'drop template'                                             => 'Template drop',

  #Log
  'sending packet dropped notification drop mode'             => 'LOG sending packet dropped notification',
  'sending single drop notification'                          => 'LOG sending packet dropped notification',
  'no track is needed for this drop - not sending'            => 'LOG not sending packet dropped notification',

  #IPS
  'PSL Drop: ADVP'                                            => 'IPS PSL Drop: ADVP',
  'BAD_MULTIK_TAG:got bad instance'                           => 'IPS BAD_MULTIK_TAG:got bad instance',
  'psl drop: internal - reject enabled'                       => 'IPS internal - reject enabled',
  'record_conn inspect func retunred drop action'             => 'IPS record_conn inspect func',

  #SecureXL
  'simpkt_in_drop'                                            => 'SecureXL simpkt_in_drop',
  'xmt error'                                                 => 'SecureXL egress queue full',
  'cut-through: xmt failed!!! xmt_rc=-2,'                     => 'SecureXL egress queue full',

  #TCP
  'psl drop: tcp segment out of maximum allowed sequence'     => 'TCP segment out of maximum allowed sequence',
  'tcp segment out of maximum allowed sequence'               => 'TCP segment out of maximum allowed sequence',
  #'psl drop: tcp segment out of maximum allowed sequence'     => 'TCP segment out of maximum allowed sequence',
  'received syn packet with data, packet dropped'             => 'TCP received syn packet with data',
  'Possible TCP state violation'                              => 'TCP Possible TCP state violation',
  'update_tcp_state: not empty'                               => 'TCP SYN or SYN-ACK packets have payload data',
  'tcp src\/dst port 0'                                       => 'TCP src or dst port 0',
  'invalid tcp flag combination'                              => 'TCP invalid tcp flag combination',
  'First packet.*SYN'                                         => 'TCP first packet is not syn',

  #Other protocol
  'packet exceeds non tcp quota'                              => 'Other protocol packet exceeds non tcp quota',

  #UDP
  'udp src\/dst port 0'                                       => 'UDP src or dst port 0',

  #ICMP
  'icmp error does not match an existing connection'          => 'ICMP error does not match an existing connection',
  'icmp reply does not match a previous request'              => 'ICMP error does not match an existing connection',

  #HTTPS
  'psl drop: tls_parser'                                      => 'HTTPS TLS parser',
  'psl drop: mux_passive'                                     => 'HTTPS TLS parser',
  'PSL Drop: TLS_PARSER'                                      => 'HTTPS TLS parser',

  #CPU high
  'instance is currently fully utilized'                      => 'CPU high',
  'utilized'                                                  => 'CPU high',

  #Multicast
  'mcast connection in process'                               => 'Multicast mcast connection in process',
  'ip multicast routing failed.*missing os route'             => 'Multicast missing os route',
  'IP multicast routing failed.*too many packets received'    => 'Multicast too many packets received before route was resolved',

  #DNS domain
  #sk44711
  'held chain expired'                                        => 'DNS held chain expired',
  ':53 .*PSL Drop: ASPII_MT'                                  => 'DNS PSL Drop: ASPII_MT',

  #DHCP
  ':67 .*local interface spoof'                               => 'DHCP local interface spoof',

  #Anti Malware
  'Anti Malware'                                              => 'Anti Malware unknown',

  #Unknown
  'failed to enqueue f2p'                                     => 'failed to enqueue f2p',
  'enqueue F2P'                                               => 'failed to enqueue f2p',
  'seqvalid_translate_verify failed'                          => 'seqvalid_translate_verify failed',

  #Other
  'buffer full. messages lost'                                => 'Other buffer full. messages lost',
  #'' => '',
);

#print input data
#debug("Command line input data: ".join ", ", @ARGV, "debug", \[caller(0)] ) if $debug > 2;

#Exit if stop file found
debug("Checking for $stop_file", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
if (-f $stop_file) {
  debug("Stop file found $stop_file. Exit", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  exit;
}
else {  
  debug("Stop file not found $stop_file. Continue", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
}

#Exit if this is not a gw
debug("is_gw()", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
if (KFO::lib::is_gw()) {
  debug("is_gw() returned 1. This is a GW. Continue", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
}
else {  
  debug("is_gw() returned 0. This is not a GW. Exit", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  exit;
}


#Exit the script if there is less than 4 CPU cores
debug("cpu_count()", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
my $cpu_count = KFO::lib::cpu_count();
if ($cpu_count < $cpu_count_minimum) {
  debug("CPU count is less than $cpu_count_minimum. Exit", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  exit;
}
else {  
  debug("CPU count is more than $cpu_count_minimum. Continue", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
}


debug("get_db()", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
%db = get_db('file' => $log_file);
debug("return data from get_db(): ".Dumper(%db), 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 4;

#Discovery
if (defined $argv{'discovery'}) {
  debug("--discovery found in %argv", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  print get_discovery();
  exit;
}

#Get date
if (defined $argv{'get-data'}) {
  debug("--get-data found in %argv", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  print get_data('vsid' => $argv{'vsid'}, 'name' => $argv{'name'});
  exit;
}

#Check if debug fw drop is enabled. Create a file. If the file is older than $kill_time the command fw ctl debug 0 will run
#check_debug_drop();

#Check if fw ctl debug is running as a process
debug("get_running_process('regex' => 'fw ctl zdebug')", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
if (my $process_found = KFO::lib::get_running_process('regex' => "fw ctl zdebug")) {
  debug("fw ctl zdebug is running. exit. $process_found", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  print 9999;
  exit;
}


#Kill old running fw ctl debug if more than 4 hours old
debug("kill_old_fw_ctl_debug()", "debug", \[caller(0)] ) if $debug > 1;
kill_old_fw_ctl_debug("fw ctl zdebug");

#Check if the running process is older than this version
#If older version found, kill it
debug("is_old_version_running()", "debug", \[caller(0)] ) if $debug > 1;
is_old_version_running();

#Create zabbix tmp directory
debug("create_dir($log_dir)", "debug", \[caller(0)] ) if $debug > 1;
KFO::lib::create_dir($log_dir);

#Delete log file if it's bigger than 10 MB
debug("trunk_file_if_bigger_than_mb($file_debug,10)", "debug", \[caller(0)] ) if $debug > 1;
KFO::lib::trunk_file_if_bigger_than_mb($file_debug,10);

debug("trunk_file_if_bigger_than_mb($file_error,10);", "debug", \[caller(0)] ) if $debug > 1;
KFO::lib::trunk_file_if_bigger_than_mb($file_error,10);

#delete_file_if_bigger_than_mb($file_debug,10);
#delete_file_if_bigger_than_mb($file_error,10);



#fork a child and exit the parent
#Don't fork if $debug is true
#Closing so the parent can exit and the child can live on
#The parent will live and wait for the child if there is no close
#Don't close if $debug is true
unless ($debug){
  debug("Parent will now fork a child and exit the parent process", "debug", \[caller(0)] ) if $debug > 1;
  
  if (my $pid_fork = fork){
    debug("Parent PID: '$$'", "debug", \[caller(0)] ) if $debug > 1;
    debug("Child PID: '$pid_fork'", "debug", \[caller(0)] ) if $debug > 1;
    exit;
  }

  debug("close STDOUT, STDIN, STDERR", "debug", \[caller(0)] ) if $debug > 1;
  close STDOUT;
  close STDIN;
  close STDERR;
}

#Eveything after here is the child


#Build the hash from old log file
#foreach (`cat $log_file 2>/dev/null`){


#copy the old log file to tmp
my $cmd_cp = "cp -f $log_file $log_file.tmp 2>/dev/null";
debug("copy old log file: $cmd_cp", "debug", \[caller(0)] ) if $debug > 1;
system $cmd_cp;

#Open lock file
my $fh_lock_w;
debug("Open lock file $lock_file", "debug", \[caller(0)] ) if $debug > 1;
open $fh_lock_w,">", $lock_file or die "Can't write to $lock_file: $!";

#Open parsing error file
debug("Open parsing error file $lock_file", "debug", \[caller(0)] ) if $debug > 1;
open my $fh_parsing_w,">", $parsing_file or die "Can't write to $parsing_file: $!";

lock_fh('file-handle' => $fh_parsing_w);

#Delete old output file
debug("delete_file() $file_gzip.old", "debug", \[caller(0)] ) if $debug > 1;
KFO::lib::delete_file('file' => "$file_gzip.old", 'print-error' => 1);
#if (-f "$file_gzip.old") {
#  debug("unlink $file_gzip.old", "debug", \[caller(0)] ) if $debug > 1;
#  unlink "$file_gzip.old";
#}

#Rename old output file 
if (-f $file_gzip) {
  debug("rename $file_gzip -> $file_gzip.old", "debug", \[caller(0)] ) if $debug > 1;
  rename $file_gzip,"$file_gzip.old" or die "Can't rename $file_gzip to $file_gzip.old: $!";
}

#Start gzip for sending output from command
debug("open '$cmd_gzip'", "debug", \[caller(0)] ) if $debug > 1;
open my $gzip_w, "|-", $cmd_gzip  or die "Can't run the command '$cmd_gzip': $!";

#Get the current time. The command will run for $run_time
my $time_startup = time;

#Get the current time for the write time
my $time_write = time;

#Run fw drop debug
my $fw_r = start_debug_process();


#Loop the command output
debug("start main loop", "debug", \[caller(0)] ) if $debug > 1;

#Main loop START
MAIN: while (readline $fw_r) {

  debug("main loop: $_", "debug", \[caller(0)] ) if $debug > 4;

  #Exit if the run time is up
  if ((time - $time_startup) > ($run_time*60)){
    debug("The command has been running for more than $run_time minutes. Will exit", "debug", \[caller(0)] ) if $debug > 1;

    debug("writ_log()", "debug", \[caller(0)] ) if $debug > 1;
    write_log($log_file, \%db);

    debug("kill_process()", "debug", \[caller(0)] ) if $debug > 1;
    kill_process("fw ctl zdebug");

    debug("exit", "debug", \[caller(0)] ) if $debug > 1;
    exit;
  }

  #Save data to lof file every N min
  #Write to log file every minute
  if ((time - $time_write) > (1*60)){
    debug("The command has been running for more than 1 minute. Will write to log file", "debug", \[caller(0)] ) if $debug > 1;
    $time_write = time; #Reset the timeer

    debug("write_log()", "debug", \[caller(0)] ) if $debug > 1;
    write_log($log_file, \%db);
  }

  #Add output to $file_gzip
  print $gzip_w $_;

  #ClusterXL drop
  next if /Log was sent successfully to FW/;

  #Remove new line in the end of line
  chomp;

  #Skip spam lines
  next if /^;$/;

  #Skip header and exit info
  next unless /;/;

  next if /: start/;

  #Not a drop log
  #next if /sim_pkt_send_drop_notification/;

  #The log file is full og CTRL keys. Remove all none ascii
  s/[^[:ascii:]]//g;

  #Remove @ as the first char
  #@;92545593;[vs_10];[tid_2];[fw4_2];fw_log_drop_ex: Packet proto=6 161.35.86.181:6983 -> 77.75.214.32:7000 dropped by fw_send_log_drop Reason: Rulebase drop - on layer "Network" rule 2018;
  #s/^\@//;

  #Remove ; as the first char
  #s/^;//;

  #Get the reason for the drop log
  my $reason = get_reason('data' => $_);
  debug("data retuned from get_reason: '$reason'", "debug", \[caller(0)] ) if $debug > 1;

  #If we can't get a reason. Add line to parsing error file
  unless ($reason) {
    error("Missing reason. $_");
    debug("Missing reason. $_", "warning", \[caller(0)] ) if $warning;
    print $fh_parsing_w "Missing reason. '$_'\n";

    $db{'NA,,,Could not parse reason'} +=1;
    #$db{"unknown,,,Total drop"} += 1;
    #next MAIN;
  }


  #Get the VSID
  my $vsid;

  $vsid = get_vsid($_);
  debug("data retuned from get_vsid: '$vsid'", "debug", \[caller(0)] ) if $debug > 1;

  #If we can't get a VSID. Add line to parsing error file
  unless (defined $vsid) {
    print $fh_parsing_w "Missing VSID: '$_'\n";
    debug("Missing VSID: '$_'", "warning", \[caller(0)] ) if $warning;

    debug("NA,,,Missing VSID. Count: $db{'NA,,,Missing VSID'}", "debug", \[caller(0)] ) if $debug;
    $db{'NA,,,Missing VSID'} +=1;

    $vsid = "unknown";
  }

  $vsid = "vs_$vsid";


  #VS total drop counter
  $db{"$vsid,,,Total drop"} += 1;
  debug(qq#$vsid,,,Total drop. Count: $db{"$vsid,,,Total drop"}#, "debug", \[caller(0)] ) if $debug;

  my @ip = get_ip($_);
  debug("data retuned from get_ip: ".join(", ", @ip), "debug", \[caller(0)] ) if $debug > 1;
  #debug("Found IP address: ".join ", ", @ip);

  #Add stats for IP-address
  IP:
  foreach my $ip (@ip) {
    next IP if $ip =~ /\.255$/;
    debug("ip: '$ip' ++", "debug", \[caller(0)] ) if $debug > 1;
    $db{"$vsid,,,IP: $ip"}++;
    debug(qq#$vsid,,,IP: $ip. Count: $db{"$vsid,,,IP: $ip"}#, "debug", \[caller(0)] ) if $debug;
  }

  my @port = get_port($_);
  debug("data retuned from get_port(): ".join(", ", @port), "debug", \[caller(0)] ) if $debug > 1;
  
  #Add stats for port
  PORT:
  foreach my $port (@port) {
    debug("port: $port ++", "debug", \[caller(0)] ) if $debug > 1;
    $db{"$vsid,,,Port: $port"}++;
    debug(qq#$vsid,,,Port: $port. Count: $db{"$vsid,,,Port: $port"}#, "debug", \[caller(0)] ) if $debug;
  }

  #TODO
  #Add foreach for @exclude

  #+1 the reason counter in the hash
  $db{"$vsid,,,$reason"} += 1;

  debug(qq#VSID: $vsid. reason: $reason. Count: $db{"$vsid,,,$reason"}#, "debug", \[caller(0)] ) if $debug;

}
#Main loop END

sub write_log {
  debug("start", "debug", \[caller(0)] ) if $debug > 2;
  debug("Input data: ".Dumper(@_), "debug", \[caller(0)] ) if $debug > 2;

  my $file      = shift || die "Need a filename to write to";
  my $hash_ref  = shift || die "Need a hash ref to read data from";

  rename $file,"$file.tmp";

  #Open the $log_file for writing
  open my $fh_w_log, ">", $file or die "Can't write to $file: $!";

  #for each the hash and print the values to the $log_file
  foreach (sort %{$hash_ref}){

    #Sanity check the data. Skip if empty
    next unless $db{$_};

    #Don't save drop less than 100
    next if /IP:/     and $db{$_} < 1000;
    next if /Port:/   and $db{$_} < 10000;

    next if $db{$_} < 100;

    #Print the value to $log_file
    print $fh_w_log "$_,,,$db{$_}\n";
  }

  #Close the $log_file
  close $fh_w_log;
}


sub is_old_version_running {
  debug("start", "debug", \[caller(0)] ) if $debug > 2;
  debug("Input data: ".Dumper(@_), "debug", \[caller(0)] ) if $debug > 2;

  my $name = $0;
  $name =~ s/ VER.*//;

  foreach (KFO::lib::run_cmd("ps xa", "a", 2)){
    s/^\s{1,}//;
    next unless /$name/;
    debug("ps xa: found $name: $_", "debug", \[caller(0)] ) if $debug > 1;

    #PID TTY      STAT   TIME COMMAND
    my ($pid,$tty,$stat,$time,$command) = split /\s{1,}/;

    next if $$ == $pid;
    next if /grep /;

    my ($ver) = /VER (\d{1,})/;

    unless ($ver) {
      debug("Found an old version of the script without version. Will kill it: $pid");
      system "kill $pid";
    }

    if ($ver && $ver < $version){
      debug("Found an old version of the script Will kill it: $pid");
      system "kill $pid";
    }
  }
  debug("No old process found", "debug", \[caller(0)] ) if $debug > 1;

}

sub kill_process {
  debug("start", "debug", \[caller(0)] ) if $debug > 2;
  debug("Input data: ".Dumper(@_), "debug", \[caller(0)] ) if $debug > 2;

  my $name = shift or die "Need a process name to kill";
  debug("Kill process subrutine with input: $name", "debug", \[caller(0)] ) if $debug > 1;

  foreach (KFO::lib::run_cmd("ps xa", "a", 2)){
    next unless /$name/;
    debug("ps xa: found $name: $_", "debug", \[caller(0)] ) if $debug > 1;
    s/^\s{1,}//;

    #PID TTY      STAT   TIME COMMAND
    my ($pid,$tty,$stat,$time,$command) = split /\s{1,}/;

    debug("kill $pid", "debug", \[caller(0)] ) if $debug > 1;
    system "kill $pid";

    debug("sleep 1", "debug", \[caller(0)] ) if $debug > 1;
    sleep 1;

    debug("kill -9 $pid", "debug", \[caller(0)] ) if $debug > 1;
    system "kill -9 $pid";

    debug($cmd_fw_debug_off, "debug", \[caller(0)] ) if $debug > 1;
    system $cmd_fw_debug_off;
  }
}

sub kill_old_fw_ctl_debug {
  debug("start", "debug", \[caller(0)] ) if $debug > 2;
  debug("Input data: ".Dumper(@_), "debug", \[caller(0)] ) if $debug > 2;

  my $name  = shift or die "Need a process name to kill";
  my $hours = shift || 4;
  debug("Kill process subrutine with input: $name", "debug", \[caller(0)] ) if $debug > 1;

  foreach (KFO::lib::run_cmd("ps xau", "a", 2)){
    next unless /$name/;
    debug("ps xa: found $name: $_", "debug", \[caller(0)] ) if $debug;
    s/^\s{1,}//;

    #USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
    my ($user,$pid,$cpu,$mem,$vsz,$rss,$tty,$stat,$start,$time,$command) = split /\s{1,}/;

    #Convert start time to unix time
    debug("date -d $start +\%s", "debug", \[caller(0)] ) if $debug > 1;
    my $start_unix = `date -d "$start" +"%s"`;
    chomp $start_unix;
    debug("Found start time of process $start. Converted to unix time $start_unix", "debug", \[caller(0)] ) if $debug > 1;

    #Kill running fw ctl if start time is more than 4 hours
    if ( (time - $start_unix) > (4*60*60) ){

      debug("Found that process is older than 4 hours. Will kill it", "debug", \[caller(0)] ) if $debug > 1;

      system "fw ctl debug 0 &>/dev/null";
      debug("kill $pid", "debug", \[caller(0)] ) if $debug > 1;
      system "kill $pid";

      debug("sleep 1", "debug", \[caller(0)] ) if $debug > 1;
      sleep 1;

      debug("kill -9 $pid", "debug", \[caller(0)] ) if $debug > 1;
      system "kill -9 $pid";

      debug($cmd_fw_debug_off, "debug", \[caller(0)] ) if $debug > 1;
      system $cmd_fw_debug_off;

    }
  }
}

sub check_debug_drop {
  debug("start", "debug", \[caller(0)] ) if $debug > 2;
  debug("Input data: ".Dumper(@_), "debug", \[caller(0)] ) if $debug > 2;

  #Looking for fw drop
  if (run_cmd("fw ctl debug", "s", 10) =~ /Module: fw.*drop.*Common/s){
    debug("fw drop debug enabled", "debug", \[caller(0)] ) if $debug;

    my $time = time;

    debug("Looking for $time_file", "debug", \[caller(0)] ) if $debug > 1;
    if (-f $time_file) {
      debug("$time_file found. Will check the mtime", "debug", \[caller(0)] ) if $debug > 1;

      my $ctime = (stat($time_file))[9];

      if ( (time - $ctime) > $kill_time ) {
        debug("$time_file is older than $kill_time. Will run fw ctl debug 0", "debug", \[caller(0)] ) if $debug > 1;

        if (-f $time_file) {
          debug("Deleting $time_file", "debug", \[caller(0)] ) if $debug > 1;
          unlink $time_file or die "Can't delete $time_file: $!";
        }

        debug($cmd_fw_debug_off, "debug", \[caller(0)] ) if $debug > 1;
        system $cmd_fw_debug_off;

      }
      else {
        debug("File is not older than $kill_time hours. Will print 9999 and exit. File: $time_file", "debug", \[caller(0)] ) if $debug;
        print 9999;
        exit;
      }
    }
    else {
      debug("Creating timestamp file", "debug", \[caller(0)] ) if $debug > 1;
      system "echo $time >$time_file 2>/dev/null";
      print 9999;
    }
  }

}

sub get_vsid {
  debug("start", "debug", \[caller(0)] ) if $debug > 2;
  debug("Input data: ".Dumper(@_), "debug", \[caller(0)] ) if $debug > 2;

  my $line = shift;
  my $vsid;

  #debug("get_vsid. input: $line");

  unless (defined $line) {
    error("sub get_vsid. Missing input data");
    debug("Missing input data: '\$line'. exit", "fatal", \[caller(0)] ) if $fatal;
    exit;
  }

  #return 0 if $line =~ /^@/;
  return 0 if $line =~ /\[kern\]/;
  return 0 if $line =~ /cpu/;

  my @regex = (
    qr/vsid=(\d{1,})/,
    qr/^\[(.*?)\];/,
    qr/vs_(\d{1,})/,
  );

  foreach my $regex (@regex) {
    ($vsid) = $line =~ $regex;
    return $vsid if defined $vsid and $vsid =~ /\d/;
  }

  return;
}

sub get_ip {
  my $line = shift;
  my %return;

  #debug("get_src_ip. input: $line");

  unless (defined $line) {
    error("sub get_src_ip. Missing input data");
    return;
  }

  #conn <10.0.6.102,53020,10.90.1.9,10050,6>;
  # 10.0.5.245:137 -> 10.0.5.255:137

  my @regex = (
    qr/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/,
    qr/ (\d{1,}\.\d.*?):.*?->/,
    qr/->.*?(\d{1,}\.\d.*?):/,
    qr/conn <(\d.*?),/,
  );

  foreach my $regex (@regex) {
    my @ip = $line =~ $regex;

    foreach my $ip (@ip) {
      $return{$ip} = 1 unless defined $return{$ip};
    } 

  }

  return keys %return;
}

sub get_port {
  my $line = shift;
  my @return;

  #debug("get_src_ip. input: $line");

  unless (defined $line) {
    error("sub get_src_ip. Missing input data");
    return;
  }

  #conn <10.0.6.102,53020,10.90.1.9,10050,6>;
  # 10.0.5.245:137 -> 10.0.5.255:137

  my @regex = (
    qr/:(\d{1,}) /,
    qr/#conn.*?,(\d{1,}),.*?,(\d{1,}),/,
  );

  foreach my $regex (@regex) {
    my @found = $line =~ $regex;
    push @return, @found if @found;
  }

  return @return;
}

sub lock_fh {
  debug("start", "debug", \[caller(0)] ) if $debug > 2;
  debug("Input data: ".Dumper(@_), "debug", \[caller(0)] ) if $debug > 2;

  my %input = @_;

  unless (defined $input{'file-handle'}) {
    debug("Missing input data: 'file-handle'. exit", "fatal", \[caller(0)] ) if $fatal;
    exit;
  }

  #Exit if it takes more than 1 sec to lock the lock file.
  #Don't start the script if it's already running
  local $SIG{ALRM} = sub { die "\n" };

  alarm 1;
  debug("alarm 1", "debug", \[caller(0)] ) if $debug > 1;

  #Lock the log file
  debug("Lock the lock file", "debug", \[caller(0)] ) if $debug > 1;
  flock($input{'file-handle'}, LOCK_EX) or die "Cannot lock file: $!\n";

  #Reset the alarm
  alarm 0;
  debug("alarm 0", "debug", \[caller(0)] ) if $debug > 1;


  debug("end", "debug", \[caller(0)] ) if $debug > 2;
}

sub get_db {
  my $sub_name = (caller(0))[3];
  debug("start", "debug", $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 1;
  debug("Input: ".Dumper(@_), "debug", $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 3;
  
  #sub header START
  my %input   = @_;
  debug("$sub_name. $input{'desc'}", "debug", $sub_name, \[caller(0)]) if $config{'log'}{'desc'}{'enabled'} and $config{'log'}{'desc'}{'level'} > 0 and defined $input{'desc'};

  my $return;

  #Default values
  $input{'exit-if-fatal'}         = 0   unless defined $input{'exit-if-fatal'};
  $input{'return-if-fatal'}       = 1   unless defined $input{'return-if-fatal'};
  $input{'validate-return-data'}  = 1   unless defined $input{'validate-return-data'};
  #$input{'XXX'} = "YYY" unless defined $input{'XXX'};
  
  #Validate input data START
  if ($config{"val"}{'sub'}{'in'}){
    my @input_type = qw( file );
    foreach my $input_type (@input_type) {

      unless (defined $input{$input_type} and length $input{$input_type} > 0) {
        debug("Missing input data for '$input_type'", "fatal", \[caller(0)] );
        return 0;
      }
    }
  }
  #Validate input data START

  #sub header END
  
  #sub main code START

  my %db_local = ();

  LOG:
  foreach (KFO::lib::readfile($input{'file'}, 'a', 100)){

    debug("\$_: '$_'",  $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 4;

    chomp;
    $_ = lc $_;

    #Split the data in to variables
    my ($vsid,$err,$count) = split/,,,/;
    debug("vsid: '$vsid', error: '$err', count: '$count'",  $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 1;

    #There is no need to log a rulebase drop
    #next if $err =~ /Rulebase/;
    #next if $err =~ /matched drop template/;
    $err =~ s/Instance \d{1,} /Instance /;

    $vsid = "vs_0" if $vsid =~ /cpu/;
    $vsid = "vs_0" if $vsid eq "kern";

    #Sanity check the input. Skip the line if something is wrong with it
    unless ($vsid =~ /vs_\d/ && $err && $count) {
      debug("Data verify failed. '$_'", "error", \[caller(0)] ) if $error;
      next LOG;
    }

    #Remove old drop logs with hit count under 100
    if ($count < $error_count_min) {
      debug("Count ($count) is under $error_count_min. next", "debug", \[caller(0)] ) if $debug > 1;
      next LOG;
    }

    #Add the data to %db hash
    debug("Adding to %db. $vsid, $err, $count",  $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 1;
    $db_local{"$vsid,,,$err"} = $count;
  }

  debug("return data: ".Dumper(%db_local),  $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 1;
  return %db_local;
}

sub get_reason {
  debug("start", "debug", \[caller(0)] ) if $debug > 2;
  debug("Input data: ".Dumper(@_), "debug", \[caller(0)] ) if $debug > 2;

  my %input = @_;

  unless (defined $input{'data'}) {
    debug("Missing input data: 'data'. exit", "fatal", \[caller(0)] ) if $fatal;
    exit;
  }

  my $reason = "";

  #Check %drop_reason START
  DROP_REASON:
  foreach my $key (keys %drop_reason) {
    my $drop_name = $drop_reason{$key};
    
    if ($input{'data'} =~ /$key/i) {
      debug("foreach %drop_reason matched on $key", "debug", \[caller(0)] ) if $debug > 1;
      $reason = $drop_reason{$key};
      return $reason;
    }
  }
  #Check %drop_reason END



  ($reason) = $input{'data'} =~ /Reason: (.*)/;

  ($reason) = $input{'data'} =~ /reason: (.*?),/                          unless $reason;

  ($reason) = $input{'data'} =~ /:\s{0,}(.*?),\s{0,}conn:/                unless $reason;

  ($reason) = $input{'data'} =~ /:\s{0,}(.*?)\s{0,}dir/                   unless $reason;

  ($reason) = $input{'data'} =~ /:\s{0,}(.*?)\s{0,}for/                   unless $reason;

  ($reason) = $input{'data'} =~ /cmik_loader_fw_context_match_cb: (.*?);/ unless $reason;

  ($reason) = $input{'data'} =~ /:\s{0,}(.*?)\s{0,},/                     unless $reason;

  ($reason) = $input{'data'} =~ /:\s{0,}(.*?)\s{0,};/                     unless $reason;

  ($reason) = $input{'data'} =~ /:\s{0,}(.*?)\s{0,}</                     unless $reason;

  #($reason) = $input{'data'} =~ /dropped by (.*)/                        unless $reason;

  ($reason) = $input{'data'} =~ /\];(.*?):/                               unless $reason;

  unless ($reason) {
    debug("Could not find reason. return \$reason", "debug", \[caller(0)] ) if $debug > 1;
    return $reason;
  } 

  #Remove digits from instance in reason
  $reason =~ s/Instance \d{1,} /Instance /;

  #Remove ; from $reason
  $reason =~ s/;//g;

  #Remove space from end of line in $reason
  $reason =~ s/\s{1,}$//;

  #Remove SIM
  $reason =~ s/\[SIM.*]//g;

  #Remove worker
  $reason =~ s/\[fw.*?\]//g;

  #Remove tid
  $reason =~ s/\[tid.*?\]//g;

  #Remove vsid
  $reason =~ s/vsid=\d{1,}//g;

  $reason =~ s/\[|\]//g;

  #Change ,,, to ,, The log file uses ,,, as row seperator
  $reason =~ s/,,,/,,/g;

  $reason = lc $reason;


  debug("returning data: '$reason'", "debug", \[caller(0)] ) if $debug > 4;
  debug("end", "debug", \[caller(0)] ) if $debug > 2;
  return $reason;

}

sub get_discovery {
  my $sub_name = (caller(0))[3];
  debug("start", "debug", $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 1;
  debug("Input: ".Dumper(@_), "debug", $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 3;

  #print Dumper %config;

  my %input = @_;
  my @json;

  DB:
  foreach (keys %db){
    chomp; 
    debug("foreach %db: '$_'",  $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 1;

    #Split the data in to variables
    my ($vsid,$err) = split/,,,/, $_;
    my $count = $db{$_};

    debug("vsid: '$vsid', error: '$err', count: '$count'",  $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 1;

    #Sanity check the input. Skip the line if something is wrong with it
    unless (defined $vsid and defined $err and defined $count) {
      debug("validation failed for line: '$_'",  'error', \[caller(0)]) if $config{'log'}{'error'}{'enabled'} and $config{'log'}{'error'}{'level'} > 1;
      print "failed\n";
      next DB;
    }
    debug("\$vsid: '$vsid'. \$error: '$error'. \$count: '$count'",  $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 1;

    #next if $count < 100_000;

    $vsid =~ s/^vs_//;

    if (not defined $tmp{'cache'}{get_vsname}{$vsid}) {
      debug("KFO::lib::get_vsname($vsid);",  $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 1;
      $tmp{'cache'}{get_vsname}{$vsid} = KFO::lib::get_vsname($vsid);

      unless (defined $tmp{'cache'}{get_vsname}{$vsid}) {
        debug("No data returned from KFO::lib::get_vsname($vsid). next DB",  'error', \[caller(0)]) if $config{'log'}{'error'}{'enabled'} and $config{'log'}{'error'}{'level'} > 1;
        next DB;
      }

    }
    debug("\$vsname: '$tmp{'cache'}{get_vsname}{$vsid}'", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

    my %data = (
      '{#VSNAME}'   => $tmp{'cache'}{get_vsname}{$vsid},
      '{#VSID}'     => $vsid,
      '{#NAME}'     => $err,
      '{#COUNT}'    => $count,
    );
    debug("\%data: ".Dumper(%data),  $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 1;

    #print Dumper %data;
    push @json, \%data;
  }

  my $json = KFO::lib::hash_to_json( 'hash_ref' => \@json);
  debug("\$json: '$json'",  $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 1;

  #print Dumper %config;
  debug("end", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 2;
  return $json;
}

sub get_data {
  debug("start", "debug", \[caller(0)] ) if $debug > 2;
  debug("Input data: ".Dumper(@_), "debug", \[caller(0)] ) if $debug > 2;

  my %input = @_;
  my @json;

  unless (defined $input{'vsid'}) {
    debug("Missing input data: 'vsid'. exit", "fatal", \[caller(0)] ) if $fatal;
    exit;
  }

  unless (defined $input{'name'}) {
    debug("Missing input data: 'name'. exit", "fatal", \[caller(0)] ) if $fatal;
    exit;
  }


  foreach (keys %db){
    chomp; 
    debug("foreach %db: '$_'", "debug", \[caller(0)] ) if $debug > 1;

    #Split the data in to variables
    my ($vsid,$err) = split/,,,/, $_;
    my $count = $db{$_};

    $vsid =~ s/^vs_//;

    debug("vsid: '$vsid', error: '$err', count: '$count'", "debug", \[caller(0)] ) if $debug > 1;

    #Sanity check the input. Skip the line if something is wrong with it
    next unless defined $vsid and defined $err and defined $count;

    #next if $count < 100_000;

    debug("$input{'name'} eq $err) and ($input{'vsid'} eq $vsid)", "debug", \[caller(0)] ) if $debug > 3;
    if ( ($input{'name'} eq $err) and ($input{'vsid'} eq $vsid) ){
      debug("Found match on VSID and Error message. print $count. exit", "debug", \[caller(0)] ) if $debug;
      print $count;
      exit;
    }
  }
  debug("No data found in file. Something is wrong", "warning", \[caller(0)] ) if $warning;

  debug("end", "debug", \[caller(0)] ) if $debug > 2;
  return 0;
}

sub get_fw_ctl_command {
  debug("start", "debug", \[caller(0)] ) if $debug > 2;
  debug("Input data: ".Dumper(@_), "debug", \[caller(0)] ) if $debug > 2;

  my %input = @_;
  my $cmd;
  my $cmd_fw_80_10 = "fw ctl zdebug -m fw + drop";
  my $cmd_fw_80_20 = "fw ctl zdebug -v all -m fw + drop";

  my $cp_ver = KFO::lib::get_cp_version(); 

  unless (defined $cp_ver) {
    debug("Missing Check Point version number from get_cp_version(). exit", "fatal", \[caller(0)] ) if $fatal;
    exit;
  }

  if ($cp_ver < 8020) {
    debug("Check Point version is less than R80.20. CMD: '$cmd_fw_80_10'", "debug", \[caller(0)] ) if $debug > 1;
    $cmd = $cmd_fw_80_10;
  } 
  elsif ($cp_ver >= 8010) {
    debug("Check Point version is more than R80.10. CMD: '$cmd_fw_80_20'", "debug", \[caller(0)] ) if $debug > 1;
    $cmd = $cmd_fw_80_20;
  } 
  else {
    debug("Check Point version is unknown. version: '$cp_ver'. return", "fatal", \[caller(0)] ) if $fatal;
    return;
  }

  debug("end", "debug", \[caller(0)] ) if $debug > 2;
  return $cmd;
}

sub start_debug_process {
  debug("start", "debug", \[caller(0)] ) if $debug > 2;
  debug("Input data: ".Dumper(@_), "debug", \[caller(0)] ) if $debug > 2;


  debug("foreach 1 .. 3", "debug", \[caller(0)] ) if $debug > 1;
  TRY:
  foreach my $try (1 .. 3) {
    debug("try: $try", "debug", \[caller(0)] ) if $debug > 1;

    debug("Running the command: '$cmd_fw'", "debug", \[caller(0)] ) if $debug > 1;
    open my $fh_r,"-|", "$cmd_fw 2>&1"  or die "Can't run $cmd_fw: $!";

    #Failed to unset debug filter
    #Debug state was reset to default
    my $line = readline $fh_r;
    if ($line =~ /Failed/) {
      #if ($line =~ /Failed|reset to default/) {
      debug("Failed found in command output. next. Line: '$line'", "debug", \[caller(0)] ) if $debug > 1;
      close $fh_r;
      sleep 2;
      next TRY;
    }
    else {
      debug("Failed not found in command output. return \$fh_r. Line: '$line'", "debug", \[caller(0)] ) if $debug > 1;
      return $fh_r;
    }
  }

  debug("Could not run the command. Failed. return undef", "debug", \[caller(0)] ) if $fatal;
  return undef;
}

__DATA__

;[vs_2];[tid_1];[fw4_1];fw_log_drop_ex: Packet proto=17 10.130.2.101:0 -> 10.130.3.101:49152 dropped by asm_stateless_verifier Reason: UDP src/dst port 0;


#From log file


vs_0,,,ipsec_encrypt failed: failed to find sa. dropping packet... conn: <52.112.144.205,,,34607

#map address spoofing to address spoofing
vs_0,,,address spoofing,,,19454
vs_0,,,anti-spoofing,,,19252

#Remove (.*?)
vs_0,,,drop due vpn_ipsec_encrypt returns pkt_drop(3),,,1097381

#remove rule id
vs_0,,,drop template rule id 1858 (inbound),,,117100
vs_0,,,drop template rule id 1859 (inbound),,,1381269
vs_0,,,drop template rule id 1860 (inbound),,,186985

#remove ( and ). replace with - 
vs_0,,,ip multicast routing failed (missing os route),,,6037169

#remove
#   <
#   >
#   .
vs_0,,,ipsec_encrypt failed: failed to find sa. dropping packet... conn: <52.112.144.205,,,34607
vs_0,,,ipsec_encrypt failed: failed to find sa. dropping packet... conn: <52.115.133.252,,,39667

#remove tracking level is 0
vs_0,,,rule 1858 tracking level is 0,,,117097
vs_0,,,rule 1859 tracking level is 0,,,1381254

#remove -1
vs_0,,,sending packet dropped notification drop mode: 0 debug mode: 1 send as is: 0 track_lvl: -1,,,284759

#replace -> with -
vs_0,,,vpn decrypt returned drop -> dropping packet,,,1789
vs_0,,,vpn decrypt returned drop: replay counter verification failed -> dropping packet,,,875527

