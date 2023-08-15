#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;

$0 = "perl disk check VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

#TODO
#
#Alle alarmer/data sendes som en JSON
#items/dscovery lager items
#flere discovery på samme JSON.
# disk, ledig plass
# dd tester
# iotop -a
# top 10 filer på disk
# top 10 prosesser som skriver til disk
#   Ikke bruk PID men prosessnavn
#
#hdparm
#hdparm -C  /dev/sda
#hdparm -i  /dev/sda
#hdparm -I  /dev/sda
#hdparm -t /dev/sda
#hdparm -T /dev/sda
#
#smartctl
#smartctl --all /dev/sda
#smartctl -a /dev/sda
#smartctl -P showall /dev/sda
#smartctl -H /dev/sda
#smartctl -c /dev/sda
#
#Teste skrive/lese-hastighet
#Sjekk CPU-bruk.
#Sjekke ledig diskplass.
#Hvis boksen idler (typisk om natten)
#Hvis under 80% I bruk.
#Dd, lag en fil med ledig diskplass opp til 80%
#Send tilbake skrivehastighet
#Les fil med dd
#Send tilbake lesehastighet
#Slett fil
#
#Sjekk antall filer disk
#Kjør find /
#Tell antall filer pr mappe
#Tell antall filer pr partisjon
#Tell antall filer totalt
#Send antall tilbake
#Hvis mappe har for mange filer.
#Kjør kommandoen ls i mappen.
#Hvis ls bruker mer enn 10 sekunder.
#Send alarm tilbake til zabbix med nivå disaster
#

my $dir_tmp        = "/tmp/zabbix/NAME/disk_check/";
our $file_debug    = "$dir_tmp/debug.log";
our $debug         = 1;

create_dir($dir_tmp);

#Delete log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);


#End of standard header


#fork a child and exit the parent
#Don't fork if $debug is true
unless ($debug){
  fork && exit;
}

#Closing so the parent can exit and the child can live on
#The parent will live and wait for the child if there is no close
#Don't close if $debug is true
unless ($debug) {
  close STDOUT;
  close STDIN;
  close STDERR;
}

#Eveything after here is the child

