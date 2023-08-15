#!/usr/bin/perl
use warnings;
use strict;

$0 = "perl diff output VER 100";
$|++;

my $cmd             = shift @ARGV // die "Need a command to run";
my $sleep           = shift @ARGV // 1;
my $type            = shift @ARGV // 'full'; # lines full
my $logg_if_diff    = shift @ARGV // 1;
my $dir_tmp         = "/tmp/zabbix/diff_output";
our $file_debug     = "$dir_tmp/debug.log";
our $debug          = 0;
my %db;
my $db_tmp            = {};


$type               = "lines" if $cmd =~ /cat|tail/;

my $date_time_start   = get_date_time();
my $date_time_start_safe    = $date_time_start;
$date_time_start_safe       =~ s/[:\s]/-/g;

my $cmd_safe        = $cmd;
$cmd_safe =~ s/\W/_/g;
$cmd_safe =~ s/_{2,}/_/g;

my $dir_cmd           = "$dir_tmp/$cmd_safe";
my $file_debug_cmd    = "$dir_tmp/$cmd_safe-debug.log";

system "mkdir -p $dir_tmp" if not -d $dir_tmp;
debug("mkdir $dir_tmp") if $debug > 0;

$$db_tmp{'cmd'}{$cmd}{'count'} = 0;
@{$$db_tmp{'cmd'}{$cmd}{'log'}} = ();
#print "$cmd\n";
debug("CMD: $cmd");

while (1){
  open my $fh_r, "-|", $cmd or die "Can't run $cmd: $!";
  debug("CMD: $cmd") if $debug > 4;

  my $out;
  my $diff_found = 0;
  my $diff_data;
  $$db_tmp{'cmd'}{$cmd}{'count'}++;

  while (readline $fh_r){
    my $line = $_;
    $out    .= $_;

    s/^\s{0,}//;

    # remove timestamp
    s/^.*?\s{1,}.*?\s{1,}.*?\s{1,}.*?\s{1,}//;

    # remove PID
    #s/\[\d{1,}\]://;

    debug("line after format: $_") if $debug > 5;

    next if not defined $_;
    next if length $_ == 0;

    if (defined $db{$_}){
      $db{$_}++;
      next;
    }
    else{
      #print "debug(\$line: '$line'. \$_: '$_')\n";
      debug($line);

      $db{$_} = 1;
      $diff_data .= $line;
      $diff_found = 1;
    }
  }

  $diff_found = 0 if $$db_tmp{'cmd'}{$cmd}{'count'} == 1;

  if ($diff_found == 1){
    debug("\$diff_found == 1") if $debug > 0;

    system qq#mkdir -p $dir_cmd# if not -d $dir_cmd;

    my $date_time         = get_date_time();
    my $date_time_safe    = $date_time;
    $date_time_safe       =~ s/[:\s]/-/g;

    my $file_log        = "$dir_cmd/$date_time_start_safe.log";

    $$db_tmp{'cmd'}{$cmd}{'diff'}{'count'}++;

    my $file_log_out    = "$date_time\n\n$cmd\ndiff count: $$db_tmp{'cmd'}{$cmd}{'diff'}{'count'}\n\ndiff start:\n\n$diff_data\ndiff end\n\ncommand output:\n\n$out";
    my $print_out       = "$date_time\n\n$cmd\ndiff count: $$db_tmp{'cmd'}{$cmd}{'diff'}{'count'}\n\ncommand output:\n\n$out";

    if ($type eq 'full'){
      system "clear";
      print $print_out;
    }

    if ($type eq 'full'){
      print "\n\n$file_log\n";
      open my $fh_w_log, ">", $file_log or die "Can't write to $file_log: $!";
      print  $fh_w_log $file_log_out;
      close $fh_w_log;
    }

    print_log();
  }
  $out        = undef;
  $diff_data  = undef;

  sleep $sleep if not $sleep == 0;
  close $fh_r;
}

sub get_date_time {
  #debug("start", "debug", \[caller(0)] ) if $debug > 2;
  #debug("Input data: ".join ", ", @_, "debug", \[caller(0)] ) if $debug > 2;

  my %input = @_;

  $input{'time'}         = time  unless defined $input{'time'};

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime($input{'time'});
  my $timestamp = sprintf ( "%04d-%02d-%02d %02d:%02d:%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec);

  #debug("end", "debug", \[caller(0)] ) if $debug > 2;
  return $timestamp;
}

sub debug {
  my $text = shift // return;
  chomp $text;
  my $date_time       = get_date_time();

  my $line_out = "$date_time. $text\n";

  if (defined $$db_tmp{'cmd'}{$cmd}{'count'}){
    push @{$$db_tmp{'cmd'}{$cmd}{'log'}}, $line_out if not $$db_tmp{'cmd'}{$cmd}{'count'} == 1;
    pop @{$$db_tmp{'cmd'}{$cmd}{'log'}} if @{$$db_tmp{'cmd'}{$cmd}{'log'}} > 100;
  }

  print $line_out;

  open my $fh_w_a_debug, ">>", $file_debug or die "Can't write to $file_debug: $!";
  print $fh_w_a_debug $line_out;
  close $fh_w_a_debug;
}

sub print_log {
  print "log:\n";
  my $print_count_max = 10;
  my $print_count     = 0;
  foreach my $log_line (reverse @{$$db_tmp{'cmd'}{$cmd}{'log'}}){
    last if $print_count++ > $print_count_max;

    print $log_line;
  }
}

