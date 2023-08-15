#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
  #require "./lib.pm";
}

# 2023-05-31 13-59-33

use warnings;
use strict;
use Data::Dumper;
use JSON;
use MIME::Base64;

my $org_name      = $0;
$0 = "perl get data VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);


my $dir_tmp               = "/tmp/zabbix/get_data";
our $file_debug           = "$dir_tmp/debug.log";

our $debug                = 0;                                                  #This needs to be 0 when running in production
our $info                 = 0;
our $warning              = 1;
our $error                = 1;
our $fatal                = 1;

my %config;

$config{'dir'}{'log'} = ".";

$config{'log'}{'default'}       = {
  "enabled"       => 0,     #0/1
  'name'          => 'default', 
  "level"         => 9,     #1-9
  "print"         => 1,     #Print to STDOUT
  "print-warn"    => 0,     #Print to STDERR
  "log"           => 0,     #Save to log file
  "file"          => "$config{'dir'}{'log'}/default.log", #Log file
  "file-fifo"     => 0,     #Create a fifo file for log
  "file-size"     => 10,    #MB max log file size
  "cmd"           => "",    #Run CMD if log. Variable: _LOG_
  "lines-ps"      => 10,    #Max lines pr second
  "die"           => 0,     #Die/exit if this type of log is triggered

  'mqtt'          => {
    "enabled"       => 0,     #0/1
    "level"         => 9,     #1-9
    "topic"         => 'rtl/log/default',
  },
};

$config{'log'}{'debug'}       = {
  "enabled"       => 0,     #0/1
  'name'          => 'debug', 
  "level"         => 2,     #1-9
  "print"         => 1,     #Print to STDOUT
  "print-warn"    => 0,     #Print to STDERR
  "log"           => 0,     #Save to log file
  "file"          => "$config{'dir'}{'log'}/debug.log", #Log file
  "file-fifo"     => 0,     #Create a fifo file for log
  "file-size"     => 100*1024*1024,    #MB max log file size
  "cmd"           => "",    #Run CMD if log. Variable: _LOG_
  "lines-ps"      => 10,    #Max lines pr second
  "die"           => 0,     #Die/exit if this type of log is triggered

  'mqtt'          => {
    "enabled"       => 0,     #0/1
    "topic"         => 'rtl/log/__NAME__',
  },
};

$config{'log'}{'info'}       = {
  "enabled"       => 1,     #0/1
  'name'          => 'info', 
  "level"         => 5,     #1-9
  "print"         => 1,     #Print to STDOUT
  "print-warn"    => 0,     #Print to STDERR
  "log"           => 1,     #Save to log file
  "file"          => "$config{'dir'}{'log'}/info.log", #Log file
  "file-fifo"     => 0,     #Create a fifo file for log
  "file-size"     => 100*1024*1024,    #MB max log file size
  "cmd"           => "",    #Run CMD if log. Variable: _LOG_
  "lines-ps"      => 10,    #Max lines pr second
  "die"           => 0,     #Die/exit if this type of log is triggered

  'mqtt'          => {
    "enabled"       => 1,     #0/1
    "topic"         => 'rtl/log/__NAME__',
  },
};

$config{'log'}{'warning'}       = {
  "enabled"       => 1,     #0/1
  'name'          => 'warning', 
  "level"         => 5,     #1-9
  "print"         => 1,     #Print to STDOUT
  "print-warn"    => 0,     #Print to STDERR
  "log"           => 1,     #Save to log file
  "file"          => "$config{'dir'}{'log'}/warning.log", #Log file
  "file-fifo"     => 0,     #Create a fifo file for log
  "file-size"     => 100*1024*1024,    #MB max log file size
  "cmd"           => "",    #Run CMD if log. Variable: _LOG_
  "lines-ps"      => 10,    #Max lines pr second
  "die"           => 0,     #Die/exit if this type of log is triggered

  'mqtt'          => {
    "enabled"       => 1,     #0/1
    "topic"         => 'rtl/log/__NAME__',
  },
};

#debug("", "error", \[caller(0)] ) if $config{'log'}{'error'}{'enabled'};
$config{'log'}{'error'}       = {
  "enabled"       => 1,     #0/1
  'name'          => 'debug', 
  "level"         => 5,     #1-9
  "print"         => 1,     #Print to STDOUT
  "print-warn"    => 0,     #Print to STDERR
  "log"           => 1,     #Save to log file
  "file"          => "$config{'dir'}{'log'}/error.log", #Log file
  "file-fifo"     => 0,     #Create a fifo file for log
  "file-size"     => 100*1024*1024,    #MB max log file size
  "cmd"           => "",    #Run CMD if log. Variable: _LOG_
  "lines-ps"      => 10,    #Max lines pr second
  "die"           => 0,     #Die/exit if this type of log is triggered

  'mqtt'          => {
    "enabled"       => 1,     #0/1
    "topic"         => 'rtl/log/__NAME__',
  },
};

