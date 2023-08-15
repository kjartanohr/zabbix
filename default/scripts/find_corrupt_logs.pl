#!/usr/bin/perl5.32.0
#bin
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;

$0 = "perl find corrupt FW logs VER 102";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

my  $dir_tmp            = "/tmp/zabbix/logs_corrupt/";
our $file_debug        = "$dir_tmp/debug.log";
our $debug             = 0;
my  $dry_run           = 0;
my  $skip_cp_log_files = 0;

my  $corruption_found  = 0;
my  $file_mdsprofile   = ""; 
my  $is_mds            = is_mds();

#Exit the script if this is not a MGMT
exit if `fwm ver 2>&1` =~ /This is not a Security Management Server station/;

create_dir($dir_tmp);


#Exit if this program is already running 
if (`ps xau|grep "$0"| grep -v $$ | grep -v grep`) {
  debug("Found an already running version of my self. Will exit\n");
  print "Found an already running version of my self. Will exit\n";
  exit;
}

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

my @path;

#Add MGMT fw log path
my $out_mgmt_log = `/etc/profile.d/vsenv.sh; echo \$FWDIR/log/`;
chomp $out_mgmt_log;
push @path, $out_mgmt_log;


if ($is_mds) {
  debug("This is a MDS MGMT\n");

  my  $file_mdsprofile = whereis("MDSprofile.sh");

  my $out_mds_log = `/etc/profile.d/vsenv.sh; echo \$MDS_FWDIR/log/`;
  chomp $out_mds_log;
  push @path, $out_mds_log;

  foreach my $cma (get_mds()) {
    debug("Found MGMT $cma\n");

    my $cmd_path = "source $file_mdsprofile ; mdsenv $cma; echo \$FWDIR/log/";
    my $out_path = `$cmd_path`;
    chomp $out_path;

    debug("Found log path $out_path\n");

    push @path, $out_path;
  }
}

debug("Found log path: ".join "\n", @path."\n");

my @files_log;

#Get all log files
foreach my $path (@path) {
  chomp $path;

  my $cmd_find = qq#find "$path" -name "*.log"#;
  debug("CMD: $cmd_find\n");

  open my $ch, "-|", $cmd_find or die "Can't run $cmd_find: $!";

  while ( my $find = <$ch>) {
    chomp $find;


    #Skip the file if it's a check point log file and $skip_cp_log_files is true
    if ($skip_cp_log_files) {
      next if $find =~ /2\d\d\d.*\.log$/;
    }
  
    #Skip the line if the filename is not ending with a .log
    next unless $find =~ /\.log$/;

    debug("Adding log file to \@files_log: $find\n");
    push @files_log, $find;
  }
}

debug("Found log files: ".join "\n", @files_log) if $debug > 1;


my $count_file = 0;
my $files_log_count = scalar @files_log;

