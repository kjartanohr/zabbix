#!/bin/bash
#bin


if [ $1 ] && [ $1 = '--zabbix-test-run' ]
then
  echo ZABBIX TEST OK;
  exit;
fi



/usr/share/zabbix/repo/scripts/auto/download_repo.pl http://zabbix.kjartanohr.no/zabbix/repo/__VER__/rpms/auto/ /usr/share/zabbix/repo/rpms/auto/
