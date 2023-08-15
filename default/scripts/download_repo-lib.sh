#!/bin/bash
#bin

if [ $1 ] && [ $1 = '--zabbix-test-run' ]
then
  echo ZABBIX TEST OK;
  exit;
fi


URL="http://zabbix.kjartanohr.no/zabbix/repo/default/lib";
DOWNLOAD_REPO="/usr/share/zabbix/repo/scripts/auto/download_repo.pl";

$DOWNLOAD_REPO $URL/ /usr/share/zabbix/repo/lib/
$DOWNLOAD_REPO $URL/lib/stable/ /usr/share/zabbix/repo/lib/stable/
$DOWNLOAD_REPO $URL/lib/prod/ /usr/share/zabbix/repo/lib/prod/
$DOWNLOAD_REPO $URL/lib/dev/ /usr/share/zabbix/repo/lib/dev/
$DOWNLOAD_REPO $URL/lib/test/ /usr/share/zabbix/repo/lib/test/

$DOWNLOAD_REPO $URL/KFO/ /usr/share/zabbix/repo/lib/KFO/

$DOWNLOAD_REPO $URL/KFO/stable/ /usr/share/zabbix/repo/lib/KFO/stable/
$DOWNLOAD_REPO $URL/KFO/prod/ /usr/share/zabbix/repo/lib/KFO/prod/
$DOWNLOAD_REPO $URL/KFO/dev/ /usr/share/zabbix/repo/lib/KFO/dev/
$DOWNLOAD_REPO $URL/KFO/test/ /usr/share/zabbix/repo/lib/KFO/test/
