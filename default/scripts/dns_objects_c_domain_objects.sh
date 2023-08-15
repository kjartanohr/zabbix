#!/bin/bash
#bin

if [ $1 ] && [ $1 = '--zabbix-test-run' ]
then
  echo ZABBIX TEST OK;
  exit;
fi



perl -ne  'next unless /:name \(\./; s/.*\(//; s/\)//; s/^\.//; s/\.$//; chomp; $cmd = qq#dig +tcp $_#; print "$cmd\n"; my $out = `$cmd`; if ($out =~ /status: NOERROR/){next} print "$out\n\n"' `find / -name "objects.C" 2>/dev/null`
