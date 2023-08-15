#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;

#TODO

#Changes
#2022.02.01 - New syntax for the debug command. -v all to debug all VS


#use warnings;
use Fcntl qw(:flock SEEK_END); #Module for file lock

#Print the data immediately. Don't wait for full buffer
$|++;

#Zabbix test that will have to print out zabbix test ok. If not, the script will not download
if (@ARGV and $ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

#Print the input the script is started with
debug("$0 Input data ".join " ",@ARGV);

our $debug            = 0;                                                            #Set to 1 if you want debug data and no fork
our $info             = 1;
our $warning          = 1;
our $error            = 1;
our $fatal            = 1;

my $dir_tmp           = "/tmp/zabbix/fw_ctl_debug_drop";
our $file_error       = "$dir_tmp/error.log";
my $version           = 102;                                                          #Version of the script. If the version runnin is older than this, kill the old script
my $run_time          = shift @ARGV || 10;                                            #Run the fw debug for NN minutes
my $log_file          = shift @ARGV || "/tmp/zabbix/fw_ctl_debug_drop/drop.log";      #What log file to use
my $lock_file         = shift @ARGV || "/tmp/zabbix/fw_ctl_debug_drop/drop.lock";     #What lock file to use
my $time_file         = shift @ARGV || "/tmp/zabbix/fw_ctl_debug_drop/dbg_time.log";  #debug drop timestamp file
my $stop_file         = shift @ARGV || "/tmp/zabbix/fw_ctl_debug_drop/stop";          #STOP file
my $parsing_file      = shift @ARGV || "/tmp/zabbix/fw_ctl_debug_drop/parsing_error.log";
my ($log_dir)         = $log_file =~ /(.*)\//;                                        #Extract directory from log file path
$0                    = "fw ctl debug drop VER $version";                             #Set the process name
my $file_gzip         = "$dir_tmp/command_output.gz";

#fw ctl debug -h
#my $cmd_fw           = "fw ctl zdebug -m fw + drop";                                 #fw ctl debug command. R80.10-
my $cmd_fw            = "fw ctl zdebug -v all -m fw + drop";                          #fw ctl debug command. R80.30+

my $kill_time         = 4;                                                            #Kill the fw ctl debug if it's older than N hours
my $cpu_count_minimum = 4;
my %db                = ();                                                           #Set an empty hash
my %ip                = ();                                                           #Set an empty hash

#Exit if stop file found
exit if -f $stop_file;

#Exit if this is not a gw
exit unless is_gw();

#Exit the script if there is less than 4 CPU cores
exit if cpu_count() < $cpu_count_minimum;

#Check if debug fw drop is enabled. Create a file. If the file is older than $kill_time the command fw ctl debug 0 will run
check_debug_drop();

#Kill old running fw ctl debug if more than 4 hours old
kill_old_fw_ctl_debug("fw ctl zdebug");

#Check if the running process is older than this version
#If older version found, kill it
is_old_version_running();

#Create zabbix tmp directory
create_dir($log_dir);

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

#Build the hash from old log file
foreach (`cat $log_file 2>/dev/null`){
  debug("Reading from old log file $_");
  chomp;

  #Split the data in to variables
  my ($vsid,$err,$count) = split/,,,/;

  #There is no need to log a rulebase drop
  #next if $err =~ /Rulebase/;
  #next if $err =~ /matched drop template/;
  $err =~ s/Instance \d{1,} /Instance /;

  $vsid = "vs_0" if $vsid =~ /cpu/;
  $vsid = "vs_0" if $vsid eq "kern";

  #Sanity check the input. Skip the line if something is wrong with it
  next unless $vsid =~ /vs_\d/ && $err && $count;

  #Remove old drop logs with hit count under 100
  next if $count < 100;

  #Add the data to %db hash
  $db{"$vsid,,,$err"} = $count;
}

#copy the old log file to tmp
my $cmd_cp = "cp -f $log_file $log_file.tmp 2>/dev/null";
debug("copy old log file: $cmd_cp");
system $cmd_cp;

my $fh_lock_w;
#Open lock file
debug("Open lock file $lock_file");
open $fh_lock_w,">", $lock_file or die "Can't write to $lock_file: $!";

#Open parsing error file
debug("Open parsing error file $lock_file");
open my $fh_parsing_w,">", $parsing_file or die "Can't write to $parsing_file: $!";

#Exit if it takes more than 1 sec to lock the lock file.
#Don't start the script if it's already running
local $SIG{ALRM} = sub { die "\n" };
alarm 1;

#Lock the log file
debug("Lock the lock file");
flock($fh_lock_w, LOCK_EX) or die "Cannot lock $lock_file $!\n";

#Reset the alarm
alarm 0;

#Run the command
debug("Running the command: $cmd_fw");
open my $fw_r,"-|", $cmd_fw or die "Can't run $cmd_fw: $!";

#Delete old output file
unlink "$file_gzip.old" if -f "$file_gzip.old";

#Rename old output file 
rename $file_gzip,"$file_gzip.old" or die "Can't rename $file_gzip to $file_gzip.old: $!";

#Start gzip for sending output from command
open my $gzip_w,"|-", "gzip -9 >$file_gzip";

#Get the current time. The command will run for $run_time
my $time_startup = time;

#Get the current time for the write time
my $time_write = time;

#Loop the command output
MAIN: while ($_ = <$fw_r>) {

  print $_ if $debug;

  #Exit if the run time is up
  if ((time - $time_startup) > ($run_time*60)){
    debug("The command has been running for more than $run_time minutes. Will exit");
    write_log($log_file, \%db);
    kill_process("fw ctl zdebug");
    exit;
  }

  #Save data to lof file every N min
  #Write to log file every minute
  if ((time - $time_write) > (1*60)){
    debug("The command has been running for more than 1 minute. Will write to log file");
    $time_write = time; #Reset the timeer
    write_log($log_file, \%db);
  }

  #ClusterXL drop
  next if /Log was sent successfully to FW/;

  #Add output to $file_gzip
  print $gzip_w $_;

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
  #s/^\@//;

  #Remove ; as the first char
  #s/^;//;

  #Get the reason for the drop log
  my $reason;
  ($reason) = /Reason: (.*)/;

  ($reason) = /reason: (.*?),/ unless $reason;

  ($reason) = /:\s{0,}(.*?),\s{0,}conn:/ unless $reason;

  ($reason) = /:\s{0,}(.*?)\s{0,}dir/ unless $reason;

  ($reason) = /:\s{0,}(.*?)\s{0,}for/ unless $reason;

  ($reason) = /cmik_loader_fw_context_match_cb: (.*?);/ unless $reason;

  ($reason) = /:\s{0,}(.*?)\s{0,},/ unless $reason;

  ($reason) = /:\s{0,}(.*?)\s{0,};/ unless $reason;

  ($reason) = /:\s{0,}(.*?)\s{0,}</ unless $reason;

  #($reason) = /dropped by (.*)/ unless $reason;

  ($reason) = /\];(.*?):/ unless $reason;


  #If we can't get a reason. Add line to parsing error file
  unless ($reason) {
    error("Missing reason. $_");
    debug("Missing reason. $_", "error", \[caller(0)] ) if $error;
    print $fh_parsing_w "Missing reason. $_\n";

    $db{'NA,,,Could not parse reason'} +=1;
    $db{"unknown,,,Total drop"} += 1;
    next;
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

  #Get the VSID
  my $vsid;

  $vsid = get_vsid($_);

  #debug("VSID found: $vsid");

  #If we can't get a VSID. Add line to parsing error file
  unless (defined $vsid) {
    print $fh_parsing_w "Missing VSID. $_\n";
    $db{'NA,,,Could not parse reason'} +=1;
  }

  unless (defined $vsid){
    $vsid = "unknown";
    debug("Could not extract VSID from line: $_");
  }
  $vsid = "vs_$vsid";


  #Drop counter
  $db{"$vsid,,,Total drop"} += 1;

  my @ip = get_ip($_);
  #debug("Found IP address: ".join ", ", @ip);

  foreach my $ip (@ip) {
    next if $ip =~ /\.255$/;
    $db{"$vsid,,,IP: $ip"}++;
  }

  my @port = get_port($_);
  #debug("Found port: ".join ", ", @port);

  foreach my $port (@port) {
    $db{"$vsid,,,Port: $port"}++;
  }


  #Filter out
  next if $reason =~ /Rulebase/i;
  next if $reason =~ /matched drop template/i;

  #+1 the reason counter in the hash
  $db{"$vsid,,,$reason"} += 1;

  debug("VSID: $vsid. reason: $reason");

}

sub write_log {
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
    next if $db{$_} < 10000;

    #Print the value to $log_file
    print $fh_w_log "$_,,,$db{$_}\n";
  }

  #Close the $log_file
  close $fh_w_log;
}


