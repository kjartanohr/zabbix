#!/bin/bash
#bin

if [ $1 ] && [ $1 = '--zabbix-test-run' ]
then
  echo ZABBIX TEST OK;
  exit;
fi



perl -ne  'next unless /:ipaddr \(/; s/.*\(//; s/\)//; chomp; next if /0$/; next if defined $db{$_}; $db{$_} = 1; $cmd = qq#dig +tcp -x $_ |grep status:#; print "$cmd. "; system $cmd' `find / -name "objects.C" 2>/dev/null`
