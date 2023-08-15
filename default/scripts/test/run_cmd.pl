#!/usr/bin/perl5.32.0

# 2023.03.29

BEGIN{
  require "/usr/share/zabbix/repo/lib/lib.pm";
  #require "/usr/share/zabbix/repo/scripts/auto/lib-dev.pm";
  #require "/usr/share/zabbix/repo/scripts/auto/lib-2022.10.03.pm";
  #require "./lib.pm" if -f "./lib.pm";  #For local lib dev testing
  #push @INC ,"/usr/share/zabbix/repo/files/auto/"; 
  #print join "\n", @INC;
}

use warnings;
use strict;
use KFO::lib;

my %config;
my $lib = KFO::lib->new();
$lib->config(\%config);

my $org_name      = $0;
$0 = "perl run cmd VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

$lib->zabbix_check($ARGV[0]);


my $dir_tmp               = "/tmp/zabbix/run_cmd";
our $file_debug           = "$dir_tmp/debug.log";

our $debug                = 1;          #This needs to be 0 when running in production
our $info                 = 1;
our $warning              = 1;
our $error                = 1;
our $fatal                = 1;

my $dry_run               = 0;

#Zabbix health check
zabbix_check($ARGV[0]);

#Check if this script is running
#exit if check_if_other_self_is_running($0, $$);

#Create tmp dir
create_dir($dir_tmp);

#Delete log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);


#End of standard header


debug("$0 starting", "debug", \[caller(0)] ) if $debug;

unless (@ARGV) {
  help(
    'msg'         => "Missing input data. No data in \@ARGV",
    'die'         => 1,
    'debug'       => 1,
    'debug_type'  => "fatal",
  );
}

#my %input = @ARGV;
my %input = parse_command_line(@ARGV);

if (defined $input{'help'}) {
  help(
    'msg'   => "help started from command line",
    'exit'  => 1,
  );
}

#Activate debug if debug found in command line options
if (defined $input{'debug'}) {
  $debug = $input{'debug'};
}


unless (defined $input{'command'} or defined $input{'file'}) {
  my $msg = "Missing input data. Need command or file to read data from";
  debug($msg, "fatal", \((caller(0))[3]) );
  die $msg;
}

#Default values
$input{'command-ttl'}     = 10    unless defined $input{'command-ttl'};        #TTL for command output. This is used for run_cmd()
$input{'command-timeout'} = 10    unless defined $input{'command-timeout'};    #Timeout for the command to run
$input{'output-ttl'}      = 10    unless defined $input{'output-ttl'};         #TTL for output data. If more than one item is asking for the same data. Send back the output cache

$input{'msg-no-match'}    = 9999  unless defined $input{'msg-no-match'};       #Error message if no data found

my $data;
my $result;

#Run command
if (defined $input{'command'} and $input{'command'}) {
  debug("\$input{'command'} is defind and has data: $input{'command'}. run_command()", "debug", \[caller(0)] ) if $debug;
  $data = run_command(%input);
}
elsif (@ARGV) {
  my $command = join " ", @ARGV;
  debug("\@ARGV has data. run_command($command)", "debug", \[caller(0)] ) if $debug;
  $data = run_command($command);
}




#Validate \$data
if (defined $data and length $data > 0) {
  debug("\$data is defind and has data: $data", "debug", \[caller(0)] ) if $debug;
}
else {
  debug("\$data is not defind and has data. return \$input{'msg-no-match'} $input{'msg-no-match'}", "debug", \[caller(0)] ) if $debug;
  print $input{'msg-no-match'};
  exit;
}

#Regex substitute the output before regex extract
if (defined $input{'regex-sub-output-from'} and $input{'regex-sub-output-from'}) {

  debug("\$input{'regex-sub-output-from'} is defind and has data: $input{'regex-sub-output-from'}. run_regex_sub()", "debug", \[caller(0)] ) if $debug;
  run_regex_sub(
    'comment'     => "if \$input{'regex-sub-output-from'}",
    'regex-from'  => $input{'regex-sub-output-from'}, 
    'regex-to'    => $input{'regex-sub-output-to'}    || "", 
    'regex-opt'   => $input{'regex-sub-output-opt'}   || "", 
    'data'        => \$data,
  );
}




#Extract text with regex
if (defined $input{'regex-match'} and $input{'regex-match'}) {
  debug("\$input{'regex-match'} is defind and has data: $input{'regex-match'}. run_regex()", "debug", \[caller(0)] ) if $debug;

  $result = run_regex(
    'regex-match'       => $input{'regex-match'}, 
    'regex-match-type'  => $input{'regex-match-type'} || "normal",
    'data'              => \$data,
    'desc'              => "run_cmd from $0",
  );
}