sub is_old_version_running {
  my $name = $0;
  $name =~ s/ VER.*//;

  my $cmd = qq#ps xa|grep "$name"#;
  debug($cmd);

  foreach (`$cmd`){
    s/^\s{1,}//;

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
  debug("No old process found");

}

sub kill_process {
  my $name = shift or die "Need a process name to kill";
  debug("Kill process subrutine with input: $name");

  foreach (`ps xa`){
    next unless /$name/;
    debug("ps xa: found $name: $_");
    s/^\s{1,}//;

    #PID TTY      STAT   TIME COMMAND
    my ($pid,$tty,$stat,$time,$command) = split /\s{1,}/;

    debug("kill $pid");
    system "kill $pid";
    sleep 1;
    system "kill -9 $pid";
    system "fw ctl debug 0 &>/dev/null";
  }
}

sub kill_old_fw_ctl_debug {
  my $name  = shift or die "Need a process name to kill";
  my $hours = shift || 4;
  debug("Kill process subrutine with input: $name");

  foreach (`ps xau`){
    next unless /$name/;
    debug("ps xa: found $name: $_");
    s/^\s{1,}//;

    #USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
    my ($user,$pid,$cpu,$mem,$vsz,$rss,$tty,$stat,$start,$time,$command) = split /\s{1,}/;

    #Convert start time to unix time
    my $start_unix = `date -d "$start" +"%s"`;
    chomp $start_unix;
    debug("Found start time of process $start. Converted to unix time $start_unix");

    #Kill running fw ctl if start time is more than 4 hours
    if ( (time - $start_unix) > (4*60*60) ){
      debug("Found that process is older than 4 hours. Will kill it");
      debug("kill $pid");
      system "kill $pid &>/dev/null";
      sleep 1;
      system "kill -9 $pid &>/dev/null";
      system "fw ctl debug 0 &>/dev/null";
    }
  }
}

sub check_debug_drop {
  debug("Starting subrutine check_debug_drop");

  #Looking for fw drop
  if (`fw ctl debug` =~ /Module: fw.*drop.*Common/s){
    debug("fw drop debug enabled");

    my $time = time;

    debug("Looking for $time_file");
    if (-f $time_file) {
      debug("$time_file found. Will check the mtime");

      my $ctime = (stat($time_file))[9];

      if ( (time - $ctime) > ($kill_time*60*60) ) {
        debug("$time_file is older than $kill_time. Will run fw ctl debug 0");
        unlink $time_file;
        system "fw ctl debug 0 &>/dev/null";

      }
      else {
        debug("File is not older than $kill_time hours. Will print 9999 and exit");
        print 9999;
        exit;
      }
    }
    else {
      debug("Creating timestamp file");

      system "echo $time >$time_file 2>/dev/null";
      print 9999;
    }
  }

}

sub get_vsid {
  my $line = shift;
  my $vsid;

  #debug("get_vsid. input: $line");

  unless (defined $line) {
    error("sub get_vsid. Missing input data");
    return;
  }

  return 0 if $line =~ /^@/;
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
  my @return;

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
    push @return, @ip if @ip;
  }

  return @return;
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

__DATA__

;[vs_2];[tid_1];[fw4_1];fw_log_drop_ex: Packet proto=17 10.130.2.101:0 -> 10.130.3.101:49152 dropped by asm_stateless_verifier Reason: UDP src/dst port 0;


#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;


#use warnings;
use Fcntl qw(:flock SEEK_END); #Module for file lock

#Print the data immediately. Don't wait for full buffer
$|++;

#Zabbix test that will have to print out zabbix test ok. If not, the script will not download
if (@ARGV and $ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

#Print the input the script is started with
debug("$0 Input data ".join " ",@ARGV);

our $debug            = 0;                                                            #Set to 1 if you want debug data and no fork
our $info             = 1;
our $warning          = 1;
our $error            = 1;
our $fatal            = 1;

my $dir_tmp           = "/tmp/zabbix/fw_ctl_debug_drop";
our $file_error       = "$dir_tmp/error.log";
my $version           = 102;                                                          #Version of the script. If the version runnin is older than this, kill the old script
my $run_time          = shift @ARGV || 10;                                            #Run the fw debug for NN minutes
my $log_file          = shift @ARGV || "/tmp/zabbix/fw_ctl_debug_drop/drop.log";      #What log file to use
my $lock_file         = shift @ARGV || "/tmp/zabbix/fw_ctl_debug_drop/drop.lock";     #What lock file to use
my $time_file         = shift @ARGV || "/tmp/zabbix/fw_ctl_debug_drop/dbg_time.log";  #debug drop timestamp file
my $stop_file         = shift @ARGV || "/tmp/zabbix/fw_ctl_debug_drop/stop";          #STOP file
my $parsing_file      = shift @ARGV || "/tmp/zabbix/fw_ctl_debug_drop/parsing_error.log";
my ($log_dir)         = $log_file =~ /(.*)\//;                                        #Extract directory from log file path
$0                    = "fw ctl debug drop VER $version";                             #Set the process name
my $file_gzip         = "$dir_tmp/command_output.gz";

#fw ctl debug -h
#my $cmd_fw           = "fw ctl zdebug -m fw + drop";                                 #fw ctl debug command. R80.10-
my $cmd_fw            = "fw ctl zdebug -v all -m fw + drop";                          #fw ctl debug command. R80.30+

my $kill_time         = 4;                                                            #Kill the fw ctl debug if it's older than N hours
my $cpu_count_minimum = 4;
my %db                = ();                                                           #Set an empty hash
my %ip                = ();                                                           #Set an empty hash

#Exit if stop file found
exit if -f $stop_file;

#Exit if this is not a gw
exit unless is_gw();

#Exit the script if there is less than 4 CPU cores
exit if cpu_count() < $cpu_count_minimum;

#Check if debug fw drop is enabled. Create a file. If the file is older than $kill_time the command fw ctl debug 0 will run
check_debug_drop();

#Kill old running fw ctl debug if more than 4 hours old
kill_old_fw_ctl_debug("fw ctl zdebug");

#Check if the running process is older than this version
#If older version found, kill it
is_old_version_running();

#Create zabbix tmp directory
create_dir($log_dir);

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

#Build the hash from old log file
foreach (`cat $log_file 2>/dev/null`){
  debug("Reading from old log file $_");
  chomp;

  #Split the data in to variables
  my ($vsid,$err,$count) = split/,,,/;

  #There is no need to log a rulebase drop
  #next if $err =~ /Rulebase/;
  #next if $err =~ /matched drop template/;
  $err =~ s/Instance \d{1,} /Instance /;

  $vsid = "vs_0" if $vsid =~ /cpu/;
  $vsid = "vs_0" if $vsid eq "kern";

  #Sanity check the input. Skip the line if something is wrong with it
  next unless $vsid =~ /vs_\d/ && $err && $count;

  #Remove old drop logs with hit count under 100
  next if $count < 100;

  #Add the data to %db hash
  $db{"$vsid,,,$err"} = $count;
}

#copy the old log file to tmp
my $cmd_cp = "cp -f $log_file $log_file.tmp 2>/dev/null";
debug("copy old log file: $cmd_cp");
system $cmd_cp;

my $fh_lock_w;
#Open lock file
debug("Open lock file $lock_file");
open $fh_lock_w,">", $lock_file or die "Can't write to $lock_file: $!";

#Open parsing error file
debug("Open parsing error file $lock_file");
open my $fh_parsing_w,">", $parsing_file or die "Can't write to $parsing_file: $!";

#Exit if it takes more than 1 sec to lock the lock file.
#Don't start the script if it's already running
local $SIG{ALRM} = sub { die "\n" };
alarm 1;

#Lock the log file
debug("Lock the lock file");
flock($fh_lock_w, LOCK_EX) or die "Cannot lock $lock_file $!\n";

#Reset the alarm
alarm 0;

#Run the command
debug("Running the command: $cmd_fw");
open my $fw_r,"-|", $cmd_fw or die "Can't run $cmd_fw: $!";

#Delete old output file
unlink "$file_gzip.old" if -f "$file_gzip.old";

#Rename old output file 
rename $file_gzip,"$file_gzip.old" or die "Can't rename $file_gzip to $file_gzip.old: $!";

#Start gzip for sending output from command
open my $gzip_w,"|-", "gzip -9 >$file_gzip";

#Get the current time. The command will run for $run_time
my $time_startup = time;

#Get the current time for the write time
my $time_write = time;

#Loop the command output
MAIN: while ($_ = <$fw_r>) {

  print $_ if $debug;

  #Exit if the run time is up
  if ((time - $time_startup) > ($run_time*60)){
    debug("The command has been running for more than $run_time minutes. Will exit");
    write_log($log_file, \%db);
    kill_process("fw ctl zdebug");
    exit;
  }

  #Save data to lof file every N min
  #Write to log file every minute
  if ((time - $time_write) > (1*60)){
    debug("The command has been running for more than 1 minute. Will write to log file");
    $time_write = time; #Reset the timeer
    write_log($log_file, \%db);
  }

  #ClusterXL drop
  next if /Log was sent successfully to FW/;

  #Add output to $file_gzip
  print $gzip_w $_;

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
  #s/^\@//;

  #Remove ; as the first char
  #s/^;//;

  #Get the reason for the drop log
  my $reason;
  ($reason) = /Reason: (.*)/;

  ($reason) = /reason: (.*?),/ unless $reason;

  ($reason) = /:\s{0,}(.*?),\s{0,}conn:/ unless $reason;

  ($reason) = /:\s{0,}(.*?)\s{0,}dir/ unless $reason;

  ($reason) = /:\s{0,}(.*?)\s{0,}for/ unless $reason;

  ($reason) = /cmik_loader_fw_context_match_cb: (.*?);/ unless $reason;

  ($reason) = /:\s{0,}(.*?)\s{0,},/ unless $reason;

  ($reason) = /:\s{0,}(.*?)\s{0,};/ unless $reason;

  ($reason) = /:\s{0,}(.*?)\s{0,}</ unless $reason;

  #($reason) = /dropped by (.*)/ unless $reason;

  ($reason) = /\];(.*?):/ unless $reason;


  #If we can't get a reason. Add line to parsing error file
  unless ($reason) {
    error("Missing reason. $_");
    debug("Missing reason. $_", "error", \[caller(0)] ) if $error;
    print $fh_parsing_w "Missing reason. $_\n";

    $db{'NA,,,Could not parse reason'} +=1;
    $db{"unknown,,,Total drop"} += 1;
    next;
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

  #Get the VSID
  my $vsid;

  $vsid = get_vsid($_);

  #debug("VSID found: $vsid");

  #If we can't get a VSID. Add line to parsing error file
  unless (defined $vsid) {
    print $fh_parsing_w "Missing VSID. $_\n";
    $db{'NA,,,Could not parse reason'} +=1;
  }

  unless (defined $vsid){
    $vsid = "unknown";
    debug("Could not extract VSID from line: $_");
  }
  $vsid = "vs_$vsid";


  #Drop counter
  $db{"$vsid,,,Total drop"} += 1;

  my @ip = get_ip($_);
  #debug("Found IP address: ".join ", ", @ip);

  foreach my $ip (@ip) {
    next if $ip =~ /\.255$/;
    $db{"$vsid,,,IP: $ip"}++;
  }

  my @port = get_port($_);
  #debug("Found port: ".join ", ", @port);

  foreach my $port (@port) {
    $db{"$vsid,,,Port: $port"}++;
  }


  #Filter out
  next if $reason =~ /Rulebase/i;
  next if $reason =~ /matched drop template/i;

  #+1 the reason counter in the hash
  $db{"$vsid,,,$reason"} += 1;

  debug("VSID: $vsid. reason: $reason");

}

sub write_log {
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
    next if $db{$_} < 10000;

    #Print the value to $log_file
    print $fh_w_log "$_,,,$db{$_}\n";
  }

  #Close the $log_file
  close $fh_w_log;
}


sub is_old_version_running {
  my $name = $0;
  $name =~ s/ VER.*//;

  my $cmd = qq#ps xa|grep "$name"#;
  debug($cmd);

  foreach (`$cmd`){
    s/^\s{1,}//;

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
  debug("No old process found");

}

sub kill_process {
  my $name = shift or die "Need a process name to kill";
  debug("Kill process subrutine with input: $name");

  foreach (`ps xa`){
    next unless /$name/;
    debug("ps xa: found $name: $_");
    s/^\s{1,}//;

    #PID TTY      STAT   TIME COMMAND
    my ($pid,$tty,$stat,$time,$command) = split /\s{1,}/;

    debug("kill $pid");
    system "kill $pid";
    sleep 1;
    system "kill -9 $pid";
    system "fw ctl debug 0 &>/dev/null";
  }
}

sub kill_old_fw_ctl_debug {
  my $name  = shift or die "Need a process name to kill";
  my $hours = shift || 4;
  debug("Kill process subrutine with input: $name");

  foreach (`ps xau`){
    next unless /$name/;
    debug("ps xa: found $name: $_");
    s/^\s{1,}//;

    #USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
    my ($user,$pid,$cpu,$mem,$vsz,$rss,$tty,$stat,$start,$time,$command) = split /\s{1,}/;

    #Convert start time to unix time
    my $start_unix = `date -d "$start" +"%s"`;
    chomp $start_unix;
    debug("Found start time of process $start. Converted to unix time $start_unix");

    #Kill running fw ctl if start time is more than 4 hours
    if ( (time - $start_unix) > (4*60*60) ){
      debug("Found that process is older than 4 hours. Will kill it");
      debug("kill $pid");
      system "kill $pid &>/dev/null";
      sleep 1;
      system "kill -9 $pid &>/dev/null";
      system "fw ctl debug 0 &>/dev/null";
    }
  }
}

sub check_debug_drop {
  debug("Starting subrutine check_debug_drop");

  #Looking for fw drop
  if (`fw ctl debug` =~ /Module: fw.*drop.*Common/s){
    debug("fw drop debug enabled");

    my $time = time;

    debug("Looking for $time_file");
    if (-f $time_file) {
      debug("$time_file found. Will check the mtime");

      my $ctime = (stat($time_file))[9];

      if ( (time - $ctime) > ($kill_time*60*60) ) {
        debug("$time_file is older than $kill_time. Will run fw ctl debug 0");
        unlink $time_file;
        system "fw ctl debug 0 &>/dev/null";

      }
      else {
        debug("File is not older than $kill_time hours. Will print 9999 and exit");
        print 9999;
        exit;
      }
    }
    else {
      debug("Creating timestamp file");

      system "echo $time >$time_file 2>/dev/null";
      print 9999;
    }
  }

}

sub get_vsid {
  my $line = shift;
  my $vsid;

  #debug("get_vsid. input: $line");

  unless (defined $line) {
    error("sub get_vsid. Missing input data");
    return;
  }

  return 0 if $line =~ /^@/;
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
  my @return;

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
    push @return, @ip if @ip;
  }

  return @return;
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

__DATA__

;[vs_2];[tid_1];[fw4_1];fw_log_drop_ex: Packet proto=17 10.130.2.101:0 -> 10.130.3.101:49152 dropped by asm_stateless_verifier Reason: UDP src/dst port 0;


#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;


#use warnings;
use Fcntl qw(:flock SEEK_END); #Module for file lock

#Print the data immediately. Don't wait for full buffer
$|++;

#Zabbix test that will have to print out zabbix test ok. If not, the script will not download
if (@ARGV and $ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

#Print the input the script is started with
debug("$0 Input data ".join " ",@ARGV);

our $debug            = 0;                                                            #Set to 1 if you want debug data and no fork
our $info             = 1;
our $warning          = 1;
our $error            = 1;
our $fatal            = 1;

my $dir_tmp           = "/tmp/zabbix/fw_ctl_debug_drop";
our $file_error       = "$dir_tmp/error.log";
my $version           = 102;                                                          #Version of the script. If the version runnin is older than this, kill the old script
my $run_time          = shift @ARGV || 10;                                            #Run the fw debug for NN minutes
my $log_file          = shift @ARGV || "/tmp/zabbix/fw_ctl_debug_drop/drop.log";      #What log file to use
my $lock_file         = shift @ARGV || "/tmp/zabbix/fw_ctl_debug_drop/drop.lock";     #What lock file to use
my $time_file         = shift @ARGV || "/tmp/zabbix/fw_ctl_debug_drop/dbg_time.log";  #debug drop timestamp file
my $stop_file         = shift @ARGV || "/tmp/zabbix/fw_ctl_debug_drop/stop";          #STOP file
my $parsing_file      = shift @ARGV || "/tmp/zabbix/fw_ctl_debug_drop/parsing_error.log";
my ($log_dir)         = $log_file =~ /(.*)\//;                                        #Extract directory from log file path
$0                    = "fw ctl debug drop VER $version";                             #Set the process name
my $file_gzip         = "$dir_tmp/command_output.gz";

#fw ctl debug -h
#my $cmd_fw           = "fw ctl zdebug -m fw + drop";                                 #fw ctl debug command. R80.10-
my $cmd_fw            = "fw ctl zdebug -v all -m fw + drop";                          #fw ctl debug command. R80.30+

my $kill_time         = 4;                                                            #Kill the fw ctl debug if it's older than N hours
my $cpu_count_minimum = 4;
my %db                = ();                                                           #Set an empty hash
my %ip                = ();                                                           #Set an empty hash

#Exit if stop file found
exit if -f $stop_file;

#Exit if this is not a gw
exit unless is_gw();

#Exit the script if there is less than 4 CPU cores
exit if cpu_count() < $cpu_count_minimum;

#Check if debug fw drop is enabled. Create a file. If the file is older than $kill_time the command fw ctl debug 0 will run
check_debug_drop();

#Kill old running fw ctl debug if more than 4 hours old
kill_old_fw_ctl_debug("fw ctl zdebug");

#Check if the running process is older than this version
#If older version found, kill it
is_old_version_running();

#Create zabbix tmp directory
create_dir($log_dir);

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

#Build the hash from old log file
foreach (`cat $log_file 2>/dev/null`){
  debug("Reading from old log file $_");
  chomp;

  #Split the data in to variables
  my ($vsid,$err,$count) = split/,,,/;

  #There is no need to log a rulebase drop
  #next if $err =~ /Rulebase/;
  #next if $err =~ /matched drop template/;
  $err =~ s/Instance \d{1,} /Instance /;

  $vsid = "vs_0" if $vsid =~ /cpu/;
  $vsid = "vs_0" if $vsid eq "kern";

  #Sanity check the input. Skip the line if something is wrong with it
  next unless $vsid =~ /vs_\d/ && $err && $count;

  #Remove old drop logs with hit count under 100
  next if $count < 100;

  #Add the data to %db hash
  $db{"$vsid,,,$err"} = $count;
}

#copy the old log file to tmp
my $cmd_cp = "cp -f $log_file $log_file.tmp 2>/dev/null";
debug("copy old log file: $cmd_cp");
system $cmd_cp;

my $fh_lock_w;
#Open lock file
debug("Open lock file $lock_file");
open $fh_lock_w,">", $lock_file or die "Can't write to $lock_file: $!";

#Open parsing error file
debug("Open parsing error file $lock_file");
open my $fh_parsing_w,">", $parsing_file or die "Can't write to $parsing_file: $!";

#Exit if it takes more than 1 sec to lock the lock file.
#Don't start the script if it's already running
local $SIG{ALRM} = sub { die "\n" };
alarm 1;

#Lock the log file
debug("Lock the lock file");
flock($fh_lock_w, LOCK_EX) or die "Cannot lock $lock_file $!\n";

#Reset the alarm
alarm 0;

#Run the command
debug("Running the command: $cmd_fw");
open my $fw_r,"-|", $cmd_fw or die "Can't run $cmd_fw: $!";

#Delete old output file
unlink "$file_gzip.old" if -f "$file_gzip.old";

#Rename old output file 
rename $file_gzip,"$file_gzip.old" or die "Can't rename $file_gzip to $file_gzip.old: $!";

#Start gzip for sending output from command
open my $gzip_w,"|-", "gzip -9 >$file_gzip";

#Get the current time. The command will run for $run_time
my $time_startup = time;

#Get the current time for the write time
my $time_write = time;

#Loop the command output
MAIN: while ($_ = <$fw_r>) {

  print $_ if $debug;

  #Exit if the run time is up
  if ((time - $time_startup) > ($run_time*60)){
    debug("The command has been running for more than $run_time minutes. Will exit");
    write_log($log_file, \%db);
    kill_process("fw ctl zdebug");
    exit;
  }

  #Save data to lof file every N min
  #Write to log file every minute
  if ((time - $time_write) > (1*60)){
    debug("The command has been running for more than 1 minute. Will write to log file");
    $time_write = time; #Reset the timeer
    write_log($log_file, \%db);
  }

  #ClusterXL drop
  next if /Log was sent successfully to FW/;

  #Add output to $file_gzip
  print $gzip_w $_;

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
  #s/^\@//;

  #Remove ; as the first char
  #s/^;//;

  #Get the reason for the drop log
  my $reason;
  ($reason) = /Reason: (.*)/;

  ($reason) = /reason: (.*?),/ unless $reason;

  ($reason) = /:\s{0,}(.*?),\s{0,}conn:/ unless $reason;

  ($reason) = /:\s{0,}(.*?)\s{0,}dir/ unless $reason;

  ($reason) = /:\s{0,}(.*?)\s{0,}for/ unless $reason;

  ($reason) = /cmik_loader_fw_context_match_cb: (.*?);/ unless $reason;

  ($reason) = /:\s{0,}(.*?)\s{0,},/ unless $reason;

  ($reason) = /:\s{0,}(.*?)\s{0,};/ unless $reason;

  ($reason) = /:\s{0,}(.*?)\s{0,}</ unless $reason;

  #($reason) = /dropped by (.*)/ unless $reason;

  ($reason) = /\];(.*?):/ unless $reason;


  #If we can't get a reason. Add line to parsing error file
  unless ($reason) {
    error("Missing reason. $_");
    debug("Missing reason. $_", "error", \[caller(0)] ) if $error;
    print $fh_parsing_w "Missing reason. $_\n";

    $db{'NA,,,Could not parse reason'} +=1;
    $db{"unknown,,,Total drop"} += 1;
    next;
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

  #Get the VSID
  my $vsid;

  $vsid = get_vsid($_);

  #debug("VSID found: $vsid");

  #If we can't get a VSID. Add line to parsing error file
  unless (defined $vsid) {
    print $fh_parsing_w "Missing VSID. $_\n";
    $db{'NA,,,Could not parse reason'} +=1;
  }

  unless (defined $vsid){
    $vsid = "unknown";
    debug("Could not extract VSID from line: $_");
  }
  $vsid = "vs_$vsid";


  #Drop counter
  $db{"$vsid,,,Total drop"} += 1;

  my @ip = get_ip($_);
  #debug("Found IP address: ".join ", ", @ip);

  foreach my $ip (@ip) {
    next if $ip =~ /\.255$/;
    $db{"$vsid,,,IP: $ip"}++;
  }

  my @port = get_port($_);
  #debug("Found port: ".join ", ", @port);

  foreach my $port (@port) {
    $db{"$vsid,,,Port: $port"}++;
  }


  #Filter out
  next if $reason =~ /Rulebase/i;
  next if $reason =~ /matched drop template/i;

  #+1 the reason counter in the hash
  $db{"$vsid,,,$reason"} += 1;

  debug("VSID: $vsid. reason: $reason");

}

sub write_log {
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
    next if $db{$_} < 10000;

    #Print the value to $log_file
    print $fh_w_log "$_,,,$db{$_}\n";
  }

  #Close the $log_file
  close $fh_w_log;
}


sub is_old_version_running {
  my $name = $0;
  $name =~ s/ VER.*//;

  my $cmd = qq#ps xa|grep "$name"#;
  debug($cmd);

  foreach (`$cmd`){
    s/^\s{1,}//;

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
  debug("No old process found");

}

sub kill_process {
  my $name = shift or die "Need a process name to kill";
  debug("Kill process subrutine with input: $name");

  foreach (`ps xa`){
    next unless /$name/;
    debug("ps xa: found $name: $_");
    s/^\s{1,}//;

    #PID TTY      STAT   TIME COMMAND
    my ($pid,$tty,$stat,$time,$command) = split /\s{1,}/;

    debug("kill $pid");
    system "kill $pid";
    sleep 1;
    system "kill -9 $pid";
    system "fw ctl debug 0 &>/dev/null";
  }
}

sub kill_old_fw_ctl_debug {
  my $name  = shift or die "Need a process name to kill";
  my $hours = shift || 4;
  debug("Kill process subrutine with input: $name");

  foreach (`ps xau`){
    next unless /$name/;
    debug("ps xa: found $name: $_");
    s/^\s{1,}//;

    #USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
    my ($user,$pid,$cpu,$mem,$vsz,$rss,$tty,$stat,$start,$time,$command) = split /\s{1,}/;

    #Convert start time to unix time
    my $start_unix = `date -d "$start" +"%s"`;
    chomp $start_unix;
    debug("Found start time of process $start. Converted to unix time $start_unix");

    #Kill running fw ctl if start time is more than 4 hours
    if ( (time - $start_unix) > (4*60*60) ){
      debug("Found that process is older than 4 hours. Will kill it");
      debug("kill $pid");
      system "kill $pid &>/dev/null";
      sleep 1;
      system "kill -9 $pid &>/dev/null";
      system "fw ctl debug 0 &>/dev/null";
    }
  }
}

sub check_debug_drop {
  debug("Starting subrutine check_debug_drop");

  #Looking for fw drop
  if (`fw ctl debug` =~ /Module: fw.*drop.*Common/s){
    debug("fw drop debug enabled");

    my $time = time;

    debug("Looking for $time_file");
    if (-f $time_file) {
      debug("$time_file found. Will check the mtime");

      my $ctime = (stat($time_file))[9];

      if ( (time - $ctime) > ($kill_time*60*60) ) {
        debug("$time_file is older than $kill_time. Will run fw ctl debug 0");
        unlink $time_file;
        system "fw ctl debug 0 &>/dev/null";

      }
      else {
        debug("File is not older than $kill_time hours. Will print 9999 and exit");
        print 9999;
        exit;
      }
    }
    else {
      debug("Creating timestamp file");

      system "echo $time >$time_file 2>/dev/null";
      print 9999;
    }
  }

}

sub get_vsid {
  my $line = shift;
  my $vsid;

  #debug("get_vsid. input: $line");

  unless (defined $line) {
    error("sub get_vsid. Missing input data");
    return;
  }

  return 0 if $line =~ /^@/;
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
  my @return;

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
    push @return, @ip if @ip;
  }

  return @return;
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

__DATA__

;[vs_2];[tid_1];[fw4_1];fw_log_drop_ex: Packet proto=17 10.130.2.101:0 -> 10.130.3.101:49152 dropped by asm_stateless_verifier Reason: UDP src/dst port 0;