$config{'log'}{'fatal'}       = {
  "enabled"       => 1,     #0/1
  'name'          => 'fatal', 
  "level"         => 5,     #1-9
  "print"         => 1,     #Print to STDOUT
  "print-warn"    => 0,     #Print to STDERR
  "log"           => 1,     #Save to log file
  "file"          => "$config{'dir'}{'log'}/fatal.log", #Log file
  "file-fifo"     => 0,     #Create a fifo file for log
  "file-size"     => 100*1024*1024,    #MB max log file size
  "cmd"           => "",    #Run CMD if log. Variable: _LOG_
  "lines-ps"      => 10,    #Max lines pr second
  "die"           => 0,     #Die/exit if this type of log is triggered

  'mqtt'          => {
    "enabled"       => 1,     #0/1
    "topic"         => 'rtl/log/__NAME__',
  },
};

my @input_keys    = (
  #'',
);

create_dir($dir_tmp);

#Delete log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);

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
$input{'command-ttl'}     = 60    unless defined $input{'command-ttl'};        #TTL for command output. This is used for run_cmd()
$input{'command-timeout'} = 25    unless defined $input{'command-timeout'};    #Timeout for the command to run
$input{'output-ttl'}      = 60    unless defined $input{'output-ttl'};         #TTL for output data. If more than one item is asking for the same data. Send back the output cache

$input{'msg-no-match'}    = 9999  unless defined $input{'msg-no-match'};       #Error message if no data found

my $data;
my $result;

#Run command
if (defined $input{'command'} and $input{'command'}) {
  debug("\$input{'command'} is defind and has data: $input{'command'}. run_command()", "debug", \[caller(0)] ) if $debug;
  $data = run_command(%input);
}

#Validate \$data
if (defined $data and length $data > 0) {
  debug("\$data is defind and has data: $data", "debug", \[caller(0)] ) if $debug > 3;
}
else {
  debug("\$data is not defind and has data. return \$input{'msg-no-match'} $input{'msg-no-match'}", "debug", \[caller(0)] ) if $error;
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

  $data = run_regex(
    'regex-match'       => $input{'regex-match'}, 
    'regex-match-type'  => $input{'regex-match-type'} || "normal",
    'data'              => \$data,
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
    'data'        => \$data,
  );
}

#Count regex matches
if (defined $input{'regex-match-count'} and $input{'regex-match-count'}) {

  debug("\$input{'regex-match-count'} is defind and has data: $input{'regex-match-count'}. run_regex_match_count()", "debug", \[caller(0)] ) if $debug;
  run_regex_sub(
    'comment'     => "if \$input{'regex-sub-output-from'}",
    'regex-from'  => $input{'regex-sub-result-from'}, 
    'regex-to'    => $input{'regex-sub-result-to'}    || "", 
    'regex-opt'   => $input{'regex-sub-result-opt'}   || "", 
    'data'        => \$data,
  );
}


#Convert data to hash
if (defined $input{'action'} and $input{'action'} eq "cmd-to-json") {
  debug("\$input{'action'} is defind and has data: $input{'action'} (cmd-to-json). convert command output to json()", "debug", \[caller(0)] ) if $debug;

  my $hash = convert_to_hash(
    'comment'                 => "if \$input{'data-split'}",
    'data'                    => \$data,
    'regex-title'             => $input{'regex-title'},
    'regex-title-not'         => $input{'regex-title-not'},
    'regex-title-if'          => $input{'regex-title-if'},

    'regex-name-value'        => $input{'regex-name-value'},
    'regex-name'              => $input{'regex-name'},
    'regex-value'             => $input{'regex-value'},
  );

  $data = hash_to_json( 'hash_ref' => $hash);
  debug("return data from hash_to_json(): $data", "debug", \[caller(0)] ) if $debug > 2;



}




