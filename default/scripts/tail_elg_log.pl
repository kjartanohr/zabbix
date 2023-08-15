#!/usr/bin/perl5.32.0
#bin
BEGIN{

  #init global pre checks
  #init_local_begin('version' => 1);

  #Global var
  our %config;

  require "/usr/share/zabbix/repo/files/auto/lib.pm";
  #require "./lib.pm";

  #Zabbix health check
  zabbix_check($ARGV[0]) if defined $ARGV[0] and $ARGV[0] eq "--zabbix-test-run";


  #init global pre checks
  init_global_begin('version' => 1);
}

#TODO

#Changes

#BUGS

#Feature request

use warnings;
no warnings qw(redefine);
use strict;
use JSON;


#Run init global. This will die if global checks failes
init_global_before_config('version' => 1);

our $debug = 0;
my $version                   = 100;
my $process_name_org          = $0;
my $process_name              = "tail log files";
$0                            = "perl $process_name VER $version";

#Print the data immediately. Don't wait for full buffer
$|++;

$SIG{CHLD}                    = "IGNORE";
#$SIG{INT}                     = \&save_and_exit('msg') => 'Signal INIT';

#Gloal var
our $db;
our %tmp  = ();
our %argv = ();

my  $dir_tmp_name_safe          = get_filename_safe('name' => $process_name, 'exit-if-fatal' => 1);
our $dir_tmp                    = "/tmp/zabbix/$dir_tmp_name_safe";
our $file_debug                 = "$dir_tmp/debug.log";
my  $file_exit                  = "$dir_tmp/stop";


#Get default config
our %config                     = get_config();

#log config
$config{'log'}{'debug'}       = {
  "enabled"       => 5,     #0/1
  "level"         => 5,     #0-9
  "print"         => 1,     #Print to STDOUT
  "log"           => 0,     #Save to log file
  "die"           => 0,     #Die/exit if this type of log is triggered
};
$config{'log'}{'info'}       = {
  "enabled"       => 1,     #0/1
  "level"         => 1,     #0-9
  "print"         => 1,     #Print to STDOUT
  "log"           => 1,     #Save to log file
};
$config{'log'}{'warning'}       = {
  "enabled"       => 1,     #0/1
  "level"         => 1,     #0-9
  "print"         => 1,     #Print to STDOUT
  "log"           => 1,     #Save to log file
};
$config{'log'}{'error'}       = {
  "enabled"       => 1,     #0/1
  "level"         => 1,     #0-9
  "print"         => 1,     #Print to STDOUT
  "log"           => 1,     #Save to log file
};
$config{'log'}{'fatal'}       = {
  "enabled"       => 1,     #0/1
  "level"         => 1,     #0-9
  "print"         => 1,     #Print to STDOUT
  "log"           => 1,     #Save to log file
  "die"           => 1,     #Die/exit if this type of log is triggered
};

#legacy debug on/off
$debug = $config{'log'}{'debug'}{'level'} if $config{'log'}{'debug'}{'enabled'};


#Fork
$config{'init'}{'fork'}         = 0;

#JSON
$config{'json'}{'enabled'}      = 1;

#Files
$config{'file'}{'stdout'}       = "$dir_tmp/stdout.log";
$config{'file'}{'stderr'}       = "$dir_tmp/stderr.log";

# if $config{'log'}{'debug'}{'enable'} and $config{'log'}{'debug'}{'level'} > 1;
#debug("", "debug", \[caller(0)] ) if $config{'log'}{'debug'}{'enable'} and $config{'log'}{'debug'}{'level'} > 1;
#debug("", "info", \[caller(0)] )  if $config{'log'}{'info'}{'enable'} and $config{'log'}{'info'}{'level'} > 1;
#debug("", "warning", \[caller(0)] ) if $config{'log'}{'warning'}{'enable'} and $config{'warning'}{'info'}{'level'} > 1;
#debug("", "error", \[caller(0)] )  if $config{'log'}{'error'}{'enable'} and $config{'log'}{'error'}{'level'} > 1;
#debug("", "fatal", \[caller(0)] )  if $config{'log'}{'fatal'}{'enable'} and $config{'log'}{'fatal'}{'level'} > 1;
#debug("", "fatal", \[caller(0)] );

$config{'msg'}{'help'} = qq#$process_name_org ' --username="test-user" --password="vpn123" --comment="Cert comment" --file="cert.p12" '#;

#Run init local after config
#init_local_after_config();
init_global_after_config('version' => 1);

#End of standard header

#print Dumper %config;

#Fork a child and exit the main script
fork_and_exit( 'version' => 1, 'stdout' => $config{'file'}{'stdout'}, 'stderr' => $config{'file'}{'stderr'}) if $config{'init'}{'fork'} and not $config{'log'}{'debug'}{'enable'};
#Eveything after here is the child


#main code START

#main_code();

my @search        = qw( *.log *.elg );
my $exclude_file  = 'zabbix|cpcgroup|ted.elg|pepd.elg|dlpu.elg|fw.log$|\d{4}-\d{2}.*\.log';
my $exclude_line  = 'kdjkdfjdkjf';

my @files;

