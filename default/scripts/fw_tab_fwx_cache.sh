#!/bin/bash
#bin

if [ $1 ] && [ $1 = '--zabbix-test-run' ]
then
  echo ZABBIX TEST OK;
  exit;
fi

perl -e 'foreach my $line (`fw tab -t $ARGV[0] -m $ARGV[1]`){my ($ip_source_hex, $ip_dest_hex, $unknown) = $line =~ /\<(.*?), (.*?); (.*?)>/; my $ip_source = join ".", map { hex($_) } unpack("A2 A2 A2 A2", $ip_source_hex);  my $ip_dest = join ".", map { hex($_) } unpack("A2 A2 A2 A2", $ip_dest_hex); print "$ip_source, $ip_dest\n" if $ip_source_hex; print $line unless $ip_source_hex}' 'fwx_cache' '10'
