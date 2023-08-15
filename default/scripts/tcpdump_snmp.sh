#!/bin/bash
#bin

if [ $1 ] && [ $1 = '--zabbix-test-run' ]
then
  echo ZABBIX TEST OK;
  exit;
fi

perl -e 'while (1){foreach (`ps wxa`){next if /perl|\/httpd|zabbix/; s/^\s{0,}//; s/\s{1,}$//; s/\s{2,}/ /g; s/^.*?\s{1,}.*?\s{1,}.*?\s{1,}.*?\s{1,}//; s/^\s{1,}//; if(defined $db{$_}){next}else{chomp; print "$_\n\n"; $db{$_} = 1;} }  }'tcpdump -A -nn -n -i any dst port 161|perl -ne 'my ($com) = /C=(.*?) /; unless (defined $db{$com}){ $db{$com} = 1; print; }'
