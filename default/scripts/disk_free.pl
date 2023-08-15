#!/bin/perl

$debug             = 0;

#Zabbix test that will have to print out zabbix test ok. If not, the script will not download
if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

debug("$0 Input data ".join " ",@ARGV);

$input_mount             = shift @ARGV || "/";                                   #Mount to check
$input_percentage_alert  = shift @ARGV || 90;                                    #Print mount that are more than N in use
$input_disk_free_gb      = shift @ARGV || 10;                                    #Minimum N GB free 

#Foreach loop for the df command
MAIN: foreach (`df --block-size=1G`){

  #Split output in to lines
  ($filesystem,$blocks,$used,$avail,$use_per,$mount) = split/\s{1,}/;

  #Next if line does not match $input_mount
  next unless $input_mount eq $mount;

  unless ($input_percentage_alert eq "-"){
    #Next if percentage in use is less than $input_perentage_alert
    next MAIN if $use_per < input_percentage_alert;
  }

  unless ($input_disk_free_gb eq "-"){
    #Next if available diskspace if more then $input_disk_free_gb
    next MAIN if $avail > $input_disk_free_gb;
  }

  #Print back to zabbix agent
  print "$mount $use_per $avail";
}


sub debug {
  print "DEBUG: $_[0]\n" if $debug;
}


$test = <<EOF;
Filesystem           1K-blocks      Used Available Use% Mounted on
/dev/mapper/vg_splat-lv_current
                      81259184  58286240  18778640  76% /
/dev/sda1               295561     78590    201711  29% /boot
tmpfs                 32931560         4  32931556   1% /dev/shm
/dev/mapper/vg_splat-lv_log
                     248856260 166825208  69185996  71% /var/log
EOF
