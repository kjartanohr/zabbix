#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;

$0 = "perl tainted kernel VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

my  $dir_tmp        = "/tmp/zabbix/tainted_kernel";
our $file_debug     = "$dir_tmp/debug.log";
our $debug          = 0;
my  $file_last_line = "$dir_tmp/last_line";
my  $last_line      = "";
my  $start          = 0;

my %state_info = (
  'P' => 'proprietary module was loaded',
  'G' => 'proprietary module was loaded',
  'F' => 'module was force loaded',
  'S' => 'kernel running on an out of specification system',
  'R' => 'module was force unloaded',
  'M' => 'processor reported a Machine Check Exception (MCE)',
  'B' => 'bad page referenced or some unexpected page flags',
  'U' => 'taint requested by userspace application',
  'D' => 'kernel died recently, i.e. there was an OOPS or BUG',
  'A' => 'ACPI table overridden by user',
  'W' => 'kernel issued warning',
  'C' => 'staging driver was loaded',
  'I' => 'workaround for bug in platform firmware applied',
  'O' => 'externally-built (“out-of-tree”) module was loaded',
  'E' => 'unsigned module was loaded',
  'L' => 'soft lockup occurred',
  'K' => 'kernel has been live patched',
  'X' => 'auxiliary taint, defined for and used by distros',
  'T' => 'kernel was built with the struct randomization plugin',
);

create_dir($dir_tmp);


#End of standard header

open my $ch_r, "-|", "dmesg", or die "Can't run dmesg: $!";
my $dmesg = join "", <$ch_r>;

if (-f $file_last_line) {
  debug("Found $file_last_line\n");
  open my $fh_r, "<", $file_last_line or die "Can't read $file_last_line: $!";
  $last_line = <$fh_r>;
  close $fh_r;

  if (defined $last_line) {
    debug("Found last line from file: $last_line\n");
  }
  else {
    debug("Could not find any last line from file\n");
    $last_line = "";
  }


  if ($last_line and $dmesg =~ /\Q$last_line\E/) {
    debug("Found line in dmesg: $last_line\n");
  }
  else {
    debug("Could not find the line: $last_line in dmesg\n");
    $last_line = "";
    $start = 1;
  }
}

foreach (split/\n/, $dmesg) {

  if ($last_line) {
    $start = 1 if $last_line eq $_;
  }
  next unless $start;

  $last_line = $_;

  #[Mon Jan  4 06:00:07 2021] CPU: 0 PID: 3 Comm: ksoftirqd/0 Tainted: P           OE  ------------   3.10.0-693cpx86_64 #1
  next unless /Tainted: /;

  my ($process, $state)   = /Comm: (.*?) Tainted: (.*?)--/;

  $state =~ s/\s//g;


  next unless $state;

  my $print = "$process: ";
  foreach (split//, $state) {
    $print .= " $state_info{$_}, ";
  }

  $print .= "\n";

  print $print;
  debug($print);

}

open my $fh_w, ">", $file_last_line or die "Can't write to $file_last_line: $!";
print $fh_w $last_line;
close $fh_w;
