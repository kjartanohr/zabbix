#!/bin/bash
#bin

if [ $1 ] && [ $1 = '--zabbix-test-run' ]
then
  echo ZABBIX TEST OK;
  exit;
fi

 perl -e '$dns = `cat /usr/share/zabbix/repo/files/auto/domain_list.txt`; while (1){ foreach (split /\n/, $dns){chomp; $cmd = "dig +tcp $_ \@127.0.0.1"; $out = `$cmd`; ($time) = $out =~ /Query time: (.*?) msec/; print "Time: $time \@127.0.0.1 $_ \n" if $time > 0 }}'
