#!/bin/bash
#bin

if [ $1 ] && [ $1 = '--zabbix-test-run' ]
then
  echo ZABBIX TEST OK;
  exit;
fi

dig +tcp -f /usr/share/zabbix/repo/files/auto/domain_list_500.txt
