#!/usr/bin/perl5.32.0
#bin
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;

$0 = "perl disk write speed VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);


my @files = (
  "/",         "/tmp/dd_speed_test", 
  "/var/log/", "/var/log/dd_speed_test"
);

while (@files) {
  my $partition = shift @files;
  my $file      = shift @files;

  my $df = `df -k $partition`;
  my ($free) = $df =~ /\d{1,}\s{1,}\d{1,}\s{1,}(\d{1,})\s/;
  
  if (($free/1024/1024) < 2){
    print "Not enough free disk space\n";
    exit;
  }
  
  my $cmd = "dd if=/dev/zero of=$file oflag=direct bs=1024M count=1 2>&1";
  print "$cmd\n\n";
  my $out = `$cmd`;
  
  
  unlink $file;
  
  my ($speed) = $out =~ /s, (\d{1,}.*)/;
  print "$speed\n";
 
}
