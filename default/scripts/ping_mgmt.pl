#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;

$0 = "perl ping management";
$|++;

zabbix_check($ARGV[0]);

unless (defined $ARGV[0]) {
  die "Missing VSID from input to command\n";
}

my $vsid           = $ARGV[0];
my $dir_tmp        = "/tmp/zabbix/ping_mgmt";
our $file_debug    = "$dir_tmp/$vsid-debug.log";
our $file_ping_ok  = "$dir_tmp/$vsid-ping_ok";
our $file_stop     = "$dir_tmp/$vsid-stop";
our $debug         = 0;

exit;
create_dir($dir_tmp);

#Delete log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);


#End of header

if (-f $file_stop) {
  debug("$file_stop file found. Will exit\n");
  exit;
}


debug("Checking if this is a GW. If not, exit");
my $is_gw = is_gw();
exit unless $is_gw;

die "is gw check failed. Something is wrong here\n" if $is_gw == 2;

debug("Script startet for VS $vsid");

my $mgmt_ip = get_mgmt_ip();
die "Could not get MGMT IP" unless $mgmt_ip;

my $ping_ip = ping_ip($mgmt_ip,$vsid,3);

if ($ping_ip) {
  debug("Ping MGMT $mgmt_ip is OK\n");
  debug("Creating $file_ping_ok\n");
  
  touch($file_ping_ok);
}
else {
  debug("Ping MGMT $mgmt_ip FAILED\n");
  
  if (-f $file_ping_ok) {
    debug("File $file_ping_ok found. Ping should work, will send back an error\n");

    die "could not ping MGMT IP $mgmt_ip\n" unless $ping_ip;

    if ( (file_seconds_old($file_ping_ok)/60/60) > 24) {
      debug("$file_ping_ok is older than 24 hours, will delete it");
      unlink $file_ping_ok;
    
  }
  else {
    debug("File $file_ping_ok NOT found. Ping has never worked, will NOT send back an error\n");
    }
  }
}

