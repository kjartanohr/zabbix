#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;

$0 = "perl vmware tools VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

my $dir_tmp        = "/tmp/zabbix/vmware_tools";
our $file_debug    = "$dir_tmp/debug.log";
our $debug         = 0;
my $file_vmtools   = "/bin/vmtoolsd";
my $file_rh_rel    = "/etc/redhat-release";
my $cmd_vmtools    = "/bin/vmtoolsd -b -p /etc/vmware-tools/plugins/vmsvc";
my $cmd_lspci      = "/sbin/lspci";
my $cmd_ps         = "ps xau|grep vmtool";
my $cmd_rh_rel     = qq#echo "Red Hat Enterprise Linux Server release 6"  >/etc/redhat-release#;
create_dir($dir_tmp);

#Delete log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);


#End of standard header

if (run_cmd($cmd_ps) =~ /$file_vmtools/){
  debug("vmware tools is running in the background. No need to continue");
  print 1;
  exit;
}
else {
  debug("vmware tools is not running in the background. Continue");
}

my $ok_file      = 0;
my $ok_vmware_hw = 0;

if (-f $file_vmtools) {
  $ok_file = 1;
  debug("Found vmware tools file: $file_vmtools");
}

if (`$cmd_lspci` =~ /vmware/i) {
  $ok_vmware_hw = 1;
  debug("Found vmware hw listet in lspci");
}

if ($ok_file and $ok_vmware_hw) {
  debug("vmware tools found and we are running in vmware. Will start vmware tools");

  unless (-f $file_rh_rel) {
    debug("Could not find a redhat release file. Creating $file_rh_rel");
    run_cmd($cmd_rh_rel);
  }

  run_cmd($cmd_vmtools);

  sleep 1;
  unlink $file_rh_rel;


  if (run_cmd($cmd_ps) =~ /$file_vmtools/){
    debug("vmware tools is running in the background");
  }
  else {
    debug("vmware tools is not running in the background. Something is wrong");
    print 9999;
  }
}


