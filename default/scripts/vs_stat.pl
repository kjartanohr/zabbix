#!/bin/perl
#bin

if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}


$out = `vsx stat -v -l`;

foreach (split/\n/,$out){
  if (m/VSID/){($id) = /VSID: *(\d\d?)/;
  print $id;

  $active = `source /etc/profile.d/vsenv.sh; vsenv $id&>/dev/null;cphaprob stat 2>/dev/null |grep local`;

  if ($active =~ m/Active/i){
    print "\tActive\t"}

  else {
    print "\tPassive\t"
  }
}

  if (m/Name/){
    ($name) = /Name: *(.*)/;
    print "$name\n"
  }
}
