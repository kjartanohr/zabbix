#!/bin/perl

#kommentar

if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

#Exit if this is a mamagement
exit if `cpprod_util CPPROD_IsMgmtMachine 2>&1` =~ /1/;

$vsid = shift @ARGV || 0;

$out = `source /etc/profile.d/vsenv.sh; vsenv $vsid&>/dev/null ; fw ctl multik stat 2>&1`;

#Print 1 if CoreXL is disabled
if ($out =~ /fw: CoreXL is disabled/){
  print 1;
  exit;
}

foreach (split "\n", $out) {
  s/^\s{0,}//;
  $count++ if /^\d/;
}

if ($count) {
  print $count;
}
else {
  print 1;
}

