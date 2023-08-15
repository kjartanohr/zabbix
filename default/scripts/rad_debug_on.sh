#!/bin/bash
#bin

if [ $1 ] && [ $1 = '--zabbix-test-run' ]
then
  echo ZABBIX TEST OK;
  exit;
fi

perl -e 'while (1){foreach (`ps wxa`){next if /perl|\/httpd|zabbix/; s/^\s{0,}//; s/\s{1,}$//; s/\s{2,}/ /g; s/^.*?\s{1,}.*?\s{1,}.*?\s{1,}.*?\s{1,}//; s/^\s{1,}//; if(defined $db{$_}){next}else{chomp; print "$_\n\n"; $db{$_} = 1;} }  }'rad_admin rad debug on

rad_admin stats on urlf
rad_admin stats on appi
rad_admin stats on malware
rad_admin stats on av

rad_admin restart