#Print result
if (defined $data) {
  debug("Data returned to zabbix: '$data'", "debug", \[caller(0)] ) if $debug;
  print $data;
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
  debug("start", "debug", \[caller(0)] ) if $debug > 2;
  debug("Input data: ".join ", ", @_, "debug", \[caller(0)] ) if $debug > 2;

  my %input = @_;

  if (defined $input{'command'} and $input{'command'}) {
    debug("\$input{'command'} is defind and has data: $input{'command'}", "debug", \[caller(0)] ) if $debug > 2;

    if (defined $input{'vsid'} and length $input{'vsid'} > 0) {
      debug("\$input{'vsid'} is defind and has data: $input{'vsid'}", "debug", \[caller(0)] ) if $debug > 2;

      $input{'command'} = "vsenv $input{'vsid'} &>/dev/null ; ".$input{'command'};
      debug("After adding vsenv to command: $input{'command'}", "debug", \[caller(0)] ) if $debug > 2;
    }

    $data = run_cmd({
      'cmd'             => $input{'command'}, 
      'return-type'     => 's', 
      'refresh-time'    => $input{'command-ttl'}, 
      'timeout'         => $input{'command-timeout'}, 
    });

  }

}

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
  my $item_b64;
  my $item_b64_all;
  my $item_full;

  #remove defaults
  foreach my $key ("msg-no-match", "command-timeout", "command-ttl", "output-ttl", "debug" ) {
    next unless defined $input{$key};
    delete $input{$key};
  }

  delete $input{'regex-match-type'} if defined $input{'regex-match-type'} and $input{'regex-match-type'} eq "normal";
  
  

  #In correct order
  if (0){
  foreach my $key ("command", "action", "vsid") {
    next unless defined $input{$key};

    $item           .= qq# --$key="$input{$key}"#;
    $item_b64       .= qq# --$key="$input{$key}"#;

    delete $input{$key};
  }
  }

  foreach my $key (keys %input) {
    debug("foreach %input. key: '$key', value: '$input{$key}'", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
    next unless defined $input{$key};

    my $string_b64  = $input{$key};
    if ($input{$key} =~ /\D/) {
      $string_b64     = string_to_base64('data' => $input{$key});
      $string_b64     = "b64($string_b64)";
    }

    $item           .= qq# --$key="$input{$key}"#;
    $item_b64       .= qq# --$key="$string_b64"#;

  }

  $item =~ s/,$//;

  $item_full = $item;
  $item_full = qq#get_text[ '$item --vsid="0" --command-ttl="60" --command-timeout="25" --msg-no-match="9999" --name="optional name" ' ]#;

  my $item_full_b64 = qq#get_text[ '$item_b64 --vsid="0" --command-ttl="60" --command-timeout="25" --msg-no-match="9999" --name="optional name" ' ]#;

  $item = "get_text[ '$item ' ]";

  $item_b64 =~ s/,$//;
  $item_b64 = "get_text[ '$item_b64 ' ]";


  my $out = "$item\n$item_b64\n$item_full\n$item_full_b64";

  return $out;

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

  $0 --help
  $0 help
  
  Examples:

  Regular/normal regex

  $org_name ' --debug="1" --command="ls -lh \$CPDIR/database/" --vsid="0" --name="postgres ls files" --regex--ml-match="(.*)" '

  $org_name ' --debug="1" --command="psql_client cpm postgres -c "SELECT version()"" --vsid="0" --name="postgres version" --regex-match="PostgreSQL (.*?) " '

  $org_name ' --command="fwaccel stats" --action="cmd-to-json" --vsid="0" --regex-name="(\\w.*?)\\s{3,}" --regex-title="(^\\w.*?)\$" --regex-title-not="\\d" --regex-value="(\\d{1,})" --regex-name-value="(\\w.*?\\s{3,}\\d{1,})" '

  $org_name get_text[ ' --command="cphaprob -a if" --vsid="0" --regex-match="(.*?) .*DOWN" --name="cphaprob -a if down" ']

  $org_name ' --command="cpstat threat-emulation" --action="cmd-to-json" --vsid="0" --regex-title="" --regex-title-not="" --regex-name-value="^(.*)\$" --regex-name="^(.*?):" --regex-value=":\\s{0,}(.*)\$" '
   

EOF

  debug($msg, $input{'debug_type'}, \[caller(0)] ) if $debug;

  warn $msg if defined $input{'stderr'} and $input{'stderr'};

  die $msg if defined $input{'die'} and $input{'die'};

}

