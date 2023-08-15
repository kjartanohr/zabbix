#!/usr/bin/perl5.32.0
#bin
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
  #require "./lib.pm" if -f "./lib.pm";  #For local lib dev testing
}

#TODO
#Legge til sletting av mapper/directory
# utvid med to ekstra felt. En for filer 0/1, en for mapper 0/1
#

use warnings;
use strict;

$0 = "perl cleanup VER 100";
$|++;


our $dir_tmp              = "/tmp/zabbix/cleanup";
our $file_debug           = "$dir_tmp/debug.log";
my  $file_message         = "$dir_tmp/message.log";

our $debug                = 0;          #This needs to be 0 when running in production
our $info                 = 0;
our $warning              = 1;
our $error                = 1;
our $fatal                = 1;

my $dry_run               = 0;

#Deleted files counter
my $files_deleted_counter = 0;

$SIG{CHLD} = "IGNORE";

#Zabbix health check
zabbix_check($ARGV[0]);

#Check if this script is running
#exit if check_if_other_self_is_running($0, $$);

#Create tmp dir
create_dir($dir_tmp);

#Delete log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);


#End of standard header

#Print the last message to the zabbix agent
my $last_message = get_last_message('file' => $file_message) if -f $file_message;
if (defined $last_message and $last_message =~ /^\d*?$/ and $last_message > 0) {
  print $last_message;
}

#global ignore list
my @ignore = (
  "/home/",                             #Debug files
  '20\d\d-\d\d-\d\d',                   #Local log files
  'fw\.log',                            #Local log file
  '/var/log/jail/',                     #Jails
  "aspam_engine/customRules",           #Config files in tmp folder
);

# search_dir ;;; search string ;;; Minimum file size ;;; days old ;;; Must match regex ;;; Skip if match regex
# "dir ;;; string ;;; min ;;; days ;;; match ;;; no match",
my @search = (

  #Check Point loggfiler
  #CP sitt standard logg-format er .elg
  #Noen av disse filene blir ikke slettet i noen gitte situasjoner. Rar kombo av aktive blades hvor scriptene som skal slettes henger seg pga for mange filer i tmp kataloger
  "/ ;;; *.elg ;;; 100M ;;; ;;; ;;; ",

  #Linux og noen check point loggfile
  "/ ;;; *.log ;;; 100M ;;; ;;; ;;; ",

  #Check Point tmp filer. 
  #CP genererer opp til flere millioner filer. Dette gjør at find bruker lang tid og kommandoer som ls henger.
  #Dette gjør at CP og zabbix sine script henger.
  "/ ;;; CKP_mutex::* ;;; ;;; 7 ;;; tmp ;;; ",

  #Zabbix tmp filer. 2019
  #Gamle script har ikke skikkelig cleanup kode.
  "/tmp ;;; debug.log ;;; 20M ;;; ;;; ;;; ",
  
  #Check Point tmp filer. 2019
  #Div CP script dumper filer i /tmp uten å rydde opp etter seg.
  "/tmp ;;; * ;;; 100M ;;; ;;; ;;; ",

  #Threat Emulation R80.30
  #Ny tmp katalog fra R80.30, pr VS. En av disse mappene kan bli 60 GB på 7 dager. 2022.02.10. 
  #"/var/log/opt/CPsuite-R80.40/fw1/CTX/CTX00003/tmp/te/te_tmp_files ;;; string ;;; min ;;; days ;;; match ;;; no match",
  "/var/log/opt/ ;;; ;;; ;;; 1 ;;; \/tmp\/te\/te_tmp_files\/ ;;; ",

  #Threat Emulation R80.10. 2018
  #Felles TE tmp mapper.
  "/var/log/scrub/repository/ ;;; ;;; ;;; 7 ;;; ;;;",
  "/var/log/DL_UPLOADER/te_image_performance/all_vms ;;; ;;; ;;; 7 ;;; ;;;",

  #DLP tmp filer. R80.10. 2019
  #Her dumpes filer selv om DLP ikke er slått på. Ser ut som dette brukes av AV
  "/var/log/opt/ ;;; ;;; ;;; 1 ;;; \/tmp\/dlp\/ ;;; ",

  #DLP tmp filer. 2022.02.10
  #/var/log/opt/CPsuite-R80/fw1/CTX/CTX00008/tmp/dlp/{CA7B1C5E-4256-2C25-C8B2-F2A945A4FEC7}
  "/var/log/opt/ ;;; ;;; ;;; 1 ;;; \/tmp\/dlp\/ ;;; ",

  #New tmp for DLP
  #/var/log/opt/CPsuite-R80.40/fw1/CTX/CTX00003/tmp/te/dlpu_tmp_files_4-5/{F95AB70C-34D6-8349-A93A-E7D71F3E682D}
  
  #Check Pont Anti-Spam MTA. Mail tmp 2018
  #/var/log/opt/CPsuite-R80/fw1/CTX/CTX00015/tmp/email_tmp/aspam_engine/cteng_1_2_51643105999r.dat
  "/var/log/opt/ ;;; ;;; ;;; 1 ;;; \/tmp\/email_tmp\/aspam_engine\/ ;;; ",

  #Check Point local FW logs
  #Slette lokale logger. Dette tar plass vekk fra Threat Emulation
  #/opt/CPsuite-R80.40/fw1/CTX/CTX00003/log/2022-02-09_111506_21*
  #\d{4}-\d{2}-\d{2}_\d{6}

  #Check Point daservice loggfiler
  #/opt/CPInstLog/DIlogs/da_installer_2020-11-24-12-36-30.log
  

);

