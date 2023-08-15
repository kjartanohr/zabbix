#!/usr/bin/perl_mini
use warnings;
use strict;

# 2023-06-07-13-01-05

=pod
/var/log/opt/CPsuite-R80.40/fw1/CTX/CTX00003/2023-06-05_163238_6.log

2023-06-06_000000.adtlog
2023-06-06_000000.adtlogaccount_ptr
2023-06-06_000000.adtloginitial_ptr
2023-06-06_000000.adtlogptr
2023-06-06_000000.log
2023-06-06_000000.logaccount_ptr
2023-06-06_000000.loginitial_ptr
2023-06-06_000000.logptr
=cut

#my $dir       = "/opt/CPsuite-R80.40/fw1/log/";
my $dir       = "/var/";
my $cmd_find  = qq{find "$dir" -name "*.log" 2>/dev/null};
my $dry_run   = 0;
my $debug = 0;

my @verify = qw(adtlog adtlogaccount_ptr adtloginitial_ptr adtlogptr logaccount_ptr loginitial_ptr logptr);

open my $fh_r, "-|", $cmd_find or die "Can't run $cmd_find: $!";
print "CMD: $cmd_find\n";

while (my $line = readline $fh_r){
  chomp $line;
  #print "line: $line\n";
  next if not $line =~ m#/log/#;
  #next if not $line =~ m#/20\d{2}-\d{2}-\d{2}-\d{5,}.*\.log$#;
  next if not $line =~ m#/20\d{2}-\d{2}-\d{2}_\d{5,}.*\.log$#;

  if (not -f $line){
    print "$line is not a file. next\n";
    next;
  }

  print "file: $line\n";

  my $corrupt_log_found = 0;

  my ($file_short) = $line =~ /(.*?)\.log/;
  print "file short: $file_short\n" if $debug > 0;

  $corrupt_log_found = 1 if run_verify($file_short);

  if ($corrupt_log_found){

    my ($dir_log) = $line =~ /(.*)\//;

    print "starting repair on corrupt log file. $line\n"  if $debug > 0;
    my $cmd_fw_repair = qq{cd $dir_log ; pwd ; time fw -d repairlog -u "$line"};
    print "CMD: $cmd_fw_repair\n";
    system $cmd_fw_repair if $dry_run == 0;

    print "Could not repair corrupt file: $line\n" if run_verify($file_short);
  }


}

sub run_verify {
  my $file    = shift;
  my $return  = 0;

  foreach my $verify (@verify){
   
    my $verify_file = "$file.$verify";
    print "verify file: $verify_file\n" if $debug > 0;

    if (not -f $verify_file){
      $return = 1;
      print "ERROR file is missing $verify_file\n";
    }
  }
  return $return;
}

