#!/usr/bin/perl5.32.0
#bin
BEGIN{

  #init global pre checks
  #init_local_begin('version' => 1);

  #Global var
  our %config;

  require "/usr/share/zabbix/repo/files/auto/lib.pm";
  #require "./lib.pm";

  #Zabbix health check
  zabbix_check($ARGV[0]) if defined $ARGV[0] and $ARGV[0] eq "--zabbix-test-run";


  #init global pre checks
  init_global_begin('version' => 1);
}

#TODO

#Changes

#BUGS

#Feature request

use warnings;
no warnings qw(redefine);
use strict;


foreach (`mdsstat`){
  @split = split/\s{0,}\|\s{0,}/;
  next unless $split[1] eq CMA;

  print "\nMGMT $split[2]\n";
  $mgmt_count++;

foreach (`source /opt/CPmds-R80.30/scripts/MDSprofile.sh; mdsenv $split[2]; cpmiquerybin attr "" network_objects "type='gateway_cluster'" -a __name__,ipaddr`) {
  chomp;
  s/\s{1,}.*//;
  print "  GW $_\n";
  $gw_count++;
}

}

print "MGMT total: $mgmt_count\n";
print "GW total: $gw_count\n";
