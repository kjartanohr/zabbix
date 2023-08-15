#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;
use Expect;


$0 = "perl NAME OF SCRIPT VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

my $dir_tmp        = "/tmp/zabbix/expect/";
our $file_debug    = "$dir_tmp/debug.log";
our $debug         = 1;

create_dir($dir_tmp);


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

my $up   = "\c[[A";
my $down = "\c[[B";
my $left = "\c[[D";
my $right = "\c[[C";

my $exp = new Expect;
#$exp->raw_pty(1);
$exp->debug(3);
$exp->log_file("cpview.log");
$exp->stty(qw("cols 200"));

$exp->spawn("cpview") or die "Cannot spawn cpview: $!\n";

sleep 1;

$exp->send($right);

sleep 1;

#Send CTRL+C
$exp->send("\cC");

$exp->soft_close();
