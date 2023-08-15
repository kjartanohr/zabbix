#!/bin/bash
#bin

if [ $1 ] && [ $1 = '--zabbix-test-run' ]
then
  echo ZABBIX TEST OK;
  exit;
fi

perl -e 'my $int = shift @ARGV; ($ip) = `dig cws.checkpoint.com` =~ /A\s{1,}(\d.*)/; open my $ch_r,"-|", "tcpdump -n -nn -i $int host $ip and dst port 80 -vvv -A -s 10000"; while (<$ch_r>){next unless /GET /; ($url) = /GET (.*?) HTTP/; print "$url\n";}' `ip route | grep default | perl -ne '@s = split/\s{1,}/; print $s[-1]'`
