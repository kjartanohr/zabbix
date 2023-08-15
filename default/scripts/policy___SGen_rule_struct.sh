#!/bin/bash
#bin

if [ $1 ] && [ $1 = '--zabbix-test-run' ]
then
  echo ZABBIX TEST OK;
  exit;
fi

perl -e 'my $print = 0; foreach my $line (`sqlite3 \$FWDIR/state/__tmp/FW1/local.upDB.sqlite .dump`){ if ($line =~ /^CREATE TABLE/){$print = 0;}  if ($line =~ /^CREATE TABLE.*$ARGV[0]/){$print = 1;} print $line if $print}' "__SGen_rule_struct"
