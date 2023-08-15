#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;
use Data::Dumper;

$0 = "perl top collector VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

my $cpu_min         = 5; #Don't save data if the CPU usage is under N%

my  $vsid           = shift @ARGV || 0;
my  $dir_tmp        = "/tmp/zabbix/top_collector";
our $file_debug     = "$dir_tmp/debug.log";
our $debug          = 0;
my  $file_top       = "$dir_tmp/top.log";
my  $file_config    = "$dir_tmp/.toprc";
my  $cmd_top        = "bash -c 'export HOME=$dir_tmp ; unset COLUMNS ; top -d 5 -H -b'";
my  %pname;
my  %header;

create_dir($dir_tmp);

#Exit if this program is already running
if (`ps xau|grep "$0"| grep -v $$ | grep -v grep`) {
  debug("Found an already running version of my self. Will exit\n");
  exit;
}
else {
  print "Startet top collector\n";
}


#Create top config file
create_config();

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
  s/^\s{1,}//;

  my $print = 1;

  unless ($_) {
    debug("Emtpy line. Discarding\n");
    next;
  }

  if (/^top - /) {
    debug("Found the header of top. Adding timestamp: $_\n");
    print $fh_w_top "TIME: ".time()."\n";
    next;
  }
  if (/^PID/) {
    print $fh_w_top "$_\n";
  }

  if (/^%Cpu/) {
    debug("Found %Cpu\n");

    #%Cpu0  :  0.0 us,  0.0 sy,  0.0 ni, 94.7 id,  0.0 wa,  0.0 hi,  0.0 si,  5.3 st
    #my ($cpu, $us, $sy, $ni, $id, $wa, $hi, $si, $st) = split//;
    my ($id) = /.*,\s{1,}(.*?)\s{1,}id,/;
    if ($id < 100) {
      debug("Found %Cpu and idle is less than 100: $id Adding to log: $_\n");
      print $fh_w_top "$_\n";
    }
    next;
  }

  #Get the array index for CPU
  if (!%header and /^PID/) {
    debug("Found the row header: $_\n");
    #PID USER      PR  NI    VIRT    RES    SHR S %CPU %MEM     TIME+ COMMAND
    my $count_row = 0;
    foreach (split/\s{1,}/) {
      debug("Adding row to hash $count_row is $_\n");
      $header{$_} = $count_row;
      $count_row++;
    }
    debug("Rows: ".Dumper %header) if $debug;
    next;
  }

  if (/^\d/) {
    debug("Found digit at the beginning of the line. Guessing its a PID: $_") if $debug > 1
  }
  else {
    debug("Did not find a digit at the beginning of the line. Next") if $debug > 1;
    next;
  }

  #22664 admin     20   0    2420    716    616 S  0.0  0.0   0:00.00 mpstat 1 1
  #my ($pid, $user, $pr, $ni, $virt, $res, $shr, $s, $cpu, $mem, $time, $command) = split/\s{1,}/;
  my @split = split/\s{1,}/;

  my $row_cpu = $header{'%CPU'};

  unless ($row_cpu) {
    debug("Missing %header data. Discarding line $_\n");
    next;
  }

  my $cpu = $split[$row_cpu];

  if ($cpu) {
    #debug("Found CPU usage: $cpu: $_\n") if $debug;
  }
  else {
    debug("Could not find find CPU usage: $cpu: $_\n") if $debug;
    next;
  }

  if ($cpu !~ /^\d/) {
    debug("CPU usage is not a valid integer: $cpu: $_\n") if $debug;
    next;
  }

  $cpu = int $cpu;

  if ($cpu > 100) {
    debug("CPU usage ($cpu) is more than 100. Something wrong. Discarding line: $_\n") if $debug;
    next;
  }

  #No need to use disk space to save processes with no CPU usage
  if ($cpu < $cpu_min) {
    #debug("CPU usage ($cpu) is less than \$cpu_min ($cpu_min). Discarding line: $_\n") if $debug;
    next;
  }
  else {
    #debug("CPU usage ($cpu) is more than \$cpu_min ($cpu_min): $_\n") if $debug;
  }


  my $row_pid = $header{'PID'};
  my $pid = $split[$row_pid];

  unless (defined $pid and $pid =~ /^\d/) {
    debug("PID not a valid integer: $pid: $_\n") if $debug;
    next;
  }

  my $pname = get_name_of_process($pid);
  unless (defined $pname) {
    debug("Could not find process name if PID $pid\n") if $debug;
  }

  unless ($pname) {
    debug("Could not find process name if PID $pid\n") if $debug;
  }


  if ($pname) {
    debug("Adding line to log with extra command line data: $_ $pname\n") if $debug;
    print $fh_w_top "$_ $pname\n";
  }
  else {
    debug("Adding line to log: $_\n") if $debug;
    print $fh_w_top "$_\n";
  }


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

  unless (exists $pname{$pid}) {
    debug("Could not find PID in hash. Updating hash\n");
    %pname = ();
    update_process_names();
  }

  my $name;
  foreach (@{$pname{$pid}}) {
    $name .= "$_ ";
  }

  return $name;
}

sub update_process_names {

  foreach (`ps xawwHT --cols 200 -o pid,comm,args`) {
    chomp;
    s/^\s{0,}//;

    my @s = split/\s{1,}/;

    if ($s[2] =~ /^\[.*\]$/) {
      #print "adding $s[0] $s[1]\n";
      push @{$pname{$s[0]}}, $s[1];
      next;
    }
    @s = split/\s{1,}/,$_,3;

    push @{$pname{$s[0]}}, $s[1];
    push @{$pname{$s[0]}}, $s[2];

  }
}

sub create_config {
  if (-f $file_config){
    debug("top config file found. Will not create a new one");
    return;
  }
  else {
    debug("top config not file found. Will create a new one");
  }


  my $config = <<EOF;
RCfile for "top with windows"           # shameless braggin
Id:a, Mode_altscr=0, Mode_irixps=1, Delay_time=1.000, Curwin=0
Def     fieldscur=AEHIOQTWKNMbcdfgJplrsuvyzX
        winflags=30009, sortindx=10, maxtasks=0
        summclr=1, msgsclr=1, headclr=3, taskclr=1
Job     fieldscur=ABcefgjlrstuvyzMKNHIWOPQDX
        winflags=62777, sortindx=0, maxtasks=0
        summclr=6, msgsclr=6, headclr=7, taskclr=6
Mem     fieldscur=ANOPQRSTUVbcdefgjlmyzWHIKX
        winflags=62777, sortindx=13, maxtasks=0
        summclr=5, msgsclr=5, headclr=4, taskclr=5
Usr     fieldscur=ABDECGfhijlopqrstuvyzMKNWX
        winflags=62777, sortindx=4, maxtasks=0
        summclr=3, msgsclr=3, headclr=2, taskclr=3

EOF

  open my $fh_w, ">", $file_config or die "Can't write to $file_config: $!";
  print $fh_w $config;
  close $fh_w;
}