foreach my $search (@search){
  foreach my $file (`find / -mtime -1 -iname "$search" 2>/dev/null`){

    chomp $file;
    next if $file =~ /$exclude_file/i;
    push @files, $file;
  }
}

my $files = join " ", @files;

my $date_time = get_date_time();
my $date_time_safe = get_filename_safe('name' => $date_time);

my $cmd_tail = "tail -n0 -F $files 2>&1";
my $cmd_gzip = "gzip --force --best - >debug-$date_time_safe.gz";

#Tail
open my $fh_r, "-|", $cmd_tail or die "Can't run $cmd_tail: $!";

#gzip
open my $fh_w, "|-", $cmd_gzip or die "Can't run $cmd_gzip: $!";

while (my $line = readline $fh_r) {

  #remove spam
  next if $line =~ /$exclude_line/i;

  #bzip
  print $fh_w $line;

  #stdout
  print $line;


}

#main code END

#sub template START
=pod
main_code();
=cut
sub main_code {
  debug("start", "debug", \[caller(0)]) if $config{'log'}{'debug'}{'enable'} and $config{'log'}{'debug'}{'level'} > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $config{'log'}{'debug'}{'enable'} and $config{'log'}{'debug'}{'level'} > 3;

  #sub header START
  my %input   = @_;
  my $return;

  #Default values
  $input{'exit-if-fatal'}         = 0   unless defined $input{'exit-if-fatal'};
  $input{'return-if-fatal'}       = 1   unless defined $input{'return-if-fatal'};
  $input{'validate-return-data'}  = 0   unless defined $input{'validate-return-data'};
  #$input{'XXX'} = "YYY" unless defined $input{'XXX'};

  #Set debug if debug found in input
  if (defined $input{'debug'}) {
    debug("debug defined in input data. debug: $input{'debug'}", "debug", \[caller(0)]) if $config{'log'}{'debug'}{'enable'} and $config{'log'}{'debug'}{'level'} > 1;
    local $config{'log'} = $config{'log'};
    $config{'log'}{'debug'}{'enable'} = $input{'debug'};
  }

  my @input_type = qw(  );
  foreach my $input_type (@input_type) {

    unless (defined $input{$input_type} and length $input{$input_type} > 0) {
      debug("Missing input data for '$input_type'", "fatal", \[caller(0)] );
      run_exit() if $input{'exit-if-fatal'};
      return;
    }
  }

  #sub header END

  #sub main code START

  print "test from template\n";


  #sub main code END

  #sub end section START

  #Validate return data
  if ($input{'validate-return-data'} and defined $return and length $return == 0) {
    debug("Return data is not defined. Input data: ".Dumper(%input), "fatal", \[caller(0)] );
    run_exit() if $input{'exit-if-fatal'};
    return;
  }


  debug("end", "debug", \[caller(0)]) if $config{'log'}{'debug'}{'enable'} and $config{'log'}{'debug'}{'level'} > 1;
  return $return;

  #sub end section END

}
#sub main_code END






#sub template START
=pod
  help(
    'msg'         => "Missing input data. No data in \@ARGV",
    'die'         => 1,
    'debug'       => 1,
    'debug_type'  => "fatal",
  );
=cut
sub sub_template_2 {
  debug("start", "debug", \[caller(0)]) if $config{'log'}{'debug'}{'enable'} and $config{'log'}{'debug'}{'level'} > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $config{'log'}{'debug'}{'enable'} and $config{'log'}{'debug'}{'level'} > 3;

  #sub header START
  my %input   = @_;
  my $return;

  #Default values
  $input{'exit-if-fatal'}         = 0   unless defined $input{'exit-if-fatal'};
  $input{'return-if-fatal'}       = 1   unless defined $input{'return-if-fatal'};
  $input{'validate-return-data'}  = 1   unless defined $input{'validate-return-data'};
  #$input{'XXX'} = "YYY" unless defined $input{'XXX'};

  #Set debug if debug found in input
  if (defined $input{'debug'}) {
    debug("debug defined in input data. debug: $input{'debug'}", "debug", \[caller(0)]) if $config{'log'}{'debug'}{'enable'} and $config{'log'}{'debug'}{'level'} > 1;
    local $config{'log'} = $config{'log'};
    $config{'log'}{'debug'}{'enable'} = $input{'debug'};
  }

  my @input_type = qw( name );
  foreach my $input_type (@input_type) {

    unless (defined $input{$input_type} and length $input{$input_type} > 0) {
      debug("Missing input data for '$input_type'", "fatal", \[caller(0)] );
      run_exit() if $input{'exit-if-fatal'};
      return;
    }
  }

  #sub header END

  #sub main code START




  #sub main code END

  #sub end section START

  #Validate return data
  if ($input{'validate-return-data'} and defined $return and length $return == 0) {
    debug("Return data is not defined. Input data: ".Dumper(%input), "fatal", \[caller(0)] );
    run_exit() if $input{'exit-if-fatal'};
    return;
  }


  debug("end", "debug", \[caller(0)]) if $config{'log'}{'debug'}{'enable'} and $config{'log'}{'debug'}{'level'} > 1;
  return $return;

  #sub end section END

}
#sub template END

