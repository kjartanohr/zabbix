#!/usr/bin/perl5.32.0
#bin
BEGIN{
 require "/usr/share/zabbix/repo/files/auto/lib.pm";
  #require "./lib.pm"
}

#TODO

#Changes


use warnings;
use strict;

my $process_name_org          = $0;
my $process_name              = "run-ps-hpc";
$0                            = "perl $process_name VER 100";

#Print the data immediately. Don't wait for full buffer
$|++;

$SIG{CHLD}                    = "IGNORE";
#$SIG{INT}                     = \&save_and_exit('msg') => 'Signal INIT';

#Zabbix health check
zabbix_check($ARGV[0]);

our $dir_tmp                  = "/tmp/zabbix/$process_name";
our $file_debug               = "$dir_tmp/debug.log";
my  $file_exit                = "$dir_tmp/stop";

our $debug                    = 4;                                                  #This needs to be 0 when running in production
our $info                     = 1;
our $warning                  = 1;
our $error                    = 1;
our $fatal                    = 1;
my  $fork                     = 1;

#Get default config
our %config                   = get_config();

#Init config
$config{'init'}   = {
};


#Hash for long time storage. Saved to file
my $db                        = get_json_file_to_hash('file' => $config{'file'}{'database'});

#Hash for short time storage. Not saved to file
my %tmp                       = ();

my $file_hpc                   = "/usr/share/zabbix/repo/files/auto/Check_Point_HCP_AUTOUPDATE_Bundle_T52_AutoUpdate.tar";

if (-d $dir_tmp) {
  debug("$dir_tmp exists. Will not continue. Delete the directory first", "error", \[caller(0)] ) if $error;
  exit;
}


#Create tmp/data directory
create_dir($dir_tmp) unless -d $dir_tmp;

#Trunk log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);

#Check for input options
#unless (@ARGV) {
#  help(
#    'msg'         => "Missing input data. No data in \@ARGV",
#    'die'         => 1,
#    'debug'       => 1,
#    'debug_type'  => "warning",
#  );
#}

#Parse input data
#my %argv = parse_command_line(@ARGV);

#Print help if no input is given
#help('msg' => "help started from command line", 'exit'  => 1) if defined $argv{'help'};

#Activate debug if debug found in command line options
#$debug = $argv{'debug'} if defined $argv{'debug'};

#init JSON
#my $json = init_json();


#debug("", "debug", \[caller(0)] ) if $debug;
#debug("", "info", \[caller(0)] )  if $debug;
#debug("", "error", \[caller(0)] ) if $error;
#debug("", "fatal", \[caller(0)] );


#End of standard header


unless (-e -f -r $file_hpc) {
  debug("Could not find and read the file $file_hpc", "fatal", \[caller(0)] );
  exit;
}

#print run_cmd({
#  'cmd'             => "tar xfv $file_hpc --directory=$dir_tmp",
#  'dir-run'         => $dir_tmp,
#  'return-type'     => 's',
#  'refresh-time'    => 1,
#  'timeout'         => 60,
#});

#print run_cmd({
#  'cmd'             => "tar xfv $dir_tmp/*.tar --directory=$dir_tmp",
#  'dir-run'         => $dir_tmp,
#  'return-type'     => 's',
#  'refresh-time'    => 1,
#  'timeout'         => 60,
#});

my $show_cmd        = "script -c 'autoupdatercli show 2>&1'";
my $show_out = run_cmd({
  'cmd'             => $show_cmd,
  'dir-run'         => $dir_tmp,
  'return-type'     => 's',
  'refresh-time'    => 60,
  'timeout'         => 60,
});
print $show_out;

if ($show_out =~ /Check_Point_HCP_AUTOUPDATE_Bundle_T52_FULL.tgz/) {
  debug("hpc already installed", "info", \[caller(0)] );
}


#autoupdatercli install /usr/share/zabbix/repo/files/auto/Check_Point_HCP_AUTOUPDATE_Bundle_T52_AutoUpdate.tar
#hcp -r all --include-charts yes
#Hent ut denne filen /var/log/hcp/last/hcp_report_cp-manager_19_04_22_11_37.tar.gz

unless ($show_out =~ /Check_Point_HCP_AUTOUPDATE_Bundle_T52_FULL.tgz/) {
  my $install_cmd     = "script -c 'autoupdatercli install $file_hpc 2>&1'";
  my $install_out = run_cmd({
    'cmd'             => $install_cmd,
    'dir-run'         => $dir_tmp,
    'return-type'     => 's',
    'refresh-time'    => 60,
    'timeout'         => 60,
  });

  if ($install_out =~ /Failed/) {
    debug("Command failed. $install_cmd: $install_out", "fatal", \[caller(0)] );
    #exit;
  }
}


my $hpc_cmd        = "script -c 'hcp -r all --include-charts yes'";
#my $hpc_cmd        = "script -c 'python /etc/hcp/source/hcp.py'";
my $hpc_out = run_cmd({
  'cmd'             => $hpc_cmd,
  'dir-run'         => $dir_tmp,
  'return-type'     => 's',
  'refresh-time'    => 60,
  'timeout'         => 60,
});
print $hpc_out;

my ($file_summary) = $hpc_out =~ /Copy (.*?gz) to your desktop/;

unless (defined $file_summary){
  debug("Could not find the summary file in the output: $hpc_out", "fatal", \[caller(0)] );
  exit;
}

unless (-e -f -r $file_summary) {
  debug("Could not find the file: $file_summary", "fatal", \[caller(0)] );
  exit;
}


debug("Found summary file in output. Will upload file to tmp folder: $file_summary", "info", \[caller(0)] );

my $upload_cmd = "/usr/share/zabbix/repo/scripts/auto/upload_nc.pl $file_summary";
#my $upload_out = run_cmd({
#  'cmd'             => $upload_cmd,
#  'dir-run'         => $dir_tmp,
#  'return-type'     => 's',
#  'refresh-time'    => 60,
#  'timeout'         => 60,
#});
system $upload_cmd;

#print $upload_out;




#autoupdatercli install /usr/share/zabbix/repo/files/auto/Check_Point_HCP_AUTOUPDATE_Bundle_T52_AutoUpdate.tar
#hcp -r all --include-charts yes
#Hent ut denne filen /var/log/hcp/last/hcp_report_cp-manager_19_04_22_11_37.tar.gz
