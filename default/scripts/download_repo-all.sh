#!/bin/bash
#bin

if [ $1 ] && [ $1 = '--zabbix-test-run' ]
then
  echo ZABBIX TEST OK;
  exit;
fi


export DIR_SCRIPTS="/usr/share/zabbix/repo/scripts/auto/";

$DIR_SCRIPTS/download_repo-scripts.sh
$DIR_SCRIPTS/download_repo-lib.sh
$DIR_SCRIPTS/download_repo-files.sh
$DIR_SCRIPTS/download_repo-rpms.sh
