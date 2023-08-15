#!/usr/bin/perl5.32.0
#bin
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

#TODO
#Legge til sletting av mapper/directory
# utvid med to ekstra felt. En for filer 0/1, en for mapper 0/1
#
# Lagre antall filer slettet til tmp logg
# Åpne tmp logg, print innhold, fork

use warnings;
use strict;

$0 = "perl cleanup files";
$|++;

zabbix_check($ARGV[0]);

my $debug                 = 0;          #This needs to be 0 when running in production
my $dry_run               = 0;
my $files_deleted_counter = 0;

my @ignore = (
  "/home/",                             #Debug files
  '20\d\d-\d\d-\d\d',                   #Local log files
  'fw\.log',                            #Local log file
  '/var/log/jail/',                     #Jails
);

# search_dir ;;; search string ;;; Minimum file size ;;; days old ;;; Must match regex ;;; Skip if match regex
# "dir ;;; string ;;; min ;;; days ;;; match ;;; no match",
my @search = (
  #Check Point daservice loggfiler
  #/opt/CPInstLog/DIlogs/da_installer_2020-11-24-12-36-30.log

  #Check Point loggfiler
  "/ ;;; *.elg ;;; 100M ;;; ;;; ;;; ",

  #Linux og noen check point loggfile
  "/ ;;; *.log ;;; 100M ;;; ;;; ;;; ",

  #Check Point tmp filer. genererer opp til flere millioner filer
  "/ ;;; CKP_mutex::* ;;; ;;; 7 ;;; tmp ;;; ",

  #Linux, Check Point og Zabbix tmp filer
  "/tmp ;;; debug.log ;;; 20M ;;; ;;; ;;; ",
  "/tmp ;;; * ;;; 100M ;;; ;;; ;;; ",

  #Threat Emulation
  #"/var/log/opt/CPsuite-R80.40/fw1/CTX/CTX00003/tmp/te/te_tmp_files ;;; string ;;; min ;;; days ;;; match ;;; no match",

  #R80.40
  "/var/log/opt/ ;;; ;;; ;;; 1 ;;; \/tmp\/te\/te_tmp_files\/ ;;; ",

  #R80.10
  "/var/log/scrub/repository/ ;;; ;;; ;;; 7 ;;; ;;;",
  "/var/log/DL_UPLOADER/te_image_performance/all_vms ;;; ;;; ;;; 7 ;;; ;;;",

  #DLP tmp filer
  #/var/log/opt/CPsuite-R80/fw1/CTX/CTX00008/tmp/dlp/{CA7B1C5E-4256-2C25-C8B2-F2A945A4FEC7}
  "/var/log/opt/ ;;; ;;; ;;; 1 ;;; \/tmp\/dlp\/ ;;; ",

  #/var/opt/CPsuite-R80.30/fw1/conf/SMC_Files/cpmi_files/file_storage/dlp/{EAC08274-0289-11DF-926F-00000000DBDB}

  #Mail tmp
  #/var/log/opt/CPsuite-R80/fw1/CTX/CTX00015/tmp/email_tmp/aspam_engine/cteng_1_2_51643105999r.dat
  "/var/log/opt/ ;;; ;;; ;;; 1 ;;; \/tmp\/email_tmp\/aspam_engine\/ ;;; ",

  #Check Point local FW logs
  #/opt/CPsuite-R80.40/fw1/CTX/CTX00003/log/2022-02-09_111506_21*
  #\d{4}-\d{2}-\d{2}_\d{6}

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


foreach my $search (@search){

  my ($s_dir,$s_search,$s_size,$s_ctime,$s_match,$s_no_match) = split /\s{0,};;;\s{0,}/, $search;

  #if no dir is given, set /
  $s_dir ||= "/";

  my $cmd_find = "find $s_dir";
  $cmd_find .= " -iname \"$s_search\"" if $s_search;
  $cmd_find .= " -size +$s_size"      if $s_size;
  $cmd_find .= " -mtime +$s_ctime"    if $s_ctime;
  $cmd_find .= " 2>/dev/null";

  print "find cmd: $cmd_find\n" if $debug;

  FILE: foreach my $file (`$cmd_find`){
    chomp $file;

    #Skip the line if this is not a file
    next FILE unless -f $file;

    foreach my $ignore (@ignore) {
      if ($file =~ m#$ignore#){
        print "Ignoring $file. $file =~ /$ignore/\n" if $debug;
        next FILE;
      }
    }

    #Check match regex in find output
    if ($s_match) {
      debug("\$s_match is true", "debug", \[caller(0)] ) if $debug;

      unless ($file =~ /$s_match/) {
        print "Ignoring file. Does not match on $s_match: $file\n" if $debug;
        next FILE;
      }
    }

    if ($s_no_match) {
      if ($file =~ /$s_no_match/) {
        print "Ignoring file. Match found in no match regex $s_no_match: $file\n" if $debug;
        next FILE;
      }
    }

    if ($debug or $dry_run) {
      print "$file\nFile found and ready for deleting. Press Y to continue: ";
      next FILE if $dry_run;
      my $answer = <>;
      chomp $answer;

      next FILE unless $answer eq "Y";
    }

    #print "$file\n "; #This is return data to zabbix for the trigger.
    $files_deleted_counter++;
    unlink $file;
  }
}
print $files_deleted_counter if $files_deleted_counter;


