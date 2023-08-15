#!/bin/bash
#bin

if [ $1 ] && [ $1 = '--zabbix-test-run' ]
then
  echo ZABBIX TEST OK;
  exit;
fi



time /usr/share/zabbix/repo/scripts/auto/dns_dig.pl 4 127.0.0.1 vg.no 20 10 2 1
