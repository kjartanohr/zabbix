#!/bin/bash
#bin

if [ $1 ] && [ $1 = '--zabbix-test-run' ]
then
  echo ZABBIX TEST OK;
  exit;
fi


perl -ne 'next unless /:ipaddr \(/; s/.*\(//; s/\)//; chomp; $list{$_} = 1; END{foreach (keys %list) {$cmd = qq#dig +tcp -x  $_ #; print "$cmd\n"; system "$cmd >/dev/null"}}' `find / -name "objects.C" 2>/dev/null`