#Regex substitute the result
if (defined $input{'regex-sub-result-from'} and $input{'regex-sub-result-from'}) {

  debug("\$input{'regex-sub-result-from'} is defind and has data: $input{'regex-sub-result-from'}. run_regex_sub()", "debug", \[caller(0)] ) if $debug;
  run_regex_sub(
    'comment'     => "if \$input{'regex-sub-output-from'}",
    'regex-from'  => $input{'regex-sub-result-from'}, 
    'regex-to'    => $input{'regex-sub-result-to'}    || "", 
    'regex-opt'   => $input{'regex-sub-result-opt'}   || "", 
    'data'        => \$result,
  );
}


#Print result
if (defined $result) {
  debug("Data returned to zabbix: '$result'", "debug", \[caller(0)] ) if $debug;
  print $result;
}
else {
  debug("No data found. No data returned to zabbix. print \$input{'msg-no-match'} $input{'msg-no-match'} and exit", "debug", \[caller(0)] ) if $debug;
  print $input{'msg-no-match'};
  exit;
}

if ($debug) {
  print "\n\n";
  print get_zabbix_item(%input);
  print "\n\n";
}



sub run_command {
  my $sub_name = (caller(0))[3];
  debug("start", $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 1;
  debug("input: ".Dumper(@_), $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 3;

  #sub header start
  my %input   = @_;
  debug("$sub_name. $input{'desc'}", $sub_name, \[caller(0)]) if $config{'log'}{'desc'}{'enabled'} and $config{'log'}{'desc'}{'level'} > 0 and defined $input{'desc'};

  my $return;

  #default values
  $input{'exit-if-fatal'}         //= 0;
  $input{'return-if-fatal'}       //= 1;
  $input{'validate-return-data'}  //= 1;
  #$input{'xxx'} = "yyy" unless defined $input{'xxx'};

  #validate input data start
  if ($config{"val"}{'sub'}{'in'}){
    my @input_type = qw( desc );
    foreach my $input_type (@input_type) {

      unless (defined $input{$input_type} and length $input{$input_type} > 0) {
        debug("missing input data for '$input_type'", "fatal", \[caller(0)] ) if $config{'log'}{'fatal'}{'enabled'} and $config{'log'}{'fatal'}{'level'} > 3;
        return 0;
      }
    }
  }
  #validate input data start

  #sub header end

  #sub main code start

  if (defined $input{'command'} and $input{'command'}) {
    debug("\$input{'command'} is defind and has data: $input{'command'}", "debug", \[caller(0)] ) if $debug;

    if (defined $input{'vsid'} and length $input{'vsid'} > 0) {
      debug("\$input{'vsid'} is defind and has data: $input{'vsid'}", "debug", \[caller(0)] ) if $debug;

      $input{'command'} = "vsenv $input{'vsid'} &>/dev/null ; ".$input{'command'};
      debug("After adding vsenv to command: $input{'command'}", "debug", \[caller(0)] ) if $debug;
    }

    my $run_cmd = {
      'cmd'             => $input{'command'}, 
      'return-type'     => 's', 
      'refresh-time'    => $input{'command-ttl'}, 
      'timeout'         => $input{'command-timeout'}, 
    };

    $$run_cmd{'vsid'} = $ENV{'VSID'} if defined $ENV{'VSID'};

    $data = run_cmd(($run_cmd));

  }

  #sub main code END

  #sub end section START

  #Validate return data
  if ($config{"val"}{'sub'}{'out'}){

    if ($input{'validate-return-data'} and defined $return and length $return == 0) {
      debug("Return data is not defined. Input data: ".Dumper(%input), "fatal", \[caller(0)] )  if $config{'log'}{'fatal'}{'enabled'} and $config{'log'}{'fatal'}{'level'} > 3;
      run_exit() if $input{'exit-if-fatal'};
      return;
    }

  }


  debug("end",  $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 1;
  return $return;

  #sub end section END

}
#sub template END






sub run_regex {
  debug("start", "debug", \[caller(0)] ) if $debug;
  debug("Input data: ".join ", ", @_, "debug", \[caller(0)] ) if $debug;

  my %input = @_;
  my $match = undef;


  #regex multi-line START
  if (defined $input{'regex-match-type'} and $input{'regex-match-type'} eq "multi-line") {
    debug("\$input{'regex-match-type'} is defind and has data: $input{'regex-match-type'}. m//s", "debug", \[caller(0)] ) if $debug;
    #debug("data: ${$input{'data'}}", "debug", \[caller(0)] ) if $debug;
  
    my $regex =  $input{'regex-match'};
    ($match)  = ${$input{'data'}} =~ m/$regex/s;

    if (defined $match) {
      debug("regex matched. Data returned: '$match'", "debug", \[caller(0)] ) if $debug;
      return $match;
    }
    else {
      debug("regex did not match. return", "debug", \[caller(0)] ) if $debug;
      return;
    }
  }
  #regex multi-line END
  

  #regex normal START
  if (defined $input{'regex-match-type'} and $input{'regex-match-type'} eq "normal") {
    debug("\$input{'regex-match-type'} is defind and has data: $input{'regex-match-type'}. m//", "debug", \[caller(0)] ) if $debug;
  
    my $regex =  $input{'regex-match'};
    ($match)  = ${$input{'data'}} =~ m/$regex/;

    if (defined $match) {
      debug("regex matched. Data returned: '$match'", "debug", \[caller(0)] ) if $debug;
      return $match;
    }
    else {
      debug("regex did not match. return", "debug", \[caller(0)] ) if $debug;
      return;
    }
  }
  #regex normal END

    
  debug("end", "debug", \[caller(0)] ) if $debug;
  return;
}

sub run_regex_sub {
  debug("start", "debug", \[caller(0)] ) if $debug;
  debug("Input data: ".join ", ", @_, "debug", \[caller(0)] ) if $debug;

  my %input = @_;
  my @regex;

  $input{'regex-opt'} ||= "normal";
  my $comment = $input{'comment'} || "comment missing";

  debug("$comment. Data before regex sub: ${$input{'data'}}", "debug", \[caller(0)] ) if $debug;

  my $input_regex_from  =  $input{'regex-from'};
  my $input_regex_to    =  $input{'regex-to'};
  my $input_regex_opt   =  $input{'regex-opt'};
  
  $input_regex_from     =~ s/^\/|\/$//g;
  $input_regex_to       =~ s/^\/|\/$//g;
  $input_regex_opt      =~ s/^\/|\/$//g;

  my @regex_from  = split/\/,\//, $input_regex_from;
  my @regex_to    = split/\/,\//, $input_regex_to;
  my @regex_opt   = split/\/,\//, $input_regex_opt;

  my $regex_from;
  my $regex_to;
  my $regex_opt;


  #${$input{'data'}} =~ s/$regex_from/$regex_to/;
  
  for (my $i = 0; $regex_from[$i]; $i++) {

    my $regex_from  = $regex_from[$i];

    $regex_to       = $regex_to[$i] if defined $regex_to[$i];
    $regex_to       = ""            if not defined $regex_to;

    $regex_opt      = $regex_opt[$i] if defined $regex_opt[$i];
    $regex_opt      = "normal"       if not defined $regex_opt;

    debug("$comment. regex-from:  $regex_from", "debug", \[caller(0)] ) if $debug;
    debug("$comment. regex-to:    $regex_to", "debug", \[caller(0)] ) if $debug;
    debug("$comment. regex-opt:   $regex_opt", "debug", \[caller(0)] ) if $debug;

    ${$input{'data'}} =~ s/$regex_from/$regex_to/ if $regex_opt   eq "normal";

    ${$input{'data'}} =~ s/$regex_from/$regex_to/g if $regex_opt  eq "g";

    ${$input{'data'}} =~ s/$regex_from/$regex_to/i if $regex_opt  eq "i";

    ${$input{'data'}} =~ s/$regex_from/$regex_to/s if $regex_opt  eq "s";

  }

  debug("$comment. Data after regex sub: ${$input{'data'}}", "debug", \[caller(0)] ) if $debug;

  debug("$comment. end", "debug", \[caller(0)] ) if $debug;

}

sub get_zabbix_item {
  #debug("start", "debug", \[caller(0)] ) if $debug;

  my %input = @_;

  #get_text["command", "fw ctl pstat -h -k -s -l -p -m", "regex-match-type", "multi-line", "regex-match", "Kernel memory.*?Total memory  bytes  used:\s*?(\d{1,})"]
  my $item;

  #remove defaults
  foreach my $key ("msg-no-match", "command-timeout", "command-ttl", "output-ttl", "debug" ) {
    next unless defined $input{$key};
    delete $input{$key};
  }

  delete $input{'regex-match-type'} if $input{'regex-match-type'} eq "normal";
  

  #In correct order
  foreach my $key ("command", "regex-match", "regex-sub-output-from", "regex-sub-output-to" ) {
    next unless defined $input{$key};

    $item .= qq# --$key="$input{$key}"#;
    delete $input{$key};
  }

  foreach my $key (keys %input) {
    $item .= qq# --$key="$input{$key}"#;
  }

  $item =~ s/,$//;
  $item = "get_text[ '$item ' ]";

  return $item;

  debug("end", "debug", \[caller(0)] ) if $debug;

}

sub help {
  my %input = @_;

  $input{'msg'}         ||= "Missing error message";
  $input{'die'}         ||= 0;
  $input{'exit'}        ||= 1;
  $input{'stdout'}      ||= 1;
  $input{'stderr'}      ||= 0;
  $input{'debug'}       ||= 0;
  $input{'debug_type'}  ||= "debug";



  my $msg = <<"EOF";

  Error message: $input{'msg'}

  Help: 

  $org_name --help
  $org_name help
  
  Examples:

  Run a command on VS 0

  
   

EOF

  debug($msg, $input{'debug_type'}, \[caller(0)] ) if defined $input{'debug'} and $input{'debug'};

  warn $msg if defined $input{'stderr'} and $input{'stderr'};

  die $msg if defined $input{'die'} and $input{'die'};

}

