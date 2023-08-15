#!/bin/perl
BEGIN{push @INC,"/usr/share/zabbix/bin/perl-5.10.1/lib"}

use warnings;
use strict;
use POSIX ":sys_wait_h"; 

$0 = "perl interface diff";
$|++;
$SIG{CHLD} = "IGNORE";
$ARGV[0] = "" unless $ARGV[0];

if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

my $dir_tmp         = "/tmp/zabbix/interface_diff/";
my $file_diff_new   = $dir_tmp."interface_diff_new";
my $file_diff_prev  = $dir_tmp."interface_diff_prev";
my $debug           = 0; 
my $out;

unless (-d $dir_tmp){system "mkdir -p $dir_tmp";}


foreach (`cat /proc/net/dev`){
  s/^\s{1,}//; 
  s/:.*//; 
  next if /^Inter/;
  next if /^face/;
  next if /^bond/;
  next if /^lo/;
  next if /^vpnt/;
  my @s = split/\s{1,}/; 
  $out .= "$_";
}


rename $file_diff_new,$file_diff_prev;

open my $log_fh, ">", $file_diff_new or die "Can't write to $file_diff_new";
print $log_fh $out;
close $log_fh;

foreach (`diff $file_diff_new $file_diff_prev 2>/dev/null`){
  next if /^\d/;
  print;
}