#Get VS data
#my %vs = vs_detailed();
#unless (defined %vs) {
#  my $msg = "Missing data from vs_detailed(). Exit";
#  debug($msg, "fatal", \[caller(0)] );
#  die $msg;
#}


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


#for each search array
foreach my $search (@search){

  my ($s_dir,$s_search,$s_size,$s_ctime,$s_match,$s_no_match) = split /\s{0,};;;\s{0,}/, $search;

  #if no dir is given, set /
  $s_dir ||= "/";

  my $cmd_find = "find $s_dir";
  $cmd_find .= " -iname \"$s_search\""  if $s_search;
  $cmd_find .= " -size +$s_size"        if $s_size;
  $cmd_find .= " -mtime +$s_ctime"      if $s_ctime;
  #$cmd_find .= " 2>/dev/null";

  debug("find cmd: $cmd_find", "debug", \[caller(0)] ) if $debug;

  #Run find  START
  my @find_out; 
  {
    #Disable debug for run_cmd()
    local $debug = 0;

    debug("run_cmd() start", "debug", \[caller(0)] ) if $debug > 1;
    @find_out = run_cmd({
      "cmd"                   => $cmd_find,
      'return-type'           => 'a',
      'refresh-time'          => 60,
      'timeout'               => 600,
      'timeout-eval'          => 600,
      'include-stderr'        => 0,
      'background-if-timeout' => 0,
    });
    debug("run_cmd() end", "debug", \[caller(0)] ) if $debug > 1;
  
  }
  #Run find END
  
  #Validate find output
  #unless (@find_out) {
  #  debug("\@find_out is empty. Find will always return some data. Something is wrong here", "fatal", \[caller(0)] );
  #  exit;
  #}

  FILE:
  #foreach my $file (`$cmd_find`){
  foreach my $file (@find_out){
    next unless defined $file;
    chomp $file;

    debug("Find output: $file", "debug", \[caller(0)] ) if $debug > 2;

    #Validate that this is a file or directory 
    # -f	File is a plain file.
    # -d	File is a directory.
    unless (-e $file) {
      debug("File failed validation. Does not exist. next FILE. $file", "info", \[caller(0)] ) if $debug > 1;
      next FILE 
    }

    #unless (-f $file or -d $file) {
    unless (-f $file) {
      debug("File failed validation. Not a file. next FILE. $file", "info", \[caller(0)] ) if $debug > 1;
      next FILE 
    }

    #Check global ignore list
    foreach my $ignore (@ignore) {
      debug("foreach @ignore: '$ignore'", "debug", \[caller(0)] ) if $debug > 2;

      if ($file =~ m#$ignore#){
        debug("Ignoring $file. $file =~ /$ignore/", "debug", \[caller(0)] ) if $debug > 1;
        next FILE;
      }
    }

    #Check match regex in find output
    if ($s_match) {
      debug("\$s_match is true for $file", "debug", \[caller(0)] ) if $debug > 1;

      unless ($file =~ /$s_match/) {
        debug("Ignoring file. Does not match on $s_match: $file", "debug", \[caller(0)] ) if $debug > 1;
        next FILE;
      }
    }

    if ($s_no_match) {
      debug("\$s_no_match is true", "debug", \[caller(0)] ) if $debug > 1;

      if ($file =~ /$s_no_match/) {
        debug("Ignoring file. Match found in no match regex $s_no_match: $file", "debug", \[caller(0)] ) if $debug > 1;
        next FILE;
      }
    }

    if ($debug or $dry_run) {
      debug("\$debug ($debug) or \$dry_run ($dry_run) is true", "debug", \[caller(0)] ) if $debug > 1;

      if ($dry_run) {
        debug("\$dry_run is true. Will not delete $file", "debug", \[caller(0)] ) if $debug > 1;
        next FILE 
      }

      print "$file\nFile found and ready for deleting. Press Y to continue: ";
      debug("$file\nFile found and ready for deleting. Press Y to continue: ", "debug", \[caller(0)] ) if $debug;

      my $answer = <>;
      chomp $answer;

      if ($answer eq "Y") {
        debug("\$answer is Y. next FILE", "debug", \[caller(0)] ) if $debug > 1;
      }
      else {
        debug("\$answer is not Y. next FILE", "debug", \[caller(0)] ) if $debug > 1;
        next FILE;
      }

    }

    $files_deleted_counter++;
    my $unlink_status = unlink $file;
    debug("File deleted $file", "debug", \[caller(0)] ) if $debug;

    if ($unlink_status) {
      debug("\$unlink_status is true. File deleted", "debug", \[caller(0)] ) if $debug > 1;
    }
    else {
      debug("\$unlink_status is true. File deleted", "error", \[caller(0)] ) if $error;
    }
  }
}


#Save the deleted files counter to the message file
set_last_message('file' => $file_message, 'message' => $files_deleted_counter);

debug("Deleted file counter: $files_deleted_counter", "debug", \[caller(0)] ) if $debug;