sub convert_to_hash {
  debug("start", "debug", \[caller(0)] ) if $debug > 1;
  debug("Input data: ".Dumper(@_), "debug", \[caller(0)] ) if $debug > 2;

  my @json;
  my %json;
  my $help = "unknown help";
  my $type = "unknown type";
  my $count = 0;

  my %input = @_;

  unless (defined $input{'data'}) {
    debug("Missing input data 'data'", "fatal", \[caller(0)] ) if $fatal;
    exit;
  }

  $input{'regex-title'}             = '(\w*\D)'               unless defined $input{'regex-title'};
  $input{'regex-name-value'}        = '(\w*?)\s{1,}(\d{1,})'  unless defined $input{'regex-name-value'};
  $input{'next-line-if-regex'}      = undef                   unless defined $input{'next-line-if-regex'};
  $input{'next-line-unless-regex'}  = undef                   unless defined $input{'next-line-unless-regex'};

  #LINE:
  #next LINE if  defined $input{'next-line-regex'}         and $line =~ /$input{'next-line-regex'}/;
  #next LINE if  defined $input{'next-line-unless-regex'}  and $line !~ /$input{'next-line-unless-regex'}/;
  my $title = "";

  LINE:
  foreach my $line (split /\n/, ${$input{'data'}}) {
    debug("foreach data: '$line'", "debug", \[caller(0)] ) if $debug > 3;

    #Get title START
    TITLE:
    {

      if (defined $input{'regex-title-if'}) {
        my ($title_if)    = $line =~ /$input{'regex-title-if'}/;
        next TITLE unless defined $title_if;
      }

      if (defined $input{'regex-title-not'}) {
        my ($title_not)    = $line =~ /$input{'regex-title-not'}/;
        next TITLE if defined $title_not;
      }

      my ($title_found) = $line =~ /$input{'regex-title'}/;
      
      unless (defined $title_found) {
        last TITLE;
      }

      my $title_first;
      my $title_last    = "";
      my $title_new     = "";

      TITLE_FOREACH:
      foreach my $title_array (split/\s{1,}/, $title_found) {
        debug("foreach split \$title_found: '$title_array'", "debug", \[caller(0)] ) if $debug > 1;

        last TITLE_FOREACH if defined $title_first and $title_first eq $title_array;
        $title_first = $title_array unless defined $title_first;

        next if $title_array eq $title_last;
        $title_last   = $title_array;

        $title_new .= "$title_array ";

      }

      if (defined $title_new) {
        debug("Title found: '$title_new'", "debug", \[caller(0)] ) if $debug > 1;
        $title = $title_new;
      }
    }
    #Get title END

    NAME_VALUE:
    foreach my $nv ($line =~ /$input{'regex-name-value'}/g) {
      debug("while \$input{'data'} =~ /$input{'regex-name-value'}. name and value: '$nv'", "debug", \[caller(0)] ) if $debug > 3;

      my ($name)  = $nv =~ /$input{'regex-name'}/g;
      my ($value) = $nv =~ /$input{'regex-value'}/g;

      if (not defined $name){
        next;
      }

      if (not defined $value){
        next;
      }

      #if (defined $name and not defined $value) {
      #  debug("if (defined \$name ($name) and not defined \$value ($value))", "debug", \[caller(0)] ) if $debug > 1;
      #  $header = $name; 
      #  next NAME_VALUE;
      #}

      debug("header: '$title', name: '$name', value: '$value'", "debug", \[caller(0)] ) if $debug > 1;


      #Add title to name 
      if (defined $title and length $title > 0) {
        $title =~ s/\s{1,}$//;
        $title =~ s/^\s{1,}//;
        $title =~ s/\s{2,}//g;

        $name = "$title, $name";
      }


      if (defined $name){
        $name =~ s/\s{1,}$//;
        $name =~ s/^\s{1,}//;
        $name =~ s/\s{2,}//g;

        $name = lc $name;
      }
      else {
        $name = "";
      }

      #$name =~ s/\W/_/g;
      #$name =~ s/_{2,}/_/g;
      #$name =~ s/^_|_$//g;

      debug("name: '$name', value: '$value'", "debug", \[caller(0)] ) if $debug > 1;

      #print "Type: $type\nValue: $value\n";
      my %data = (
        "{#KEY}"  => $name,
      );
      my %value = (
        $name  => $value,
      );

      push @{$json{'data'}}, \%data;
      $json{'value'}{$name} = $value;
    }
  }

  return \%json;
}

sub run_regex_match_count {
  debug("start", "debug", \[caller(0)] ) if $debug;
  debug("Input data: ".join ", ", @_, "debug", \[caller(0)] ) if $debug;

  my %input = @_;

  #$input{'regex-match-count'}
  my $comment = $input{'comment'} || "comment missing";

  foreach my $line (split/\n/, $input{'data'}){

  }

}