#Loop every line from find. Find will return *.log from FWDIR
foreach my $file (sort @files_log) {

  $count_file++;

  #Remove new line
  chomp $file;

  my ($path, $filename) = $file =~ /(.*)\/(.*)/;
  debug("Found path $path, filename: $filename\n") if $debug > 1;

  
  #Skip the file if it's a check point log file and $skip_cp_log_files is true
  if ($skip_cp_log_files) {
    next if $filename =~ /2\d\d\d.*\.log$/;
  }

  my $filename_tmp = $filename;

  if ($is_mds) {
    my $filename_tmp = $file;
    $filename_tmp    =~ s/\W/_/g;
    $filename_tmp    =~ s/_{2,}/_/g;
  }

  #Skip the file if it's found in the $dir_tmp. Skip the file is it's already checked 
  if (-f "$dir_tmp/$filename_tmp") {
    debug("This file is already checked. Skipping\n") if $debug > 1;
    next;
  }

  #Don't check the fw.log file. It's the live log file 
  if ($filename eq "fw.log") {
    debug("This is a live log file, will not check. Filename: $filename\n") if $debug > 1;
    next;
  }


  #Skip the line if the filename is not ending with a .log
  next unless $filename =~ /\.log$/;

  debug("Whill check the log file $file with fw log\n") if $debug > 1;

  #Read the log file with "fw log" and output the first line of the log.
  #If the command outputs Error, rename the log file

  my $cmd_fw_log =  qq#fw log -y 1 "$file" 2>&1#;
  debug("Will run cmd: $cmd_fw_log\n") if $debug > 1;

  my $out_fw_log = `$cmd_fw_log`;

  debug("OUT: $out_fw_log\n") if $debug > 1;
  

  if ($out_fw_log =~ /Error: Failed to open log file/i) { 

    my $file_new = "$file.corrupt";

    debug("Renaming $file to $file_new\n");

    rename $file,$file_new if $dry_run == 0;

    #print back to zabbix
    print "$file is a corrupt log file\n";

    debug("$count_file/$files_log_count. $file is a corrupt log file\n");

    $corruption_found = 1;
    
  }
  else {
    debug("$count_file/$files_log_count. $file is OK\n");
 
    mark_as_ok($filename_tmp,$file);
  }
}

if ($dry_run == 0 and $corruption_found) {
  debug("Corrupted files found. Will restart smartevent with evstop ; evstart\n");
  system "evstop ; evstart";
}

sub mark_as_ok {
  my $file    = shift || die "Need a filename\n";
  my $content = shift || "";
  
  open my $fh_w,">", "$dir_tmp/$file" or die "Can't write to $dir_tmp/$file: $!\n";
  print $fh_w $content if $content;
  close $fh_w;
}

sub is_mds {
  
  my $cmd_mdsstat = "whereis mdsstat";

  my $cmd_out = `$cmd_mdsstat 2>&1`;

  $cmd_out =~ s/^.*?://;

  if ($cmd_out =~ /mdsstat/) {
    return 1;
  }
  else {
    return 0;
  } 

}


sub get_mds {
  my @return;

  foreach (`mdsstat`){
    my @split = split/\s{0,}\|\s{0,}/;
    next unless $split[1];
    next unless $split[1] eq "CMA";

    my $mds_name = $split[2];
    next unless $mds_name;

    push @return, $mds_name;
  }
  return @return;

}


sub whereis {
  my $file = shift || die "Need a file to search for";

  my $cmd = "whereis $file";

  my $cmd_out = `$cmd`;

  #Remove everything before :
  $cmd_out =~ s/^.*?://;

  #Remove starting spaces
  $cmd_out =~ s/^\d{1,}//;

  my @found = split/\s{1,}/, $cmd_out;

  foreach my $found (@found) {
    chomp $found;
    next unless $found;

    debug("Found $found\n");

    #get filename from path
    my ($found_filename) = $found =~ /.*\/(.*)/;
    debug("Filename: $found_filename\n");


    if ($found_filename eq $file) {
      debug("$found_filename matches with $file\n");
      return $found;
    }
    else {
      debug("$found_filename does not match with $file. Skipping\n");
    }
  }
}

sub delete_files_if_older_than {
  my $dir  = shift || die "Missing a directory path to delete files from";
  my $days = shift || die "Missing how many days to delete files from";

  unless (-d $dir) {
    debug("$dir does not exist. Returning\n");
    return;
  }

  opendir my $dh, $dir or die "Can't open $dir: $!";

  foreach my $file (readdir $dh) {
    my $days_old = file_days_old($file);

  }

}

sub clean_tmp_dir {
  my $dir  = shift || die "Missing a directory path to delete files from";
  my $days = shift || die "Missing how many days to delete files from";

  unless (-d $dir) {
    debug("$dir does not exist. Returning\n");
    return;
  }

  opendir my $dh, $dir or die "Can't open $dir: $!";

  foreach my $file (readdir $dh) {

    #open my $fh_r, "<", 

  }

}


