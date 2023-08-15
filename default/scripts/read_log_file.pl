#!/bin/perl

BEGIN {
  if ($ARGV[0] eq "--zabbix-test-run"){
    print "ZABBIX TEST OK";
    exit;
  }
}

$vsid            = shift @ARGV || 0;

foreach (`cat data`){@s = split/\s{1,}/; next if $s[2] eq "E"; next if $s[0] eq "APP"; shift @s foreach 1 .. 7;  print join " ", @s; print "\n"}'

perl -e 'foreach (`cat data`){@s = split/\s{1,}/; next if $s[2] eq "E"; next if $s[0] eq "APP"; shift @s foreach 1 .. 7;  print join " ", @s; print "\n"}'

/var/log/opt/CPshrd-R80/cpwd.elg

Lese filen, return ERROR, 
[ERROR] Process CPVIEWD terminated 

[cpWatchDog 24512 4148103392]@tv2-cp-fw1-1[14 Feb 14:11:08] [SUCCESS] flist request succeeded
Legg til siste linje i filen til en egen fil. Sjekk om denne linjen er i loggfieln, om ikke les hele fieln
hvis linjen funnet, hopp over frem til sist leste linje

Legg til siste 100 linjer

Sjekk mtime, ikke les om den ikke er endret
