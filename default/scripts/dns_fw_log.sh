#!/bin/bash
#bin

if [ $1 ] && [ $1 = '--zabbix-test-run' ]
then
  echo ZABBIX TEST OK;
  exit;
fi

perl -e 'foreach (`find / -name "202*.log" 2>/dev/null`){chomp; next if /zabbix/; $cmd = "fw log $_ &>/dev/null"; print "$cmd\n"; system $cmd; }'
