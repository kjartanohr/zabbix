#!/bin/perl

if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

$vsid  = shift @ARGV || 0;

# 8888 = blade not enabled
# 1    = debug is off
# 2    = debug is disabled
# 9999 = something is wrong

#Check if IA is enabled. Exit if not
unless (-f "/tmp/enabled_blades_vs$vsid"."_ia"){
  print 8888;
  exit;
}

#Check if pdp debug is off. Exit if off
if (`source /etc/profile.d/vsenv.sh; vsenv $vsid &>/dev/null ; pdp debug stat` =~ /Current debug status is: off/){
  print 1;
  exit;
}

#Disable pdp debug. If not debug is not off, print 9999
if (`source /etc/profile.d/vsenv.sh; vsenv $vsid &>/dev/null ; pdp debug off` =~ /debug is now off/){
  print 2;
}
else {
  print 9999;
}
