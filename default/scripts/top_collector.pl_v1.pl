#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;

$0 = "perl top collector VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

my  $vsid           = shift @ARGV || 0;
my  $dir_tmp        = "/tmp/zabbix/top_collector";
our $file_debug     = "$dir_tmp/debug.log";
our $debug          = 0;
my  $file_top       = "$dir_tmp/top.log";
my  $cmd_top        = "top -d 5 -H -b";

create_dir($dir_tmp);

#Exit if this program is already running 
if (`ps xau|grep "$0"| grep -v $$ | grep -v grep`) {
  debug("Found an already running version of my self. Will exit\n");
  exit;
}
else {
  print "Startet top collector\n";
}


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


open my $fh_r_top,"-|", $cmd_top or die "Can't run $cmd_top: $!\n";

open my $fh_w_top,">>", $file_top or die "Can't write to file $file_top: $!\n";

my $time_check_file_size = time;

while (<$fh_r_top>) {
  chomp; 
  my $line = $_;
  s/^\s{1,}//;

  if (/^top - /) {
    print $fh_w_top "TIME: ".time()."\n"; 
  }

  #22664 admin     20   0    2420    716    616 S  0.0  0.0   0:00.00 mpstat 1 1
  my ($pid, $user, $pr, $ni, $virt, $res, $shr, $s, $cpu, $mem, $time, $command) = split/\s{1,}/;

  #No need to use disk space to save processes with no CPU usage
  next if defined $cpu && $cpu eq "0.0";
  next if defined $cpu && $cpu eq "0";

  print $fh_w_top "$line\n";


  #Check file size of the log file
  if ( (time - $time_check_file_size) > (10*60) ) {

    $time_check_file_size = time;
    debug("It's time to check the log file size\n");

    my $file_top_size    = get_file_size($file_top);
    my $file_top_size_mb = int ($file_top_size / 1024/1024);

    debug("$file_top is $file_top_size_mb MB\n");

    if ( $file_top_size_mb > 100 ) {
      debug("The log file is too big. Will delete it\n");
      close $fh_w_top;
      #use cmd split and keep 50 MB of the old log file

      system "tail -n100000 $file_top > $file_top.new 2>/dev/null"; 
      unlink $file_top;
      rename "$file_top.new",$file_top;
    
      open $fh_w_top,">>", $file_top or die "Can't run $cmd_top: $!\n";
    }
  }

}

sub get_name_of_process {
  my $pid  = shift || die "Need a PID to get name\n";
  my $file = "/proc/$pid/status";

  open my $fh_r_pid, "<", $file;
  if ($!) {
    debug("Could not open status $file: $!\n");
    return;
  }

  while (<$fh_r_pid>) {
    next unless /^Name: /;
    my ($name) = /Name:\s{1,}(.*)/;

    return $name;
  }
}
