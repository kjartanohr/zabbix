#!/usr/bin/perl5.32.0
#bin
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;

$0 = "perl diff output VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

my $cmd            = shift @ARGV || die "Need a command to run";
my $sleep           = shift @ARGV || 1;
my $dir_tmp        = "/tmp/zabbix/diff_output";
our $file_debug    = "$dir_tmp/debug.log";
our $debug         = 1;
my %db;

create_dir($dir_tmp);

#Delete log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);

debug("Temp file: $file_debug") if $debug;

#End of standard header

debug("CMD: $cmd") if $debug;
while (1){
  foreach (`$cmd`){
    s/^\s{0,}//;
    #s/^.*?\s{1,}.*?\s{1,}.*?\s{1,}.*?\s{1,}//;

    if ($db{$_}){
      next;
    }
    else{
      print;
      $db{$_} = 1;
    }
  } sleep $sleep;
}
