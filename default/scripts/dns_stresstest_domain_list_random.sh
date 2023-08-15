#!/bin/bash
#bin

if [ $1 ] && [ $1 = '--zabbix-test-run' ]
then
  echo ZABBIX TEST OK;
  exit;
fi


perl -e 'BEGIN{push @INC,"/usr/share/zabbix/bin/perl-5.10.1/lib"} use List::Util(shuffle); foreach $domain (shuffle(<STDIN>)){chomp $domain; foreach (`dig +tcp $domain`){next unless /Query time:/; print "$domain $_"}} '  </usr/share/zabbix/repo/files/auto/domain_list_500.txt
