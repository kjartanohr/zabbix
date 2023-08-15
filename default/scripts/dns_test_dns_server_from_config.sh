#!/bin/bash
#bin

if [ $1 ] && [ $1 = '--zabbix-test-run' ]
then
  echo ZABBIX TEST OK;
  exit;
fi

perl -e 'my @dns = qw(8.8.8.8 1.1.1.1); push @dns, get_resolve(); my $domain = "vg.no"; foreach $dns (@dns){$cmd = "dig +tcp \@$dns $domain"; my $out = `$cmd`; if ($out =~ /NOERROR/){print "$dns OK\n";}else{print "$dns FAILED\n$cmd\n$out"}} sub get_resolve {foreach (`cat /etc/resolv.conf`){chomp; ($server) = /nameserver (.*)/; push @ip, $server if $server;} return @ip}'
