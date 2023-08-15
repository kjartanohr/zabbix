#!/usr/bin/perl



BEGIN {

  if (defined $ARGV[0] and $ARGV[0] eq "--zabbix-test-run"){
    print "ZABBIX TEST OK";
    exit;
  }


  our $config = \%main::config;

  if ($] eq "5.032000") {

    push @INC,
      "/usr/share/zabbix/bin/perl-5.32.0/",
      "/usr/share/zabbix/bin/perl-5.32.0/lib/site_perl/5.32.0/i686-linux",
      "/usr/share/zabbix/bin/perl-5.32.0/lib/site_perl/5.32.0",
      "/usr/share/zabbix/bin/perl-5.32.0/lib/5.32.0/i686-linux",
      "/usr/share/zabbix/bin/perl-5.32.0/lib/5.32.0";

  }
  elsif ($] eq "5.010001") {

    push @INC,
      "/usr/share/zabbix/bin/perl-5.10.1/lib";
  }

}

if (0 and $] eq "5.032000") {
  use warnings;
  use strict;
  use Data::Dumper;
}


#TODO. Fix this
my $debug = 0;
$debug = $main::debug if defined $main::debug;

our $debug    = 0 unless defined $debug;
our $info     = 0 unless defined $info;
our $warning  = 0 unless defined $warning;
our $error    = 0 unless defined $error;
our $fatal    = 0 unless defined $fatal;

#my $data = readfile($file, 's', 50);
#my $data = readfile($file, 'a', 50);
#my $data = readfile('filename', 'return type: s (string), a (array)', 'max file size. 10');
sub readfile {
  my $filename        = shift;
  my $return_type     = shift || "s";
  my $max_file_size   = shift || 10; #MB 
  my $chomp           = shift || 1;
  
  debug("return type: $return_type", "debug", \[caller(0)] ) if $debug > 1;

  if (-e $filename) {
    debug("File exists: $filename", "debug", \[caller(0)] ) if $debug;
  }
  else {
    debug("File does not exist: $filename", "fatal", \[caller(0)] );
    return;
  }

  if (-f $filename) {
    debug("File is a file: $filename", "debug", \[caller(0)] ) if $debug;
  }
  else {
    debug("File is not a file type. File: $filename", "fatal", \[caller(0)] );
    return;
  }

  if (-r $filename) {
    debug("File is readable. File: $filename", "debug", \[caller(0)] ) if $debug;
  }
  else {
    debug("File is not readable. File: $filename", "fatal", \[caller(0)] );
    return;
  }

  my $file_size_max = ($max_file_size*1024*1024);
  debug("Max file size is: $file_size_max byte. $max_file_size MB", "debug", \[caller(0)] ) if $debug;

  my $file_size     = -s $filename;
  debug("File size: $file_size", "debug", \[caller(0)] ) if $debug;

  if ($file_size < $file_size_max) {
    debug("File size is less than $file_size_max. File: $filename", "debug", \[caller(0)] ) if $debug;
  }
  else {
    debug("File size is more than max. file size $file_size > file size max $file_size_max. File: $filename", "fatal", \[caller(0)] );
    return;
  }


  my $file_open_status = open my $fh_r, "<", $filename;
  unless ($file_open_status) {
    debug("Could not open file '$filename'. Error: '$!'. Fatal error", "fatal", \[caller(0)] );
    return;
  }

  if ($return_type eq "s") {
    my $text = join "", <$fh_r>;
    chomp $text if $chomp;
    return $text;
  }
  elsif ($return_type eq "a") {
    my @text =  <$fh_r>;
    return @text;
  }
  else {
    debug("Unknown return type: $return_type", "fatal", \[caller(0)] );
    return;
  }
}


#    $data = run_cmd({
#      'cmd'             => $input{'command'}, 
#      'return-type'     => 's', 
#      'refresh-time'    => $input{'command-ttl'}, 
#      'timeout'         => $input{'command-timeout'}, 
#    });
=pod
my $data = run_cmd({
  'cmd'             => $input{'command'}, 
  'return-type'     => 's', 
  'vsid'            => 3, 
  'refresh-time'    => $input{'command-ttl'}, 
  'timeout'         => $input{'command-timeout'}, 
});

=cut
sub run_cmd {
  debug("start", "debug", \[caller(0)] ) if $debug > 1;
  debug("Input data: ".join ", ", @_, "debug", \[caller(0)] ) if $debug > 2;

  #TODO.
  #Add
  # timeout
  # retry
  # debug with error and fatal
  my %input;

  #Check if first in input array is an hash ref
  if (ref $_[0] and $_[0] =~ /HASH/) {
    debug("First data in array is a hash ref", "debug", \[caller(0)] ) if $debug > 2;
    %input = %{$_[0]};
    debug("Input hash: ".join ", ", %input, "debug", \[caller(0)] ) if $debug > 2;

    #$cmd                      = $input{'cmd'}             if defined $input{'cmd'};
    #$return_type              = $input{'return-type'}     if defined $input{'return-type'};
    #$refresh_time             = $input{'refresh-time'}    if defined $input{'refresh-time'};
    #$chomp                    = $input{'chomp'}           if defined $input{'chomp'};
    #$remove_space             = $input{'remove-space'}    if defined $input{'remove-space'};
  }
  else {
    #If input data is an array
    debug("First data in array is NOT a hash ref", "debug", \[caller(0)] ) if $debug > 2;
    $input{'cmd'}               = shift || undef;
    $input{'return-type'}       = shift || undef;
    $input{'refresh-time'}      = shift || undef;
    $input{'chomp'}             = shift || undef;
    $input{'remove-space'}      = shift || undef;
  }


  unless (defined $input{'cmd'} and $input{'cmd'}) {
    my $msg = "Missing input data: 'cmd'. Fatal error found";
    debug($msg, "fatal", \[caller(0)] );
    die $msg;
  }

  #Default values
  $input{'return-type'}               = "s"                     if not defined $input{'return-type'};
  $input{'refresh-time'}              = 10                      if not defined $input{'refresh-time'};
  $input{'chomp'}                     = 1                       if not defined $input{'chomp'};
  $input{'remove-space'}              = 1                       if not defined $input{'remove-space'};
  $input{'dir-cache'}                 = "/tmp/zabbix/cmd"       if not defined $input{'dir-cache'};
  $input{'dir-run'}                   = "/tmp/zabbix/cmd/tmp"   if not defined $input{'dir-run'};
  $input{'timeout'}                   = 2                       if not defined $input{'timeout'};
  $input{'background-if-timeout'}     = 1                       if not defined $input{'background-if-timeout'};
  $input{'print-last-if-timeout'}     = 1                       if not defined $input{'print-last-if-timeout'};
  $input{'include-stderr'}            = 1                       if not defined $input{'include-stderr'};
  $input{'timeout-eval'}              = 600                     if not defined $input{'timeout-eval'};
  #$input{'XXX'}         = ""       if not defined $input{'XXX'};

  create_dir($input{'dir-run'}) unless -d $input{'dir-run'};
  
  #List of source files
  my @source = qw(
    /etc/profile
    /etc/profile.d/CP.sh
    /etc/profile.d/vim.sh
    /etc/profile.d/lang.sh
    /etc/profile.d/colorgrep.sh
    /etc/profile.d/vsenv.sh
    /etc/cpshell/autoload.d/50-vsx_vip.sh
    /etc/profile.d/mdpsenv.sh

  );

  #List of different CP directories
  my @cp_dir = (
    "cpprod_util CPPROD_GetCpmDir",             #/opt/CPmds-R80.40
    "cpprod_util GetFwdirFromRegistry",         #/opt/CPsuite-R80.40/fw1
    "cpprod_util CPPROD_GetCpdi",               #/opt/CPshrd-R80.40
    "cpprod_util CPPROD_GetFwdir",              #/opt/CPsuite-R80.40/fw1
    "cpprod_util CPPROD_GetFgdir",              #/opt/CPsuite-R80.40/fg1
    "cpprod_util CPPROD_GetCpmDir",             #/opt/CPmds-R80.40
  );

  my %variable = (
    'FWIDR'       => 'echo $FWIDR',              #/opt/CPsuite-R80.30/fw1`
    'LOG'         => 'echo $FWIDR/log',          #/opt/CPsuite-R80.30/fw1/log

    'CPDIR'       => 'echo $CPDIR',              #/opt/CPshrd-R80.30
  );
  

  my $out;
  my @out;

  #Create a safe filename for the cache file
  my $cmd_file  = $input{'cmd'};
  $cmd_file     =~ s/\W/_/g;
  $cmd_file     =~ s/^_//g;

  #If VSID in input START
  if (defined $input{'vsid'}) {
    debug("\$input{'vsid'} is defined", "debug", \[caller(0)] ) if $debug > 2;

    $input{'cmd'} = format_cmd('cmd' => $input{'cmd'}, 'vsid' => $input{'vsid'});

    my $dir = "$input{'dir-cache'}/VRF_$input{'vsid'}";
    create_dir($dir) unless -d $dir;

    $cmd_file           = "/VRF_$input{'vsid'}/$cmd_file";
    debug("New cache file: $cmd_file", "debug", \[caller(0)] ) if $debug > 2;
  }
  #If VSID in input END

  #Add source files to command START
  foreach my $source (@source) {
    debug("Checking if $source exists", "debug", \[caller(0)] ) if $debug > 2;

    if (-f $source) {
      debug("$source exists. Adding to command", "debug", \[caller(0)] ) if $debug > 2;
      $input{'cmd'} = "source $source &>/dev/null ; ".$input{'cmd'};
    }
    else {
      debug("$source does not exist. Will not add to command", "debug", \[caller(0)] ) if $debug > 2;
    }
  }
  #Add source files to command END

  #Create directory if needed
  debug("create_dir() $input{'dir-cache'}", "debug", \[caller(0)] ) if $debug > 1;
  create_dir($input{'dir-cache'});

  my $file = "$input{'dir-cache'}/$cmd_file";
  debug("Command cache file: $file", "debug", \[caller(0)] ) if $debug > 1;
  debug("Command to run: $input{'cmd'}", "debug", \[caller(0)] ) if $debug > 1;

  #If the file is newer than $input{'refresh-time'}
  if (-f $file) {
    debug("File exists $file", "debug", \[caller(0)] ) if $debug > 1;

    debug("Checking if cache file TTL is still valid. time - (stat(\$file))[9]) < $input{'refresh-time'}*60 ) ", "debug", \[caller(0)] ) if $debug > 1;
    if ( (time - (stat($file))[9]) < $input{'refresh-time'}*60 ) {
      
      debug("Cache TTL is still valid", "debug", \[caller(0)] ) if $debug > 1;

      debug("opening $file", "debug", \[caller(0)] ) if $debug > 1;
      open my $fh_r, "<", $file or die "Can't open $file: $!";

      if ($input{'return-type'} eq "s") {
        debug("return type is string, s", "debug", \[caller(0)] ) if $debug > 1;
  
        foreach (<$fh_r>) {
          $out .= $_;
        }
  
        if ($input{'chomp'}) {
          debug("\$input{'chomp'} is true. chomp \$out", "debug", \[caller(0)] ) if $debug > 2;
          chomp $out;
        }
        if ($input{'remove_space'}) {
          debug("\$input{'remove_space'} is true. Removing space in the beginning and end", "debug", \[caller(0)] ) if $debug > 2;
          $out =~ s/^\s{1,}//;
          $out =~ s/\s{1,}$//;
        }

        debug("Output from command as string:\n$out\n", "debug", \[caller(0)] ) if $debug > 3;
        return $out;
      }
      elsif ($input{'return-type'} eq "a") {
        debug("return type is array, a", "debug", \[caller(0)] ) if $debug > 1;
  
        foreach (<$fh_r>) {
          push @out, $_;
        }
  
        debug("Output from command as array:\n@out\n", "debug", \[caller(0)] ) if $debug > 3;
        return @out;
      }
  
      else {
        debug("Unknown return type $input{'return-type'}", "fatal", \[caller(0)] );
      }
          
    }
  }
  #END If the file is newer than $input{'refresh-time'}
  
  my $eval_run = 1;

  my $file_lock = "$file.lock";
  debug("\$file_lock: $file_lock", "debug", \[caller(0)] ) if $debug > 1;

  if (-f $file_lock) {
    debug("Lock file $file_lock found. Checking timestamp", "debug", \[caller(0)] ) if $debug > 2;

    if (file_seconds_old("$file.lock") > $input{'timeout-eval'} ) {
      debug("Lock file $file_lock is older than \$input{'timeout-eval'} $input{'timeout-eval'}. Deleting lock file", "debug", \[caller(0)] ) if $debug > 2;
      delete_file($file_lock);
    }
    else {
      debug("Lock file $file_lock is not older than \$input{'timeout-eval'} $input{'timeout-eval'}. \$eval_run = 0", "debug", \[caller(0)] ) if $debug > 2;
      $eval_run = 0;
    }
  }

  #Eval START
  debug("eval start", "debug", \[caller(0)] ) if $debug > 1;

  if ($eval_run) {
    debug("\$eval_run is true", "debug", \[caller(0)] ) if $debug > 1;

    my %eval_data = ();
    $eval_data{'cmd'}   = $input{'cmd'};
    $eval_data{'file'}  = $file;

    my $code = <<'EOF';

    #Create lock file
    touch("$$eval_data{'file'}.lock");

    unlink "$$eval_data{'file'}.ok"   if -f "$$eval_data{'file'}.ok";
    unlink "$$eval_data{'file'}.tmp"  if -f "$$eval_data{'file'}.tmp";

    open my $fh_cmd_r, "-|", "$$eval_data{'cmd'} 2>&1" or die "Can't run $$eval_data{'cmd'}: $!\n";

    open my $fh_w, ">", "$$eval_data{'file'}.tmp" or die "Can't write to $$eval_data{'file'}.tmp: $!\n";

    while (readline $fh_cmd_r) {
      print $fh_w $_;
    }

    close $fh_w;
    close $fh_cmd_r;

    rename $$eval_data{'file'},         "$$eval_data{'file'}.old" if -f $$eval_data{'file'};
    rename "$$eval_data{'file'}.tmp",   $$eval_data{'file'}       if -f "$$eval_data{'file'}.tmp";

    if (-f $$eval_data{'file'}) {
      debug("Command cache file found: $$eval_data{'file'}. Status: OK", "debug", \[caller(0)] ) if $debug > 2;
      touch("$$eval_data{'file'}.ok");
    }
    else {
      debug("Command cache file NOT found: $$eval_data{'file'}. Status: FAILED", "fatal", \[caller(0)] );
      touch("$$eval_data{'file'}.failed");
    }

    unlink "$$eval_data{'file'}.lock"   if -f "$$eval_data{'file'}.lock";


EOF

    use POSIX 'WNOHANG';
    $SIG{CHLD} = "IGNORE";
    my $fork_pid = fork;

    unless ($fork_pid) {
      #fork code START
      debug("$$ child started", "debug", \[caller(0)] ) if $debug > 2;
      #close STDOUT;
      #close STDIN;
      #close STDERR;

      debug("run_eval() start", "debug", \[caller(0)] ) if $debug > 1;
      run_eval(
        'code'    => $code,
        'desc'    => "run_cmd() run command",
        'timeout' => $input{'timeout-eval'},
        'data'    => \%eval_data,
      );
      debug("run_eval() end", "debug", \[caller(0)] ) if $debug > 1;

      debug("Data returned from child: ".join ", ", %eval_data, "debug", \[caller(0)] ) if $debug > 3;
      exit;
      #fork code END
    }

    #Parent code
    
    #Wait for child to exit START
    debug("Parent: waiting for child ($fork_pid) to exit", "debug", \[caller(0)] ) if $debug > 2;

    my $fork_time     = time;
    my $fork_timeout  = 0; 

    FORK_WAIT:
    while (waitpid($fork_pid, WNOHANG) == 0) {

      if ( (time - $fork_time) > $input{'timeout'}) {
        debug("Parent: Timeout waiting for child to exit", "debug", \[caller(0)] ) if $debug > 2;
        $fork_timeout = 1;    
        last FORK_WAIT;
      }

      debug("Parent: Still waiting for child ($fork_pid) to exit", "debug", \[caller(0)] ) if $debug > 2;
      sleep 1;
    }

    debug("Parent: done waiting for child ($fork_pid) to exit", "debug", \[caller(0)] ) if $debug > 2;

    if ($fork_timeout == 0) {
      debug("Child did not time out", "debug", \[caller(0)] ) if $debug > 2;

      if (defined $eval_data{'error'} and $eval_data{'error'} =~ /alarm/) {
        debug("Error found in run_eval(). Eval timeout.  Error: '$eval_data{'error'}'", "fatal", \[caller(0)] );
        die $eval_data{'error'};
      }

      if (defined $eval_data{'error'}) {
        debug("Error found in run_eval(). die. Error: '$eval_data{'error'}'", "fatal", \[caller(0)] );
        die $eval_data{'error'};
        
      }
      #print $eval_data{'out'};
      debug("Data returned from child: ".join ", ", %eval_data, "debug", \[caller(0)] ) if $debug > 3;
    }

    if ($fork_timeout == 1) {
      debug("Child timed out. Will continue without waiting for child to exit", "debug", \[caller(0)] ) if $debug > 2;
    }

  }
  #Eval END

  if ($input{'print-last-if-timeout'} == 0) {
    debug("\$input{'print-last-if-timeout'} is false. No data returned. return", "debug", \[caller(0)] ) if $debug > 2;
    return;
  }

  debug("open $file", "debug", \[caller(0)] ) if $debug > 1;
  open my $fh_r, "<", $file or die "Can't open $file: $!\n";
  
  if ($input{'return-type'} eq "s") {
    debug("return type is string, s", "debug", \[caller(0)] ) if $debug > 1;

    while (readline $fh_r) {
      $out .= $_;
    }

    debug("Output from command as string:\n$out\n", "debug", \[caller(0)] ) if $debug > 3;
    return $out;
  }
  elsif ($input{'return-type'} eq "a") {
    debug("return type is array, a", "debug", \[caller(0)] ) if $debug > 1;

    foreach (<$fh_r>) {
      push @out, $_;
    }

    debug("Output from command as array:\n@out\n", "debug", \[caller(0)] ) if $debug > 3;
    return @out;
  }

  else {
    debug("Unknown return type $input{'return-type'}", "fatal", \[caller(0)] );
  }
}


sub run_cmd_old {
  my $cmd         = shift || die "Need a command to run\n";
  my $return_type = shift || "s";
  my $out;
  my @out;

  debug("Command to run: \"$cmd\"\n");

  if ($return_type eq "s") {
    $out = `$cmd 2>&1`;
    debug("Output from command as string:\n$out\n");
    return $out;
  }
  elsif ($return_type eq "a") {
    @out =  `$cmd 2>&1`;
    debug("Output from command as array:\n@out\n");
    return @out;
  }
  else {
    debug("Unknown return type $return_type\n");
  }
}

=pod

trunk_file_if_bigger_than_mb($file, 10); #trunc file if file size is bigger than N

=cut
sub trunk_file_if_bigger_than_mb {
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  my $file    = shift || die "Need a filename to check file size for";
  my $size    = shift || 10;

  debug("Input. file: $file, size: $size MB", "debug", \[caller(0)] ) if $debug > 1;

  unless (-f $file) {
    debug("Could not find $file. Returning", "debug", \[caller(0)] ) if $debug > 1;
    return;
  }

  my $size_mb = ($size*1024*1024);
  debug("$file is $size_mb MB", "debug", \[caller(0)] ) if $debug > 1;

  debug("Checking if $file is bigger than size_mb MB", "debug", \[caller(0)] ) if $debug > 1;

  if (-s $file > ($size*1024*1024) ) {
    debug("$file is bigger than $size. touch()", "debug", \[caller(0)] ) if $debug > 1;
    touch($file);
  }

}

sub delete_file_if_bigger_than_mb {
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  my $file    = shift || die "Need a filename to check file size for";
  my $size    = shift || 10;

  debug("Input. file: $file, size: $size MB", "debug", \[caller(0)] ) if $debug > 1;

  unless (-f $file) {
    debug("Could not find $file. Returning", "debug", \[caller(0)] ) if $debug > 1;
    return;
  }

  my $size_mb = ($size*1024*1024);
  debug("$file is $size_mb MB", "debug", \[caller(0)] ) if $debug > 1;

  debug("Checking if $file is bigger than size_mb MB", "debug", \[caller(0)] ) if $debug > 1;

  if (-s $file > ($size*1024*1024) ) {
    debug("$file is bigger than $size. Deleting", "debug", \[caller(0)] ) if $debug > 1;
    delete_file('file' => $file, 'print-error' => 1);
  }
}



#debug("", "debug", \[caller(0)] ) if $debug;
#debug("", "info", \[caller(0)] )  if $debug;
#debug("", "error", \[caller(0)] ) if $error;
#debug("", "error", \[caller(0)] );
#debug("", "fatal", \[caller(0)] );

#debug level
# 1 - big picture debug. Around 10-20 lines of debug
# 2 - what sub is startet, results of if statements
# 3 - data sent and data returned. Changes to data
# 4 - print input and output data from sub
# 5 - print lines in loops. foreach array. Line: $line
# 6 - print input data from files and larger data. A script that runs for <1 sec will not take seconds
# 9 - print every step and all the data

sub debug_v1 {
  my $date      = get_date_time();
  my $text      = shift || "No text given to debug";

  $text .= "$date DBGv1 $text\n";

  if ($main::debug and defined $main::file_debug and $main::file_debug) {
    open my $fh_db_w, ">>","$main::file_debug" or die "Can't write to $main::file_debug: $!\n";
    print $fh_db_w $text;
  }

  print $text if $main::debug;
}

sub debug {

  our $debug_depth  = 1     unless defined $debug_depth;
  our $debug_msg    = $_[0] unless defined $debug_msg;

  if ($main::debug == 0) {
    return;
  }

  if (defined $main::debug) {
    $debug = $main::debug;
  }

  if ($debug > 8) {
    print "sub debug(). start\n";
    print "sub debug(). Input data: ".join( ", ", @_)."\n";
    #print join ", ", @{$$_[-1]} if defined $_[-1] and ref $_[-1];
    #print "\n";
    print "Debug depth: '$debug_depth', debug last msg: $debug_msg\n";  
  }

  #$main::debug_depth  = 1     unless defined $main::debug_depth;
  #$main::debug_msg    = $_[0] unless defined $main::debug_msg;
  #$main::debug_depth++ if $main::debug_msg eq $_[0];


  if ($debug_msg eq $_[0]) {
    print "debug msg is the same as the last debug message. \$debug_depth++\n" if $debug > 8;
    $debug_depth++ 
  }
  else {
    print "debug msg is not the same as the last debug message. \$debug_depth = 0\n" if $debug > 8;
    $debug_depth = 0;
  }

  if ($debug_depth > 8) {
    print "debug loop found. depth count: '$debug_depth' msg: '$debug_msg'. return\n" if $debug;
    return;
  }


  #Check for debug V2 
  if (ref $_[-1] ) {
    print "This is debug version 2. Hash ref found in input array -1\n" if $debug > 8;
    debug_v2(@_);
  }  
  else {
    print "This is debug version 1. No hash ref found in input array -1\n" if $debug > 8;
    debug_v1(@_);
  }
}

#debug("No data from readline", "debug", "ttl", "filesystem",\[caller(0)]);
#debug("ERROR MSG", "DEBUG TYPE 1", "DEBUG TYPE 1" );
sub debug_v2 {
  print "sub debug_v2(). start\n" if $debug > 8;

  my $msg   = shift || "No message";
  my $pre = "";
  my @type;

  my $date      = get_date_time();

  $debug = $main::debug if defined $main::debug;

  my %config;

  if (%main::config) {
    print "%main::config found. %config = %main::config\n" if $debug > 8;
    %config = %main::config;
  }

  unless (%config) {
    print "%main::config not found. %config = get_config()\n" if $debug > 8;
    %config = get_config('no-debug' => 1) 
  }

  if (ref $_[0]) {
    print "Missing input type. Setting to debug: $msg @_\n";
    push @type, "debug";
  }

  if ($_[0]) {
    print "Adding '$_[0]' to \@type\n" if $debug > 8;
    push @type, shift;
  }
  else {
    print "Missing input type. Setting to debug: $msg @_\n" if $debug;
    push @type, "debug";
  }

  #Check for caller at the end of array START
  if (ref $_[-1] ) {
    print "Found ref in the end of input\n" if $config{'log'}{'all'}{'enabled'} and $config{'log'}{'all'}{'print'} or $debug > 8;

    my $caller_ref = pop @_;
    #print Dumper $$caller_ref;
    
    if ($$caller_ref) {
      #my ($package, $filename, $line) = @{$$caller_ref};
      my ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash) = @{$$caller_ref};
      $filename     ||= "";
      $subroutine   ||= "";
      $line         ||= "";

      $filename =~ s/.*\///       if $filename;    #Remove path to file
      $filename =~ s/\.\///       if $filename;    #Remove path to file
      $subroutine =~ s/main:://   if $subroutine;

      $package = "" if defined $package and $package eq $filename;

      #push @type, $package if $package;
      $pre .= "$filename, "     if $filename;
      $pre .= "$subroutine, "   if $subroutine;
      $pre .= "$line, "         if $line;
      #$pre .= "$filename, $subroutine, $line:";
    }

  }
  #Check for caller at the end of array END
  
  #Get all the log types
  #print "Adding \@_ @_ to \@type @type\n";
  if (@_) {
    print "push \@type, '@_'\n" if $debug > 8;
    push @type, @_;
  }

  #Check log all START
  #if ($config{'log'}{'all'}{'enabled'}) {
  #  push @type, "all";
  #}
  #Check log all END

  #Remove new line
  chomp $msg;

  #Loop for all the log types START
  TYPE:
  foreach my $type (@type) {
    print "foreach \@type: '$type'\n" if $debug > 8;

    $type =~ s/ /_/g;
    $type =~ s/_{2,}/_/g;

    my $message = "$date $pre $type:\t\"$msg\"\n";
    print "Message: $message\n" if $debug > 8;

    #Set default file if not set
    #$config{'log'}{'default'}{'file'} = $main::file_debug if not defined $config{'log'}{'default'}{'file'} and defined $main::file_debug;
    print "log default file: $config{'log'}{'default'}{'file'}\n" if $debug > 8;

    #Check config for type START
    #if (not defined $config{'log'}{$type} and $config{'log'}{'error'}{'enabled'}) {
    if (not defined $config{'log'}{$type}) {

      #Use default
      $config{'log'}{$type} = $config{'log'}{'default'};
      
    }
    #Check config for type END



    #Log to file START
    if (defined $config{'log'}{$type}{'log'} and $config{'log'}{$type}{'file'}) {
      #print "Found \$config{'log'}{$type}{'log'}: $config{'log'}{$type}{'log'} and \$config{'log'}{$type}{'file'}: $config{'log'}{$type}{'file'})\n" if $config{'log'}{'all'}{'enabled'} and $config{'log'}{'all'}{'print'};

      my $max_file_size = $config{'log'}{$type}{'file-size'} || $config{'log'}{'default'}{'file-size'} || 10;
      $max_file_size *= 1024*1024;

      write_to_file(
        'file'            => $config{'log'}{$type}{'file'},
        'type'            => 'append',                                              #appen/overwrite
        'message'         => $message,                                              #Message to save
        'fatal'           => 0,                                                     #0/1. 0 = die if writing failed. 1 = return error message if error writing
        'max_file_size'   => $max_file_size,                                        #Byte. Max file size
        'debug-disabled'  => 1,                                                     #Stop debug loop. Disable debug messages.
      );
    }
    #Log to file START
    
    #print message START
    if (defined $config{'log'}{$type}{'print'} and $config{'log'}{$type}{'print'}) {
      print $message;
    }
    #print message END
    
    #print message START
    if (defined $config{'log'}{$type}{'print-warn'} and $config{'log'}{$type}{'print-warn'}) {
      warn $message;
    }
    #print message END

    #die START
    if (defined $config{'log'}{$type}{'die'} and $config{'log'}{$type}{'die'}) {
      ctrl_c();
    }
    #die END
    

  }
  #Loop for all the log types END
}


#TODO
# replace this with the correct sub
# 2022.02.15
sub write_to_file {
  #debug("main", "Start", "debug",\[caller(0)] );

  my %input = @_;

  $input{'type'}            ||= "append";
  $input{'fatal'}           ||= 0;
  $input{'max_file_size'}   ||= 10*1024*1024; #10 MB
  $input{'debug-disabled'}  ||= 0;

  unless ($input{'file'}) {
    debug("Missing input file. Return 0", "fatal",\[caller(0)]) if $input{'debug-disabled'} == 0;
    #warn("Missing input file. Return 0", "fatal",\[caller(0)]) if $input{'debug-disabled'} == 1;
    return 0;
  }
  else {
    debug("Input file: $input{'file'}", "debug",\[caller(0)]) if $input{'debug-disabled'} == 0;
    #warn("Input file: $input{'file'}", "debug",\[caller(0)]) if $input{'debug-disabled'} == 1;
  }

  unless ($input{'message'} =~ /\n$/) {
    debug("Missing message", "fatal",\[caller(0)]) if $input{'debug-disabled'} == 0;
    #warn("Missing message", "fatal",\[caller(0)]) if $input{'debug-disabled'} == 1;
    return 0;
  }
  else {
    debug("Adding new line to message: $input{'message'}", "debug",\[caller(0)]) if $input{'debug-disabled'} == 0;
    #warn("Adding new line to message: $input{'message'}", "debug",\[caller(0)]) if $input{'debug-disabled'} == 1;
  }

  #Check if log file is too big
  if (-f $input{'file'} and $input{'max_file_size'} and -s $input{'file'} > $input{'max_file_size'}) {
    debug("File is bigger than $input{'max_file_size'} ", "debug",\[caller(0)]) if $input{'debug-disabled'} == 0;
    #warn("File is bigger than $input{'max_file_size'} ", "debug",\[caller(0)]) if $input{'debug-disabled'} == 0;
    unlink $input{'file'};
  }

  my $open_status = open my $fh_w, ">>", $input{'file'};
  if ($open_status) {
    debug("Opening $input{'file'} OK", "debug",\[caller(0)] ) if $input{'debug-disabled'} == 0;
    #warn("Opening $input{'file'} OK", "debug",\[caller(0)] ) if $input{'debug-disabled'} == 1;

    print $fh_w $input{'message'};
    close $fh_w;
    return 1;
  }
  else {
    my $die_message = "Can't write to $input{'file'}: $!";

    debug("open file status", $die_message, "fatal",\[caller(0)]) if $input{'debug-disabled'} == 0;
    #warn("open file status", $die_message, "fatal",\[caller(0)]) if $input{'debug-disabled'} == 1;

    if ($input{'fatal'}) {
      die $die_message;
    }
    return 0;
  }
}



sub error {
  my $text = shift || "No text given to debug";
  $text .= "\n";

  my $dir_tmp = "/tmp/zabbix/log";

  my $file_error;
  $file_error = $main::file_error if defined $main::file_error;
  $file_error = "$dir_tmp/error.log" unless defined $file_error;

  create_dir($dir_tmp) unless -d $dir_tmp;

  open my $fh_db_w, ">>",$file_error or die "Can't write to $file_error: $!\n";
  print $fh_db_w $text;
  close $fh_db_w;

  warn $text if $debug;
}

sub create_dir {
  debug("start", "debug", \[caller(0)] ) if $debug > 2;

  my $name = shift || die "Need a directory name to create\n";
  debug("Input directory name: $name", "debug", \[caller(0)] ) if $debug > 2;

  my $out;

  if (-d $name){
    debug("$name directory exists. No need to create", "debug", \[caller(0)] ) if $debug > 2;
  }
  else {
    $out = `mkdir -p $name 2>&1`;
    debug("$name directory missing. Creating. Out: $out", "debug", \[caller(0)] ) if $debug > 2;
  }

  unless (-d $name) {
    debug("Could not create $name: $out", "fatal", \[caller(0)] ) if $main::fatal;
  }
}

sub arping {
  my $int = shift;
  my $mac = shift;
  my $ip  = shift;

  my $cmd = "arping -f -w 3 -c 3 -I $int $ip";
  print $cmd if $debug;

  my $out = run_cmd($cmd);
  print $out if $debug;

  my ($found)     = $out =~ /reply from /;
  unless ($found) {
    print "MAC not found, return $int $mac $ip\n" if $debug;
    return
  }

  my ($mac_found) = $out =~ /$ip.*$mac/i;

  print "MAC found, return 1  $int $mac $ip\n" if $debug;

  return 1 if $mac_found;
}

sub get_all_vs_id {
  my @return;

  push @return,0;

  foreach (run_cmd("vsx stat -v 2>/dev/null", "a")){
    s/^\s*`?//;
    next unless /^\d/;
    my @split = split/\s{1,}/;

    next unless $split[2] eq "S";

    push @return,$split[0];
  }

  return @return;
}

sub get_all_vs {
  debug(((caller(0))[3])." Start\n");

  my %return;

  my $hostname = get_hostname();
  debug(((caller(0))[3])." Using output form command hostname as VS0 name: $hostname\n");

  $return{0} = $hostname;

  debug(((caller(0))[3])." Checking if this is a VSX GW\n");
  my $cmd_vsx_state = "cpprod_util FwIsVSX";
  my $vsx_state     = run_cmd($cmd_vsx_state, 's', 10);
  chomp $vsx_state;

  debug(((caller(0))[3])." Result from $cmd_vsx_state: \"$vsx_state\"\n");



  if ($vsx_state == 1) {
    debug(((caller(0))[3])." This is a VSX GW\n");
  }
  else {
    debug(((caller(0))[3])." This is not a VSX GW. Will return with VS 0\n");
    return %return;
  }

  debug(((caller(0))[3])." Running vsx stat -v\n");
  foreach (run_cmd("vsx stat -v", "a", 600)){
    s/^\s*`?//;
    next unless /^\d/;
    s/\|//g;

    #9  S NAVN            Standard                4Jan2021 10:43  Standard                  Trust
    my @split = split/\s{1,}/;

    next unless $split[1] eq "S";

    $return{$split[0]} = $split[2];
  }

  return %return;
}

sub get_vsname {
  my $vsid = shift;

  return get_hostname() if $vsid == 0;

  die "No VSID given" unless defined $vsid;

  my $vsx_out = run_cmd("vsx stat -v", 's', 1*24*60);

  my ($vsname) = $vsx_out =~ / $vsid \| . (.*?) /;

  return $vsname;

}

=pod
#Get VS info
my %vs = get_vs_detailed('type' => 'S');
unless (%vs) {
  debug("No data from get_vs_detailed(). Something is wrong", "fatal", \((caller(0))[3]) );
  die "No data from get_vs_detailed(). Something is wrong. Fatal error";
}

foreach my $vs_key (keys %vs) {
  debug("key: '$vs_key'. Value: '$vs{$vs_key}'", "debug", \[caller(0)] ) if $debug;

  my $id                = $vs{$vs_key}{'id'};·
  my $name              = $vs{$vs_key}{'name'};·
  my $type              = $vs{$vs_key}{'type'};·
  my $access_policy     = $vs{$vs_key}{'access_policy'};·
  my $threat_policy     = $vs{$vs_key}{'threat_policy'};·
  my $installed_policy  = $vs{$vs_key}{'installed_policy'};·
  my $sic               = $vs{$vs_key}{'sic'};·

  my $host_name         = $vs{$vs_key}{'host_name'};·
  my $host_ip           = $vs{$vs_key}{'host_ip'};·
  my $host_int          = $vs{$vs_key}{'host_int'};·

  my $vs_ip             = $vs{$vs_key}{'vs_ip'};·
  my $vs_int            = $vs{$vs_key}{'vs_int'};·
}

=cut

sub get_vs_detailed {
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  my %input = @_;

  $input{'type'} = "S" unless defined $input{'type'};


  unless (defined $input{'type'}) {
    debug("Missing input data 'cmd'", "fatal", \[caller(0)] );
    exit;
  }


  my %return;

  my $hostname = get_hostname();
  unless ($hostname) {
    debug("Could not get hostname. Something is wrong. Setting hostname to 'no name found'", "error", \((caller(0))[3]) );
    $hostname = 'no name found';
  }

  debug(((caller(0))[3])." Using output from command hostname as VS0 name: $hostname\n") if $debug;

  #Check if fw is vsx START
  debug(((caller(0))[3])." Checking if this is a VSX GW\n") if $debug;

  if (is_vsx()) {
    debug(((caller(0))[3])." This is a VSX GW\n") if $debug;
  }
  #else {
  #  debug(((caller(0))[3])." This is not a VSX GW. Will return with VS 0\n") if $debug;
  #  return %return;
  #}
  #Check if fw is vsx END
  
  #Get the host default gateway interface ip-address
  my $host_int  = get_dfg_int();
  my $host_ip   = get_int_ip('int' => $host_int);

  debug(((caller(0))[3])." Running vsx stat -v\n") if $debug;

  #vsx stat -v R80.10
=pod
[Expert@host:0]# fw ver
This is Check Point's software version R80.10 - Build 236
[Expert@host-1:0]#

[Expert@host:0]# vsx stat -v
VSX Gateway Status
==================
Name:            hostname
Access Control Policy: Standard
Installed at:    10Dec2021  5:26:32
Threat Prevention Policy: Standard
SIC Status:      Trust

Number of Virtual Systems allowed by license:          10
Virtual Systems [active / configured]:                 10 / 10
Virtual Routers and Switches [active / configured]:     4 / 4
Total connections [current / limit]:                25445 / 1502500

Virtual Devices Status
======================

 ID  | Type & Name             | Access Control Policy | Installed at    | Threat Prevention Policy | SIC Stat
-----+-------------------------+-----------------------+-----------------+--------------------------+---------
   1 | W sw1-ext               | <Not Applicable>      |                 | <Not Applicable>         | Trust
   2 | W sw1-fwbackbone        | <Not Applicable>      |                 | <Not Applicable>         | Trust
   3 | S fw1-userext           | Standard              | 29Dec2021 11:28 | Standard                 | Trust
   4 | W sw1-uservpn           | <Not Applicable>      |                 | <Not Applicable>         | Trust
   5 | S fw1-vpn               | Standard              | 16Dec2021 10:15 | <No Policy>              | Trust
   6 | S fw1-guest             | Standard              | 10Dec2021  5:27 | Standard                 | Trust
   7 | S fw1-sumoplayout       | Standard              | 10Dec2021  5:27 | <No Policy>              | Trust
   8 | S fw1-serverext         | Standard              | 15Dec2021 12:13 | Standard                 | Trust
   9 | S fw1-lab               | Standard              | 10Dec2021  5:27 | <No Policy>              | Trust
  10 | S fw1-dmz2              | Standard              | 27Dec2021 13:03 | <No Policy>              | Trust
  12 | W sw1-ext-2             | <Not Applicable>      |                 | <Not Applicable>         | Trust
  13 | S fw1-dmz1              | Standard              | 27Dec2021 13:03 | Standard                 | Trust
  14 | S fw1-dmz3              | Standard              |  4Jan2022  9:11 | <No Policy>              | Trust
  15 | S fw1-hosting           | Hosting               | 27Dec2021 13:00 | Hosting                  | Trust

Type: S - Virtual System, B - Virtual System in Bridge mode,
      R - Virtual Router, W - Virtual Switch.

[Expert@tv2-cp-fw1-1:0]#
=cut

  my %data;

  foreach (run_cmd("vsx stat -v","a", 1*24*60)){
    chomp;                #Remove new line
    s/^\s*`?//;           #Remove white space from start of the line
    next unless /^\d/;    #Next line unless is starts with a digit
    #s/\|//g;

    #9  S NAVN            Standard                4Jan2021 10:43  Standard                  Trust
    ($data{'id'}, $data{'type_name'}, $data{'access_policy'}, $data{'installed'}, $data{'threat_policy'}, $data{'sic'}) = split/\s{0,}\|\s{0,}/;  #Split on |

    #Split type and name
    ($data{'type'}, $data{'name'}) =  split/\s{1,}/, $data{'type_name'};


    #Remove random space and tabs
    debug("foreach data. Remove space and tab", "debug", \[caller(0)] ) if $debug;
    foreach my $key (keys %data) {
      
      unless ($data{$key} and $data{$key}) {
        debug("No data found in key $key. next", "debug", \[caller(0)] ) if $debug;
        next;
      }
      debug("Key: '$key'. Data: '$data{$key}'", "debug", \[caller(0)] ) if $debug;

      $data{$key} =~ s/\t//g;       #Remove tab
      $data{$key} =~ s/\s{2,}/ /g;  #Remove 2 or more space and replace with 1 space

      $data{$key} =~ s/^\s{1,}//g;  #Remove space from the beginning
      $data{$key} =~ s/\s{1,}$//g;  #Remove space from the end

    }

    my @validate_data = qw(id type name access_policy threat_policy sic);
    foreach my $key (@validate_data) {
      
      #Verify the output data START
      if (defined $data{$key} and $data{$key}) {
        debug("Key '$key' found and has data. Data: '$data{$key}'", "debug", \[caller(0)] ) if $debug;
      }
      else {
        debug("Key '$key' found but has no data. Fatal error found", "fatal", \[caller(0)] );
        next;
      }
      #Verify the output data END
    }
    
    #Data health check
    if ($data{'sic'} ne "Trust") {
      debug("Sic is not 'Trust'. Sic: '$data{'sic'}'. Fatal error found", "warning", \[caller(0)] );
    }

    #TODO. 
    #Validate id as digit ... 
    
    #Check VS type
    if ($input{'type'} eq $data{'type'}) {
      debug("VS type is $input{'type'}. OK", "debug", \[caller(0)] ) if $debug > 1;
    }
    else {
      debug("VS type is not $input{'type'}. next", "debug", \[caller(0)] ) if $debug > 1;
      next;
    }

    #Get the VS default gateway interface ip-address
    my $vs_int  = "";
    my $vs_ip   = "";

    $vs_int  = get_dfg_int('vsid' => $data{'id'});
    $vs_ip   = get_int_ip('vsid' => $data{'id'}, 'int' => $vs_int) if $vs_int;
    
    #Set defaults 
    $data{'installed'} ||= "no install time";

    #Build the return hash with data
    $return{$data{'id'}} = {
      'id'                => $data{'id'},
      'type'              => $data{'type'},
      'name'              => $data{'name'},
      'access_policy'     => $data{'access_policy'},
      'threat_policy'     => $data{'threat_policy'},
      'policy_installed'  => $data{'installed'},
      'sic'               => $data{'sic'},

      'host_name'         => $hostname,
      'host_ip'           => $host_ip,
      'host_int'          => $host_int,

      'vs_ip'             => $vs_ip,
      'vs_int'            => $vs_int,
    };
  }

  #Add VS 0 to the data
  #TODO. Get all the data from other commands
  $return{0} = {
    'id'                => 0,
    'type'              => 'S',
    'name'              => $hostname,
    'access_policy'     => '',
    'threat_policy'     => '',
    'policy_installed'  => '',
    'sic'               => '',

    'host_ip'           => $host_ip,
    'host_int'          => $host_int,

    'vs_ip'             => $host_ip,
    'vs_int'            => $host_int,

  };


  #Return the hash with data
  debug("end", "debug", \[caller(0)] ) if $debug;
  return %return;
}

sub get_resolv_search {
  debug("start", "debug", \[caller(0)] ) if $debug;

  my $file_resolv = "/etc/resolv.conf";
  debug("File: $file_resolv", "debug", \[caller(0)] ) if $debug;

  my $data = readfile($file_resolv, 's', 1);
  if (defined $data and $data) {
    debug("Data from readfile(): $data", "debug", \[caller(0)] ) if $debug;
  }
  else {
    debug("No data from readfile(). Something is wrong. Fatal error", "fatal", \[caller(0)] );
    return;
  }


  my ($search) = $data =~ /search\s{1,}(.*?)\s{1,}/; 

  if ($search) {
    debug("search data found in $file_resolv: $search", "debug", \[caller(0)] ) if $debug;
  }
  else {
    debug("search data not found in $file_resolv. Something is wrong", "fatal", \[caller(0)] );
    return;
  }

  debug("end", "debug", \[caller(0)] ) if $debug;
  return $search;

}



sub check_if_other_self_is_running {
  debug("start", "debug", \[caller(0)] ) if $debug > 1;
  debug("Input data: ".join ", ", @_, "debug", \[caller(0)] ) if $debug > 1;

  my $name  = shift;
  my $pid   = shift;

  #Validate input data file
  unless (defined $name and $name) {
    debug("Missing input data for file. return", "fatal", \[caller(0)] );
    return;
  }
  
  #Validate input data pid
  unless (defined $pid and $pid) {
    debug("Missing input data for pid. return", "fatal", \[caller(0)] );
    return;
  }

  my $count = 0;

  debug("run_cmd() start", "debug", \[caller(0)] ) if $debug > 1;
  my @ps_out = run_cmd({
    "cmd"             => 'ps xau',
    'return-type'     => 'a',
    'refresh-time'    => 1,
    'timeout'         => 5,
    'timeout-eval'    => 10,
    'include-stderr'  => 0,
  });
  debug("run_cmd() end", "debug", \[caller(0)] ) if $debug > 1;

  debug("foreach \@ps_out", "debug", \[caller(0)] ) if $debug > 1;
  foreach (@ps_out){

    next unless /$name/;
    debug("Regex match found: $_ =~ /$name/", "debug", \[caller(0)] ) if $debug > 1;

    my @s = split/\s{1,}/;
    debug("Checking if PID from ps is our ($$) or parent PID ($pid)", "debug", \[caller(0)] ) if $debug > 1;

    debug("'$s[1]' == '$$'", "debug", \[caller(0)] ) if $debug > 1;
    next if $s[1] == $$;

    debug("'$s[1]' == '$pid'", "debug", \[caller(0)] ) if $debug > 1;
    next if $s[1] == $pid;

    debug("Found other process running. Name: '$name'. Line: '$_'", "debug", \[caller(0)] ) if $debug > 1;

    $count++;
  }

  debug("end", "debug", \[caller(0)] ) if $debug;
  return 1 if $count;
  return;
}

sub cpu_count {
  my $cpu_count;

  foreach (`cat /proc/cpuinfo`){
    next unless /^$/;
    $cpu_count++;
  }
  return $cpu_count;
}

sub is_gw {
  my $out = run_cmd("fw stat");

  return 1 if $out =~ /POLICY/;
}

sub get_file_size {
  my $file = shift;

  my ($size) = (stat($file))[7];

  unless (defined $size) {
    print "Could not find the file to get file size $file";
    exit;
  }

  return $size;

}

sub ping_ip {
  my $ip    = shift || die "need a IP to ping";
  my $vsid  = shift || 0;
  my $retry = shift || 1;

  print "sub ping_ip: input $ip\n" if $debug;

  foreach (1 .. $retry) {
    my $out = run_cmd("source /etc/profile.d/vsenv.sh; vsenv $vsid &>/dev/null ;  ping -c 1 -w 1 $ip", "s", 60);

    return 1 if $out =~ / 0% packet loss/;
  }

  return 0;
}

sub zabbix_check {
  my $argv = shift || return;

  if ($argv eq "--zabbix-test-run"){
    print "ZABBIX TEST OK";
    exit;
  }
}

sub get_mgmt_ip {
  my $vsid  = shift;
  $vsid     = $main::vsid if not defined $vsid and defined $main::vsid;
  $vsid     = 0           if not defined $vsid;

  my $cmd = "source /etc/bashrc; source /etc/profile.d/vsenv.sh; vsenv $vsid &>/dev/null ; echo -n \$CPDIR/registry/HKLM_registry.data";
  print "sub get_mgmt_ip: CMD: \"$cmd\"\n" if $debug;

  my $filename = `$cmd`;
  print "sub get_mgmt_ip: CMD output: \"$filename\"\n" if $debug;

  open my $fh_r,"<", $filename || die "Can't open $filename: $!";
  while (<$fh_r>) {
    next unless /ICAip /;
    my ($ip) = /ICAip \((.*?)\)/;
    print "Found MGMT IP $ip\n" if $debug;

    return $ip;
  }
}

sub touch {
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  my $filename = shift || die "Can't touch file with no filename given\n";
  debug("input filename: $filename", "debug", \[caller(0)] ) if $debug > 1;

  debug("open > $filename", "debug", \[caller(0)] ) if $debug > 1;
  open my $fh,">", $filename or die "Can't create file $filename: $!\n";
  close $fh;
}

sub file_days_old {
  my $filename = shift || die "Check how old the file is with no filename\n";

  die "Can't check how old the file is. No such file found: $filename\n" unless -f $filename;

  my $filename_mtime = (stat($filename))[9];

  my $seconds_old = (time - $filename_mtime);
  my $hours_old   = ($seconds_old/60/60);
  my $days_old    = ($seconds_old/24);

  return $days_old;
}

sub file_hours_old {
  my $filename = shift || die "Check how old the file is with no filename\n";

  die "Can't check how old the file is. No such file found: $filename\n" unless -f $filename;

  my $filename_mtime = (stat($filename))[9];

  my $seconds_old = (time - $filename_mtime);
  my $hours_old   = ($seconds_old/60/60);

  return $hours_old;

}
sub file_seconds_old {
  my $filename = shift || die "Check how old the file is with no filename\n";

  die "Can't check how old the file is. No such file found: $filename\n" unless -f $filename;

  my $filename_mtime = (stat($filename))[9];

  my $seconds_old = (time - $filename_mtime);

  return $seconds_old;

}

sub get_log_ip {
  my $vsid  = shift;
  $vsid     = $main::vsid if not defined $vsid and defined $main::vsid;
  $vsid     = 0           if not defined $vsid;

  my $cmd = "source /etc/bashrc; source /etc/profile.d/vsenv.sh; vsenv $vsid &>/dev/null ; cpstat fw -f log_connection 2>&1";
  print "sub get_log_ip: CMD: \"$cmd\"\n" if $debug;

  my $out = run_cmd($cmd);
  print "sub get_log_ip: CMD output: \"$out\"\n" if $debug;

  foreach (split /\n/, $out) {
    next unless /\|\d/;
    my @split = split/\|/;
    return $split[1];

  }
}

sub get_hklm_directory {
  my $search  = "HKLM_registry.data";
  my %dir     = ();

  foreach (run_cmd("find /var/opt/ -name '$search' 2>/dev/null", "a")){
    chomp;

    my ($dir) = m#(.*)/#;
    next unless -d $dir;

    $dir{$dir} = 1;
  }

  return keys %dir;

}

sub df {
  my $partition   = shift || die "sub df: Need a partition to check\n";
  my $return_data = shift || die "sub df: Need input on what data you want in return\n";
  my $return_type = shift || "";


  foreach (run_cmd("df -P $partition", "a", 600)) {
    next unless /$partition/; #Skip header

    my ($filesystem, $blocks, $used, $available, $percent_use, $mount) = split /\s{1,}/;

    $used      = ($used*1024);
    $available = ($available*1024);

    if ($return_type) {
      $used      = human_readable_byte($used,      "$return_type");
      $available = human_readable_byte($available, "$return_type");
    }

    return $filesystem   if $return_data eq "filesystem";
    return $blocks       if $return_data eq "blocks";
    return $used         if $return_data eq "used";
    return $available    if $return_data eq "available";
    return $percent_use  if $return_data eq "percent_use";
    return $mount        if $return_data eq "mount";

    return;
  }
}

sub human_readable_byte {
  my $byte = shift || die "sub human_readable: Need bytes to convert\n";
  my $type = shift || die "sub human_readable: Need a type to convert size into\n";

  return ($byte/1024) if $type eq "KB";
  return ($byte/ (1024**2) ) if $type eq "MB";
  return ($byte/ (1024**3) ) if $type eq "GB";
  return ($byte/ (1024**4) ) if $type eq "TB";
  return ($byte/ (1024**5) ) if $type eq "PB";
  return ($byte/ (1024**6) ) if $type eq "EB";

  return 0;
}

sub get_hostname {
  #my $hostname = `hostname 2>/dev/null`; 
  #chomp $hostname; 

  my $hostname = run_cmd('hostname', 's', 6000);
  
  if ($hostname) {
    return $hostname
  }
  else {
    warn "Could not get hostname\n";
    return;
  }
}

sub get_cpu_usage_process {
  debug("start", "debug", \[caller(0)] ) if $debug;
  debug("Input data: ".join ", ", @_, "debug", \[caller(0)] ) if $debug;

  my $name = shift || die "Need a process name to get CPU usage from\n";

  my $cmd_cpu = qq#/usr/share/zabbix/repo/scripts/auto/top_collector_get_max_cpu.pl "$name"#;
  my $out     = `$cmd_cpu`;

  return $out;

  debug("end", "debug", \[caller(0)] ) if $debug;
}

#get_cpu_usage(
#  'process' => "",
#  'id'      => 'script-name',
#);
sub get_cpu_usage {
  debug("start", "debug", \[caller(0)] ) if $debug;
  debug("Input data: ".join ", ", @_, "debug", \[caller(0)] ) if $debug;
  use Fcntl qw(SEEK_SET SEEK_CUR SEEK_END);


  my %input           = @_;

  $input{'tmp'}       ||= "/tmp/zabbix/top_collector";
  $input{'top-log'}   ||= "/tmp/zabbix/top_collector/top.log";
  $input{'id'}        ||= "no-id";

  create_dir($input{'tmp'});

  unless (defined $input{'process'}) {
    debug("Missing input data 'process'. return", "fatal", \[caller(0)] );
    return;
  }

  my $timestamp_log   = 0; 
  my $cpu_max         = 0;

  my $process_file    = $input{'process'}."_".$input{'id'};
  $process_file       =~ s/\W/_/g;
  $process_file       = "$input{'tmp'}/$process_file";

  my $timestamp_last  = get_last_check_timestamp($process_file);

  open my $fh_r_top, "<", $input{'top-log'} or die "Can't open $input{'top-log'}: $!\n";
  seek $fh_r_top, -1*1024*1024, SEEK_END;

  my $split_count_cpu = 0;
  while (<$fh_r_top>) {
    s/^\s{1,}//;   

    #Get the array index for CPU
    if (!$split_count_cpu and /^PID/) {
      #PID USER      PR  NI    VIRT    RES    SHR S %CPU %MEM     TIME+ COMMAND
      foreach (split/\s{1,}/) {
        last if /CPU/;
        $split_count_cpu++;
      }
    }


    if (/TIME: \d{4,}/) {
      ($timestamp_log) = /TIME: (\d{1,})/;
    }

    next unless $timestamp_log;

    if ($timestamp_last && $timestamp_log) {
      next if $timestamp_last > $timestamp_log;
    }

    #22664 admin     20   0    2420    716    616 S  0.0  0.0   0:00.00 mpstat 1 1
    #my ($pid, $user, $pr, $ni, $virt, $res, $shr, $s, $cpu, $mem, $time, $command) = split/\s{1,}/;

    my @split = split/\s{1,}/;

    #the first thing is the PID
    next unless /^\d/;
  
    next unless /$input{'process'}/;
    debug("while top: $_", "debug", \[caller(0)] ) if $debug > 4;

    debug("Found split index for CPU usage in top.log: $split_count_cpu\n");

    if ($split_count_cpu == 0) {
      $split_count_cpu = 8;
      debug("Could not find index value for CPU. Setting \$split_count_cpu to 8\n");
    }

    next unless $split[$split_count_cpu];
    $cpu_max = $split[$split_count_cpu] if $split[$split_count_cpu] > $cpu_max;  

  }

  set_timestamp($process_file);
 
  return $cpu_max;
}

sub set_timestamp {
  my $file = shift || die "need a filename to set timestamp";

  open my $fh_w,">", $file or die "Can't write to $file: $!\n";
  print $fh_w time;
  close $fh_w;
}

sub get_last_check_timestamp {
  my $file    = shift || die "Need a process name to get last check";
  #my $dir_tmp = shift || "/tmp/zabbix/top_collector_get_data";
  my $timestamp;

  if (-f $file) {
    $timestamp = readfile($file);
  }
  else {
    set_timestamp($file);
  }

}


sub get_cpu_usage_process_v1 {
  my $name = shift || die "Need a process name to get CPU usage from\n";

  foreach (`top -H -b -n1`){
    s/^\s{1,}//; 
    my @split = split/\s+/; 

    next unless $split[11];

    if ($split[11] eq $name){
      return $split[8];
    }   
  }
}

sub get_corexl_count {
  my $vsid = shift;

  my $id_max = 0;

  foreach (run_cmd("source /etc/profile.d/vsenv.sh; vsenv $vsid &>/dev/null ; fw ctl multik stat 2>&1", "a", 600)) {
    s/\s{1,}//;
    next unless /^\d/;

    my ($id) = split/\s{1,}/;

    next unless $id =~ /\d/;

    $id_max = $id if $id > $id_max;
  }

  return $id_max + 1;
}

sub init_json {
  my $json = JSON->new();
  $json->relaxed(1);
  $json->ascii(1);
  $json->pretty(1);

  return $json;
}

#Legacy 
sub is_vsx {
  if (cpprod('type' => 'FwIsVSX')) {
    return 1;
  }
  else {
    return 0;
  }
}

sub cpprod {
  debug("start", "debug", \[caller(0)] ) if $debug;

  my %input = @_;

  unless (defined $input{'type'} and $input{'type'}) {
    debug("Missing input data. This is a code error. Fatal error", "fatal", \[caller(0)] );
    return;
  }

  debug("Checking if this installation has: '$input{'type'}'", "debug", \[caller(0)] ) if $debug;

  my $cmd_cpprod  = "cpprod_util $input{'type'}";
  my $out_cpprod  = run_cmd($cmd_cpprod, 's', 600);

  $out_cpprod     =~ s/^\s{1,}//;
  $out_cpprod     =~ s/\s{1,}$//;

  $out_cpprod     =~ s/^\t{1,}//;
  $out_cpprod     =~ s/\t{1,}$//;

  if (defined $out_cpprod and length $out_cpprod > 0) {
    debug("Data returned from run_cmd(): '$out_cpprod'", "debug", \[caller(0)] ) if $debug;
  }
  else {
    debug("No data returned from run_cmd(). Something is wrong", "fatal", \[caller(0)] );
    return;
  }

  return $out_cpprod;
  #TODO.
  #Validate outout value

  if ($out_cpprod == 1) {
    debug("\$out_cpprod is 1. True", "debug", \[caller(0)] ) if $debug;
    return 1;
  }
  elsif ($out_cpprod == 0) {
    debug("\$out_cpprod is 0. False", "debug", \[caller(0)] ) if $debug;
    return 0;
  }
  else {
    debug("\$out_cpprod is a unknown value. Something is wrong.", "fatal", \[caller(0)] );
  }

  debug("end", "debug", \[caller(0)] ) if $debug;
}

sub is_ha_active {

  debug("start", "debug", \[caller(0)] ) if $debug;

  my %input = @_;

  $input{'vsid'} = 0 unless defined $input{'vsid'};

  my $out = run_cmd("source /etc/profile.d/vsenv.sh; vsenv $input{'vsid'} &>/dev/null && cphaprob state", "s", 6000);

  
=pod

  [Expert@host:3]# cphaprob state

  Cluster Mode:   Virtual System Load Sharing

  Number     Unique Address  Assigned Load   State

  1 (local)  10.1.1.36      0%              Standby
  2          10.1.1.37      100%            Active

  Local member is in current state since Fri Dec 10 05:28:16 2021

=cut


  if ($out =~ /local.*active/i) {
    return 1;
  }
  elsif ($out =~ /local.*standby/i) {
    return 0;
  }
  else {
    debug("Could not parse cphaprob state. Something is wrong", "fatal", \[caller(0)] );
    return;
  }


}

sub is_ha_and_active {

  debug("start", "debug", \[caller(0)] ) if $debug;

  my %input = @_;

  $input{'vsid'} = 0 unless defined $input{'vsid'};

  my $out = run_cmd("source /etc/profile.d/vsenv.sh; vsenv $input{'vsid'} &>/dev/null ; cphaprob state", "s", 6000);

  
=pod

  [Expert@host:3]# cphaprob state

  Cluster Mode:   Virtual System Load Sharing

  Number     Unique Address  Assigned Load   State

  1 (local)  10.1.1.36      0%              Standby
  2          10.1.1.37      100%            Active

  Local member is in current state since Fri Dec 10 05:28:16 2021

=cut


  if ($out =~ /local.*active/i) {
    return 1;
  }
  elsif ($out =~ /local.*standby/i) {
    return 0;
  }
  else {
    debug("Could not parse cphaprob state. Something is wrong", "fatal", \[caller(0)] );
    return;
  }


}


sub is_enabled_ia {

  debug("start", "debug", \[caller(0)] ) if $debug;

  my %input = @_;
  my $name  = "identityServer";

  $input{'vsid'} = 0 unless defined $input{'vsid'};
  debug("VSID: $input{'vsid'}", "debug", \[caller(0)] ) if $debug;

  my $out = run_cmd("vsenv $input{'vsid'} &>/dev/null ; enabled_blades", "s", 6000);
  
=pod

fw urlf av appi ips identityServer anti_bot ThreatEmulation

=cut

  if ($out =~ /$name/i) {
    debug("$name found in enabled_blades. Return 1", "debug", \[caller(0)] ) if $debug;
    return 1;
  }
  else {
    debug("$name NOT found in enabled_blades. Return 0", "debug", \[caller(0)] ) if $debug;
    return 0;
  }
}

sub is_enabled_fw {

  debug("start", "debug", \[caller(0)] ) if $debug;

  my %input = @_;
  my $name  = "fw";

  $input{'vsid'} = 0 unless defined $input{'vsid'};
  debug("VSID: $input{'vsid'}", "debug", \[caller(0)] ) if $debug;

  my $out = run_cmd("vsenv $input{'vsid'} &>/dev/null ; enabled_blades", "s", 6000);
  
=pod

fw urlf av appi ips identityServer anti_bot ThreatEmulation

=cut

  if ($out =~ /$name/i) {
    debug("$name found in enabled_blades. Return 1", "debug", \[caller(0)] ) if $debug;
    return 1;
  }
  else {
    debug("$name NOT found in enabled_blades. Return 0", "debug", \[caller(0)] ) if $debug;
    return 0;
  }
}

sub is_enabled_urlf {

  debug("start", "debug", \[caller(0)] ) if $debug;

  my %input = @_;
  my $name  = "urlf";

  $input{'vsid'} = 0 unless defined $input{'vsid'};
  debug("VSID: $input{'vsid'}", "debug", \[caller(0)] ) if $debug;

  my $out = run_cmd("vsenv $input{'vsid'} &>/dev/null ; enabled_blades", "s", 6000);
  
=pod

fw urlf av appi ips identityServer anti_bot ThreatEmulation

=cut

  if ($out =~ /$name/i) {
    debug("$name found in enabled_blades. Return 1", "debug", \[caller(0)] ) if $debug;
    return 1;
  }
  else {
    debug("$name NOT found in enabled_blades. Return 0", "debug", \[caller(0)] ) if $debug;
    return 0;
  }
}

sub is_enabled_av {

  debug("start", "debug", \[caller(0)] ) if $debug;

  my %input = @_;
  my $name  = "av";

  $input{'vsid'} = 0 unless defined $input{'vsid'};
  debug("VSID: $input{'vsid'}", "debug", \[caller(0)] ) if $debug;

  my $out = run_cmd("vsenv $input{'vsid'} &>/dev/null ; enabled_blades", "s", 6000);
  
=pod

fw urlf av appi ips identityServer anti_bot ThreatEmulation

=cut

  if ($out =~ /$name/i) {
    debug("$name found in enabled_blades. Return 1", "debug", \[caller(0)] ) if $debug;
    return 1;
  }
  else {
    debug("$name NOT found in enabled_blades. Return 0", "debug", \[caller(0)] ) if $debug;
    return 0;
  }
}

sub is_enabled_appi {

  debug("start", "debug", \[caller(0)] ) if $debug;

  my %input = @_;
  my $name  = "appi";

  $input{'vsid'} = 0 unless defined $input{'vsid'};
  debug("VSID: $input{'vsid'}", "debug", \[caller(0)] ) if $debug;

  my $out = run_cmd("vsenv $input{'vsid'} &>/dev/null ; enabled_blades", "s", 6000);
  
=pod

fw urlf av appi ips identityServer anti_bot ThreatEmulation

=cut

  if ($out =~ /$name/i) {
    debug("$name found in enabled_blades. Return 1", "debug", \[caller(0)] ) if $debug;
    return 1;
  }
  else {
    debug("$name NOT found in enabled_blades. Return 0", "debug", \[caller(0)] ) if $debug;
    return 0;
  }
}

sub is_enabled_ips {

  debug("start", "debug", \[caller(0)] ) if $debug;

  my %input = @_;
  my $name  = "ips";

  $input{'vsid'} = 0 unless defined $input{'vsid'};
  debug("VSID: $input{'vsid'}", "debug", \[caller(0)] ) if $debug;

  my $out = run_cmd("vsenv $input{'vsid'} &>/dev/null ; enabled_blades", "s", 6000);
  
=pod

fw urlf av appi ips identityServer anti_bot ThreatEmulation

=cut

  if ($out =~ /$name/i) {
    debug("$name found in enabled_blades. Return 1", "debug", \[caller(0)] ) if $debug;
    return 1;
  }
  else {
    debug("$name NOT found in enabled_blades. Return 0", "debug", \[caller(0)] ) if $debug;
    return 0;
  }
}

sub is_enabled_ab {

  debug("start", "debug", \[caller(0)] ) if $debug;

  my %input = @_;
  my $name  = "anti_bot";

  $input{'vsid'} = 0 unless defined $input{'vsid'};
  debug("VSID: $input{'vsid'}", "debug", \[caller(0)] ) if $debug;

  my $out = run_cmd("vsenv $input{'vsid'} &>/dev/null ; enabled_blades", "s", 6000);
  
=pod

fw urlf av appi ips identityServer anti_bot ThreatEmulation

=cut

  if ($out =~ /$name/i) {
    debug("$name found in enabled_blades. Return 1", "debug", \[caller(0)] ) if $debug;
    return 1;
  }
  else {
    debug("$name NOT found in enabled_blades. Return 0", "debug", \[caller(0)] ) if $debug;
    return 0;
  }
}

sub is_enabled_te {

  debug("start", "debug", \[caller(0)] ) if $debug;

  my %input = @_;
  my $name  = "ThreatEmulation";

  $input{'vsid'} = 0 unless defined $input{'vsid'};
  debug("VSID: $input{'vsid'}", "debug", \[caller(0)] ) if $debug;

  my $out = run_cmd("vsenv $input{'vsid'} &>/dev/null ; enabled_blades", "s", 6000);
  
=pod

fw urlf av appi ips identityServer anti_bot ThreatEmulation

=cut

  if ($out =~ /$name/i) {
    debug("$name found in enabled_blades. Return 1", "debug", \[caller(0)] ) if $debug;
    return 1;
  }
  else {
    debug("$name NOT found in enabled_blades. Return 0", "debug", \[caller(0)] ) if $debug;
    return 0;
  }

  debug("end", "debug", \[caller(0)] ) if $debug;
}

sub is_enabled_scrub {

  debug("start", "debug", \[caller(0)] ) if $debug;

  my %input = @_;
  my $name  = "Scrub";

  $input{'vsid'} = 0 unless defined $input{'vsid'};
  debug("VSID: $input{'vsid'}", "debug", \[caller(0)] ) if $debug;

  my $out = run_cmd("vsenv $input{'vsid'} &>/dev/null ; enabled_blades", "s", 6000);
  
=pod

fw urlf av appi ips identityServer anti_bot ThreatEmulation

=cut

  if ($out =~ /$name/i) {
    debug("$name found in enabled_blades. Return 1", "debug", \[caller(0)] ) if $debug;
    return 1;
  }
  else {
    debug("$name NOT found in enabled_blades. Return 0", "debug", \[caller(0)] ) if $debug;
    return 0;
  }

  debug("end", "debug", \[caller(0)] ) if $debug;
}

sub is_enabled_ca {

  debug("start", "debug", \[caller(0)] ) if $debug;

  my %input = @_;
  my $name  = "content_awareness";

  $input{'vsid'} = 0 unless defined $input{'vsid'};
  debug("VSID: $input{'vsid'}", "debug", \[caller(0)] ) if $debug;

  my $out = run_cmd("vsenv $input{'vsid'} &>/dev/null ; enabled_blades", "s", 6000);
  
=pod

fw urlf av appi ips identityServer anti_bot ThreatEmulation

=cut

  if ($out =~ /$name/i) {
    debug("$name found in enabled_blades. Return 1", "debug", \[caller(0)] ) if $debug;
    return 1;
  }
  else {
    debug("$name NOT found in enabled_blades. Return 0", "debug", \[caller(0)] ) if $debug;
    return 0;
  }

  debug("end", "debug", \[caller(0)] ) if $debug;
}

sub is_enabled_cvpn {

  debug("start", "debug", \[caller(0)] ) if $debug;

  my %input = @_;
  my $name  = "cvpn";

  $input{'vsid'} = 0 unless defined $input{'vsid'};
  debug("VSID: $input{'vsid'}", "debug", \[caller(0)] ) if $debug;

  my $out = run_cmd("vsenv $input{'vsid'} &>/dev/null ; enabled_blades", "s", 6000);
  
=pod

fw urlf av appi ips identityServer anti_bot ThreatEmulation

=cut

  if ($out =~ /$name/i) {
    debug("$name found in enabled_blades. Return 1", "debug", \[caller(0)] ) if $debug;
    return 1;
  }
  else {
    debug("$name NOT found in enabled_blades. Return 0", "debug", \[caller(0)] ) if $debug;
    return 0;
  }

  debug("end", "debug", \[caller(0)] ) if $debug;
}

sub is_enabled_vpn {

  debug("start", "debug", \[caller(0)] ) if $debug;

  my %input = @_;
  my $name  = "vpn";

  $input{'vsid'} = 0 unless defined $input{'vsid'};
  debug("VSID: $input{'vsid'}", "debug", \[caller(0)] ) if $debug;

  my $out = run_cmd("vsenv $input{'vsid'} &>/dev/null ; enabled_blades", "s", 6000);
  
=pod

fw urlf av appi ips identityServer anti_bot ThreatEmulation

=cut

  if ($out =~ /$name/i) {
    debug("$name found in enabled_blades. Return 1", "debug", \[caller(0)] ) if $debug;
    return 1;
  }
  else {
    debug("$name NOT found in enabled_blades. Return 0", "debug", \[caller(0)] ) if $debug;
    return 0;
  }

  debug("end", "debug", \[caller(0)] ) if $debug;
}

sub is_enabled_aspm {

  debug("start", "debug", \[caller(0)] ) if $debug;

  my %input = @_;
  my $name  = "aspm";

  $input{'vsid'} = 0 unless defined $input{'vsid'};
  debug("VSID: $input{'vsid'}", "debug", \[caller(0)] ) if $debug;

  my $out = run_cmd("vsenv $input{'vsid'} &>/dev/null ; enabled_blades", "s", 6000);
  
=pod

fw urlf av appi ips identityServer anti_bot ThreatEmulation

=cut

  if ($out =~ /$name/i) {
    debug("$name found in enabled_blades. Return 1", "debug", \[caller(0)] ) if $debug;
    return 1;
  }
  else {
    debug("$name NOT found in enabled_blades. Return 0", "debug", \[caller(0)] ) if $debug;
    return 0;
  }

  debug("end", "debug", \[caller(0)] ) if $debug;
}



sub is_mgmt {
  debug("start", "debug", \[caller(0)] ) if $debug;

  my $name  = "FwIsFirewallMgmt";

  if (cpprod('type' => $name)) {
    debug("$name is true", "debug", \[caller(0)] ) if $debug;
    return 1;
  }
  else {
    debug("$name is false", "debug", \[caller(0)] ) if $debug;
    return 0;
  }


  debug("end", "debug", \[caller(0)] ) if $debug;
}

sub mgmt_cli {

  debug("start", "debug", \[caller(0)] ) if $debug;

  my %input = @_;

  $input{'host'}    ||= "127.0.0.1";
  $input{'port'}    ||= 443;
  $input{'timeout'} ||= 60;
  $input{'debug'}   ||= "on";
  $input{'format'}  ||= "text";

  unless (defined $input{'command'} or length $input{'vsid'} < 1) {
    debug("Missing input command. return", "fatal", \[caller(0)] );
    return;
  }
  debug("Command: $input{'command'}", "debug", \[caller(0)] ) if $debug;

  my $out = run_cmd("mgmt_cli $input{'command'} --unsafe-auto-accept true --conn-timeout $input{'timeout'} --debug $input{'debug'} --format $input{'text'} --ignore-errors false --management $input{'host'} --root true --port $input{'port'}", "s", 600);

  if ($out =~ /Error/) {
    debug("Error found: $out", "fatal", \[caller(0)] );
    return "error: $out";
  }

  debug("end", "debug", \[caller(0)] ) if $debug;
  return $out;
}

#./script denug=1
#2022.01.17
sub read_config_options {
  debug("Start", "debug", \[caller(0)]) if $debug > 1;
  #debug("Input config from command line: ".Dumper(@ARGV), "debug", \[caller(0)]) if $debug{'sub read_config_options'};
  
  #Get input data
  my @options = @_;

  my %options = ();

  foreach my $input (@options){

    my ($key, $value);
    
    if ($input =~ /=/) {
      debug("Found = in input. Split on =", "debug", \[caller(0)]) if $debug > 1;
      ($key, $value) = split/\s{0,}=\s{0,}/, $input;
    }

    #Set default value
    unless (defined $value and $value) {
      debug("No data found in \$value. Setting default to 1", "debug", \[caller(0)]) if $debug;
      $value = 1;
    }

    debug("key: '$key' = value: '$value'", "debug", \[caller(0)]) if $debug > 1;

    if ($key =~ /^debug/) {
      $key =~ s/^debug://;
      debug("\$debug{$key} = $value", "debug", \[caller(0)]) if $debug > 1;
      $debug = $value;
      next;
    }

    debug("\$config{$key} = $value", "debug", \[caller(0)]) if $debug > 1;
    $options{$key} = $value;
  }

  debug("end", "debug", \[caller(0)]) if $debug > 1;
  return %options;
}

#2022.01.17
#TODO
#Module not installed on default CP perl
sub hash_merge {
  debug("start", "debug", \[caller(0)]) if $debug;
  #debug("Input data: ".Dumper(@_), "debug", \[caller(0)]) if $debug;

  my %input = @_;

  unless (defined $input{'hash_left'}){
    debug("Missing data in input: 'hash_left'. return", "fatal", \[caller(0)]) if $debug;
    return;
  }

  unless (defined $input{'hash_right'}){
    debug("Missing data in input: 'hash_right'. return", "fatal", \[caller(0)]) if $debug;
    return;
  }

  my $merger = init_hash_merge();

  my %merged = %{ $merger->merge( \%{$input{'hash_left'}}, \%{$input{'hash_left'}} ) };

  return \%merged;

  debug("end", "debug", \[caller(0)]) if $debug;

}


#2022.01.17
sub init_hash_merge {
  debug("start", "debug", \[caller(0)]) if $debug;

  my $merger = Hash::Merge->new();
  #$merger->add_behavior_spec(Hash::Merge::Extra::L_REPLACE, "L_REPLACE");

  debug("end", "debug", \[caller(0)]) if $debug;
  return $merger;
}


#2022.01.17
sub get_time_ms {
  debug("start", "debug", \[caller(0)]) if $debug;
  use Time::HiRes;

  my $utime   = join "", Time::HiRes::gettimeofday;
  $utime = substr $utime, 0, 13;

  debug("end", "debug", \[caller(0)]) if $debug;
  return $utime;
}


=pod
  write_to_file(
    'file'            => $file,
    'type'            => 'append',                                              #appen/overwrite
    'message'         => $message,                                              #Message to save
    'fatal'           => 0,                                                     #0/1. 0 = die if writing failed. 1 = return error message if error writing
    'max_file_size'   => $max_file_size,                                        #Byte. Max file size
    'debug-disabled'  => 1,                                                     #Stop debug loop. Disable debug messages.
  );
=cut


#my $hash_ref = json_to_hash( 'json_string' => \%hash);
#2022.01.17
sub json_to_hash {
  debug("Start", "debug", \[caller(0)]) if $debug;
  #debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug;

  my %input = @_;

  my %eval_data;
  $eval_data{'json_string'} = $input{'json_string'};

  my $eval_code = <<'EOF';
  $$eval_data{"hash_ref"} = decode_json $$eval_data{"json_string"};
EOF

  run_eval(
    'code'    => $eval_code,
    'desc'    => "json_to_hash() decode_json",
    'timeout' => 2,
    'data'    => \%eval_data,
  );

  #debug("Sending back hash ref: ".Dumper($eval_data{'hash_ref'}), "debug", \[caller(0)]) if $debug;
  debug("End", "debug", \[caller(0)]) if $debug;

  return $eval_data{'hash_ref'};
}


#hash_to_json( 'hash_ref' => \%hash);
sub hash_to_json {
  debug("Start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  my %input = @_;

  my %eval_data;
  $eval_data{'hash_ref'} = $input{'hash_ref'};

  my $eval_code = <<'EOF';
    my $json = init_json();
    #$$eval_data{"json"} = $json->encode_json($eval_data{"hash_ref"});
    my $coder = JSON::XS->new->ascii->pretty->allow_nonref;
    $$eval_data{"json"} = $pretty_printed_unencoded = $coder->encode($$eval_data{"hash_ref"});
EOF

  run_eval(
    'code'    => $eval_code,
    'desc'    => "hash_to_json() encode_json",
    'timeout' => 2,
    'data'    => \%eval_data,
  );

  #TODO. Verify JSON in string

  debug("Sending back JSON: $eval_data{'json'}", "debug", \[caller(0)]) if $debug > 3;
  debug("End", "debug", \[caller(0)]) if $debug > 1;

  return $eval_data{'json'};
}



=pod
my %eval_data = ();
my $code = <<'EOF';

$$eval_data{'out'} = `sleep 3`;

EOF

run_eval(
  'code'    => $code,
  'desc'    => "run eval example code",
  'timeout' => 1,
  'data'    => \%eval_data,
);

if (defined $eval_data{'error'} and $eval_data{'error'} =~ /alarm/) {
  debug("Error found in run_eval(). Eval timeout.  Error: '$eval_data{'error'}'", "fatal", \[caller(0)] );
  die $eval_data{'error'};
}

if (defined $eval_data{'error'}) {
  debug("Error found in run_eval(). die. Error: '$eval_data{'error'}'", "fatal", \[caller(0)] );
  die $eval_data{'error'};
  
}
print $eval_data{'out'};

=cut
sub run_eval {
  debug("Start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  my %input       = @_;

  my $code        = $input{'code'}        || die "Need code to run in eval";
  my $desc        = $input{'desc'}        || die "Need a description to run code in eval";
  my $timeout     = $input{'timeout'}     || 10;
  my $eval_data   = $input{'data'};

  my $status      = 1;

  my $eval_alarm_error;
  my $eval_code_error;

  #Run code section
  debug("$desc. Eval code start: $code", "debug", \[caller(0)]) if $debug > 2;
  {
    {
      debug("$desc. Alarm set to $timeout", "debug", \[caller(0)])  if $debug > 2;
      debug("$desc. Before eval", "debug", \[caller(0)])  if $debug > 2;

      eval {
        local $SIG{'__DIE__'};
        local $@; # protect existing $@
        local $SIG{ALRM} = sub { die "alarm\n" };
        alarm $timeout;

          eval $code;

          alarm 0;

          $eval_code_error = $@;
      };
      debug("$desc. After eval", "debug", \[caller(0)])  if $debug > 2;
      debug("$desc. Alarm set to 0", "debug", \[caller(0)]) if $debug > 2;

      $eval_alarm_error = $@;
    }
    debug("$desc. Code finished", "debug", \[caller(0)]) if $debug > 2;

    debug("$desc. Checking for eval error", "debug", \[caller(0)]) if $debug > 2;

    if ($eval_alarm_error) {
      $$eval_data{'error'} = "$desc. perl code eval timeout";
      debug("$desc. perl code eval timeout", "eval_error", \[caller(0)]) if $fatal;
      $status = 0;

    }
    else {
      debug("$desc. Perl code no timeout", "debug", \[caller(0)]) if $debug > 2;
    }

    if ($eval_code_error) {
      debug("$desc. eval error code found: $eval_code_error\nCode: $code. Input: ".join ", ", @_, "eval_error", \[caller(0)])  if $fatal;
      $$eval_data{'error'} = "$desc. eval error code found: $eval_code_error\nCode: $code";
      $status = 0;
    }
    else {
      debug("$desc. No eval error code found", "debug", \[caller(0)]) if $debug > 2;
    }
  }
  debug("$desc. Eval code finished", "debug", \[caller(0)]) if $debug > 2;

}

#regex_value($from, $to, $opt, \$data);
#2022.01.17
sub regex_value {
  debug("Start", "debug", \[caller(0)] ) if $debug;

  my $from      = shift || "";
  my $to        = shift || "";
  my $opt       = shift || "";
  my $data_ref  = shift || "";

  unless ($from or $to or $data_ref) {
    debug("Missing input data: from: '$from', to: '$to', data: '$$data_ref'", "code_error", "error", \[caller(0)] ) if $debug;
    next;
  }

  debug("Input data: from: \"$from\", to: \"$to\", data: $$data_ref", "debug", \[caller(0)] ) if $debug;

  debug("Before substitute: $$data_ref", "debug", \[caller(0)] ) if $debug;
  $$data_ref =~ s/$from/$to/i;
  debug("After substitute: $$data_ref", "debug", \[caller(0)] ) if $debug;

  debug("End", "debug", \[caller(0)] ) if $debug;
}

#2022.01.17
sub ctrl_c_no_in_use {
  debug("Start", "debug", \[caller(0)] ) if $debug;
  debug("Exiting script", "info", \[caller(0)] ) if $debug;

  debug("ctrl_c() Exit", "debug", \[caller(0)] ) if $debug;
  exit;
}

#2022.01.17
#In MB
#die "Not enough free disk space left" unless free_disk_space(100, "/");
sub free_disk_space {
  debug("Start", "debug", \[caller(0)] ) if $debug;
  my $min_free    = shift;
  my $partition   = shift || "/";
  my $die_if_less = shift || 0;
  my $cmd_df      = "df --no-sync -k -BM";

  unless ($min_free) {
    debug("Missing input for minimum disk space", "fatal", \[caller(0)] );
    return;
  }

  unless ($partition) {
    debug("Missing input for partition", "fatal", \[caller(0)] );
    return;
  }

  debug("Command: '$cmd_df'", "debug", \[caller(0)] ) if $debug;
  foreach my $line (run_cmd($cmd_df, "a", 600)) {
    my ($filesystem, $blocks, $used, $avail, $use_percent, $mount) = split /\s{1,}/, $line;
    $avail =~ s/\D//g;

    debug("Line: '$line'", "debug", \[caller(0)] ) if $debug;

    unless ($mount eq $partition) {
      debug("\$mount: '$mount' is not equal to \$partition: '$partition'. next", "debug", \[caller(0)] ) if $debug;
      next;
    }
    debug("\$mount: '$mount' is equal to \$partition: '$partition'. next", "debug", \[caller(0)] ) if $debug;

    if ($avail > $min_free) {
      debug("\$avail: '$avail' > \$min_free: '$min_free'. return 1", "debug", \[caller(0)] ) if $debug;
      return 1;
    }
    else {

      if ($die_if_less) {
        my $msg = "\$avail: '$avail' < \$min_free: '$min_free'. die";
        debug($msg, "fatal", \[caller(0)] );
        die $msg;

      }

      debug("\$avail: '$avail' < \$min_free: '$min_free'. return 1", "debug", \[caller(0)] ) if $debug;
      return 0;
    }

  }

  debug("end", "debug", \[caller(0)] ) if $debug;
}

sub is_ok {
  debug("start", "debug", \[caller(0)] ) if $debug;

  my %input = @_;

  $input{'cpu_idle'}          ||= 20;       #Min N CPU percent idle
  $input{'disk_free_path'}    ||= "/tmp";   #Path to check for disk free
  $input{'disk_free_mb'}      ||= 500;      #N MB free on N
  
  die "Not enough free disk space left on $input{'disk_free_mb'}" unless free_disk_space($input{'disk_free_mb'}, $input{'disk_free_path'});

  debug("end", "debug", \[caller(0)] ) if $debug;
}

sub init_runtime {
  debug("start", "debug", \[caller(0)] ) if $debug;

  print @_;

  my %input = @_;

  $input{'cpu_idle'}          ||= 20;       #Min N CPU percent idle

  debug("end", "debug", \[caller(0)] ) if $debug;
}

#my %input = parse_command_line(@ARGV);
#2022.01
sub parse_command_line {
  debug("start", "debug", \[caller(0)] ) if $debug;
  debug("Input data: ".join ", ", @_, "debug", \[caller(0)] ) if $debug;

  my @argv = @_;
  my @return;

  ARGV:
  foreach my $argv (@argv){
    debug("Argv: $argv", "debug", \[caller(0)] ) if $debug;
    
    debug("Found /^--/ in input argv: '$argv'", "debug", \[caller(0)] ) if $debug;

    push @return, $argv =~ /--(.*?)="(.*?)" /g;

    debug("argvs: ".join ", ", @return, "debug", \[caller(0)] ) if $debug;
      #$config =~ s/^'|^"//;
      #$config =~ s/'$|"$//;

      #$config =~ s/^\s{1,}//;

      #$config =~ s/^'|^"//;
      #$config =~ s/'$|"$//;


      #push @return, ($option, $value);
  }

  my %argv = @return;
  foreach my $key (keys %argv) {
    my $value = $argv{$key};

    if ($value =~ /^b64\(.*\)/) {
      debug("b64() found in argv value: $value", "debug", \[caller(0)] ) if $debug;

      my ($string) = $value =~ /b64\((.*?)\)/;

      $value = base64_to_string('data' => $string);
      debug("New value: $value", "debug", \[caller(0)] ) if $debug;
      $argv{$key} = $value;
    }
  }

  return %argv;

  debug("end", "debug", \[caller(0)] ) if $debug;
}

#delete_file('file' => $file);
#2022.02.10
sub delete_file {
  debug("start", "debug", \[caller(0)] ) if $input{'print-error'};
  debug("Input data: ".join ", ", @_, "debug", \[caller(0)] ) if $input{'print-error'};

  my %input = @_;

  $input{'print-error'}   = 0  unless defined $input{'print-error'};

  #Validate input data file
  unless (defined $input{'file'} and $input{'file'}) {
    debug("Missing input data for file. return", "fatal", \[caller(0)] ) if $input{'print-error'};
    return;
  }
  
  #Validate the file START
  if (-e $input{'file'}) {
    debug("File exists: $input{'file'}", "debug", \[caller(0)] ) if $input{'print-error'};
  }
  else {
    debug("File does not exist: '$input{'file'}'", "error", \[caller(0)] ) if $input{'print-error'};
    return;
  }

  if (-f $input{'file'}) {
    debug("File is a file: '$input{'file'}'", "debug", \[caller(0)] ) if $input{'print-error'};
  }
  else {
    debug("File is not a file type. File: '$input{'file'}'", "error", \[caller(0)] )  if $input{'print-error'};
    return;
  }
  #Validate the file END

  my $unlink_status = unlink $input{'file'};

  if ($unlink_status) {
    debug("File $input{'file'} is deleted. return 1", "debug", \[caller(0)] ) if $input{'print-error'};
    return 1;
  }
  else {
    debug("Deleting the file $input{'file'} FAILED: $!. return", "error", \[caller(0)] ) if $input{'print-error'};
    return;
  }



  debug("end", "debug", \[caller(0)] ) if $input{'print-error'};
}



#print get_last_message('file' => $file_message) if -f $file_message;
#2022.02.10
sub get_last_message {
  debug("start", "debug", \[caller(0)] ) if $debug > 1;
  debug("Input data: ".join ", ", @_, "debug", \[caller(0)] ) if $debug > 1;

  my %input = @_;

  $input{'print-error'}         = 0  unless defined $input{'print-error'};
  $input{'delete-file-after'}   = 1  unless defined $input{'delete-file-after'};

  #Validate input data file
  unless (defined $input{'file'} and $input{'file'}) {
    debug("Missing input data for file. return", "fatal", \[caller(0)] );
    return;
  }
  
  my $message = readfile(
    $input{'file'}, 
    's',
    1000,
  );

  #Delete the message file
  debug("delete_file()", "debug", \[caller(0)] ) if $debug > 1;
  delete_file('file' => $input{'file'}) if $input{'delete-file-after'};
  
  debug("end", "debug", \[caller(0)] ) if $debug > 1;

  #This is the return data to the zabbix agent
  return $message;
}

#set_last_message('file' => $file_message, 'message' => 'hello');
#2022.02.10
sub set_last_message {
  debug("start", "debug", \[caller(0)] ) if $debug > 1;
  debug("Input data: ".join ", ", @_, "debug", \[caller(0)] ) if $debug > 1;

  my %input = @_;

  $input{'print-error'}         = 0  unless defined $input{'print-error'};
  $input{'delete-file-after'}   = 1  unless defined $input{'delete-file-after'};

  #Validate input data file
  unless (defined $input{'file'} and $input{'file'}) {
    debug("Missing input data for file. return", "fatal", \[caller(0)] );
    return;
  }

  #Validate input data message
  unless (defined $input{'message'}) {
    debug("Missing input data for message. return", "fatal", \[caller(0)] );
    return;
  }

  debug("Message file found: $input{'file'}. Will read, print the file content and delete the file", "debug", \[caller(0)] ) if $debug;

  my $write_status = write_to_file(
  'file'            => $input{'file'},
  'type'            => 'append',                                              #appen/overwrite
  'message'         => $input{'message'},                                     #Message to save
  'fatal'           => 1,                                                     #0/1. 0 = die if writing failed. 1 = return error message if error writing
  'max_file_size'   => 1000,                                                  #Byte. Max file size
  'debug-disabled'  => 0,                                                     #Stop debug loop. Disable debug messages.
  );

  debug("end", "debug", \[caller(0)] ) if $debug > 1;
  return $write_status;
}

#2022.02.10
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

#2022.02.15
sub get_date {
  #debug("start", "debug", \[caller(0)] ) if $debug > 2;
  #debug("Input data: ".join ", ", @_, "debug", \[caller(0)] ) if $debug > 2;

  my %input = @_;

  $input{'time'}         = time  unless defined $input{'time'};

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime($input{'time'});

  #debug("end", "debug", \[caller(0)] ) if $debug > 1;
  return sprintf "%4d.%02d.%02d",$year+1900,$mon+1,$mday;
}

sub get_config {
  my %input = @_;

  my $debug_local = 0;
  $debug_local    = 0 if defined $input{'no-debug'};

  debug("start", "debug", \[caller(0)] ) if $debug_local > 2;
  debug("Input data: ".join ", ", @_, "debug", \[caller(0)] ) if $debug_local > 2;

  #Validate input
  #unless ($input{'home'} and $input{'home'}) {
  #  debug("Missing input data 'home'. exit", "fatal", \[caller(0)] ) if $fatal;
  #  exit;
  #}

  my %config = ();

  if (defined $main::tmp_dir) {
    debug("\$main::tmp_dir is defined. \$config{'dir'}{'home'} = \$main::tmp_dir ($main::tmp_dir)", "debug", \[caller(0)] ) if $debug_local > 2;
    $config{'dir'}{'home'} = $main::tmp_dir;
  }

  #Directories
  $config{'dir'}{'home'}        ||= "/tmp/zabbix/no_name";

  $config{'dir'}{'home'}        =~ s/\.\///;
  $config{'dir'}{'tmp'}         = "$config{'dir'}{'home'}/tmp";
  $config{'dir'}{'log'}         = "$config{'dir'}{'home'}/log";
  $config{'dir'}{'data'}        = "$config{'dir'}{'home'}/data";
  $config{'dir'}{'config'}      = "$config{'dir'}{'home'}/config";
  $config{'dir'}{'cache'}       = "$config{'dir'}{'home'}/cache";

  #Files
  $config{'file'}{'database'}   = "$config{'dir'}{'data'}/database.json";
  $config{'file'}{'stop'}       = "$config{'dir'}{'config'}/stop";

  $config{'log'}{'options'}   = {
    'dir' => $config{'dir'}{'log'},

  };

  #Default output data
  $config{'default-output'}   = {
    'error'         => 9999,                                                      # If something goes wrong for any reason. print this back to the zabbix agent
    'na'            => 8888,                                                      # Missing function, blade. print this if the check if for a function/blade that is not running
    'no-result'     => 0,                                                         #If no result/data is found. print this value
  };
  
  #Init config
  $config{'init'}   = {
    'is_cp_gw'        => 0,
    'is_cp_mgmt'      => 0,

    'cpu_count'       => 2,
  };

  $config{'log'}{'all'}       = {
    "enabled"       => 0,     #0/1
    "level"         => 1,     #0-9
    "print"         => 0,     #Print to STDOUT
    "print-warn"    => 0,     #Print to STDERR
    "log"           => 0,     #Save to log file
    "file"          => "$config{'dir'}{'log'}/all.log", #Log file
    "file-fifo"     => 0,     #Create a fifo file for log
    "file-size"     => 10,    #MB max log file size
    "cmd"           => "",    #Run CMD if log. Variable: _LOG_
    "lines-ps"      => 10,    #Max lines pr second
    "die"           => 0,     #Die/exit if this type of log is triggered
  };

  $config{'log'}{'default'}       = {
    "enabled"       => 0,     #0/1
    "level"         => 1,     #0-9
    "print"         => 0,     #Print to STDOUT
    "print-warn"    => 0,     #Print to STDERR
    "log"           => 0,     #Save to log file
    "file"          => "$config{'dir'}{'log'}", #Log file
    "file-fifo"     => 0,     #Create a fifo file for log
    "file-size"     => 10,    #MB max log file size
    "cmd"           => "",    #Run CMD if log. Variable: _LOG_
    "lines-ps"      => 10,    #Max lines pr second
    "die"           => 0,     #Die/exit if this type of log is triggered
  };


  $config{'log'}{'debug'}       = {
    "enabled"       => 1,     #0/1
    "level"         => 1,     #0-9
    "print"         => 1,     #Print to STDOUT
    "print-warn"    => 0,     #Print to STDERR
    "log"           => 1,     #Save to log file
    "file"          => "$config{'dir'}{'log'}/debug.log", #Log file
    "file-fifo"     => 0,     #Create a fifo file for log
    "file-size"     => 10,    #MB max log file size
    "cmd"           => "",    #Run CMD if log. Variable: _LOG_
    "lines-ps"      => 10,    #Max lines pr second
    "die"           => 0,     #Die/exit if this type of log is triggered
  };

  $config{'log'}{'info'}       = {
    "enabled"       => 1,     #0/1
    "level"         => 1,     #0-9
    "print"         => 1,     #Print to STDOUT
    "print-warn"    => 0,     #Print to STDERR
    "log"           => 1,     #Save to log file
    "file"          => "$config{'dir'}{'log'}/info.log", #Log file
    "file-fifo"     => 0,     #Create a fifo file for log
    "file-size"     => 10,    #MB max log file size
    "cmd"           => "",    #Run CMD if log. Variable: _LOG_
    "lines-ps"      => 10,    #Max lines pr second
    "die"           => 0,     #Die/exit if this type of log is triggered
  };

  $config{'log'}{'warning'}       = {
    "enabled"       => 1,     #0/1
    "level"         => 1,     #0-9
    "print"         => 1,     #Print to STDOUT
    "print-warn"    => 1,     #Print to STDERR
    "log"           => 1,     #Save to log file
    "file"          => "$config{'dir'}{'log'}/warning.log", #Log file
    "file-fifo"     => 0,     #Create a fifo file for log
    "file-size"     => 10,    #MB max log file size
    "cmd"           => "",    #Run CMD if log. Variable: _LOG_
    "lines-ps"      => 10,    #Max lines pr second
    "die"           => 0,     #Die/exit if this type of log is triggered
  };

  $config{'log'}{'error'}       = {
    "enabled"       => 1,     #0/1
    "level"         => 1,     #0-9
    "print"         => 1,     #Print to STDOUT
    "print-warn"    => 1,     #Print to STDERR
    "log"           => 1,     #Save to log file
    "file"          => "$config{'dir'}{'log'}/error.log", #Log file
    "file-fifo"     => 0,     #Create a fifo file for log
    "file-size"     => 10,    #MB max log file size
    "cmd"           => "",    #Run CMD if log. Variable: _LOG_
    "lines-ps"      => 10,    #Max lines pr second
    "die"           => 0,     #Die/exit if this type of log is triggered
  };

  $config{'log'}{'fatal'}       = {
    "enabled"       => 1,     #0/1
    "level"         => 1,     #0-9
    "print"         => 1,     #Print to STDOUT
    "print-warn"    => 1,     #Print to STDERR
    "log"           => 1,     #Save to log file
    "file"          => "$config{'dir'}{'log'}/fatal.log", #Log file
    "file-fifo"     => 0,     #Create a fifo file for log
    "file-size"     => 10,    #MB max log file size
    "cmd"           => "",    #Run CMD if log. Variable: _LOG_
    "lines-ps"      => 10,    #Max lines pr second
    "die"           => 0,     #Die/exit if this type of log is triggered
  };


  $config{'log'}{'debug'}{'enabled'}    = $main::debug if defined $main::debug;
  $config{'log'}{'info'}{'enabled'}     = $main::info if defined $main::info;
  $config{'log'}{'warning'}{'enabled'}  = $main::warning if defined $main::warning;
  $config{'log'}{'error'}{'enabled'}    = $main::error if defined $main::error;
  $config{'log'}{'fatal'}{'enabled'}    = $main::fatal if defined $main::fatal;


 
 

  debug("end", "debug", \[caller(0)] ) if $debug_local > 2;
  return %config;

}

#my $string_b64 = string_to_base64('data' => $string);
sub string_to_base64 {
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;
  require MIME::Base64;


  my %input = @_;

  unless (defined $input{'data'}) {
    debug("Missing input data 'data'", "fatal", \[caller(0)] ) if $fatal;
    exit;
  }

  my $encoded = MIME::Base64::encode_base64url($input{'data'});
  debug("Base 64 encoded string: $encoded", "debug", \[caller(0)]) if $debug > 3;

  debug("end", "debug", \[caller(0)]) if $debug > 1;
  return $encoded;
}

#my $string = base64_to_string('data' => $data);
sub base64_to_string {
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;
  require MIME::Base64;

  my %input = @_;

  unless (defined $input{'data'}) {
    debug("Missing input data 'data'", "fatal", \[caller(0)] ) if $fatal;
    exit;
  }

  my $decoded = MIME::Base64::decode_base64url($input{'data'});
  debug("Base 64 encoded string: $decoded", "debug", \[caller(0)]) if $debug > 3;

  debug("end", "debug", \[caller(0)]) if $debug > 1;
  return $decoded;
}

#2022.02.18
sub get_dfg_int {
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;


  my %input = @_;
  my $cmd_ip_route = "ip route";

  $input{'vsid'} = 0 unless defined $input{'vsid'};

  unless (defined $input{'vsid'}) {
    debug("Missing input data 'vsid'", "fatal", \[caller(0)] ) if $fatal;
    exit;
  }

  my $data = run_cmd({
    'cmd'             => $cmd_ip_route,
    'return-type'     => 's', 
    'refresh-time'    => 24*60,
    'timeout'         => 10,
    'vsid'            => $input{'vsid'},
  });

  #default via 10.90.1.1 dev Mgmt  proto routed
  my ($default) = $data =~ /default.*?dev\s(.*?)\s/;

  debug("end", "debug", \[caller(0)]) if $debug > 1;
  return $default;
}

sub get_int_ip {
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;


  my %input = @_;
  my $cmd_ip_address = "ip address show";

  $input{'vsid'} = 0 unless defined $input{'vsid'};

  unless (defined $input{'vsid'}) {
    debug("Missing input data 'vsid'", "fatal", \[caller(0)] ) if $fatal;
    return;
  }

  unless (defined $input{'int'}) {
    debug("Missing input data 'int'", "fatal", \[caller(0)] ) if $fatal;
    return;
  }



  my $data = run_cmd({
    'cmd'             => $cmd_ip_address,
    'return-type'     => 's', 
    'refresh-time'    => 24*60,
    'timeout'         => 10,
    'vsid'            => $input{'vsid'},
  });

  #1: lo: <LOOPBACK,UP,LOWER_UP> mtu 16436 qdisc noqueue
  #  link/loopback 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff
  #  inet 127.0.0.1/8 brd 127.255.255.255 scope host lo

  my ($ip) = $data =~ /$input{'int'}.*?inet (.*?)\//s;

  unless (defined $ip) {
    debug("Missing IP-address for interface: '$input{'int'}'", "warning", \[caller(0)] ) if $warning;
    return;
  }

  debug("end", "debug", \[caller(0)]) if $debug > 1;
  return $ip;
}


sub get_cp_version {
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  my $cmd_fw_ver = "fw ver";

  my $data = run_cmd({
    'cmd'             => $cmd_fw_ver,
    'return-type'     => 's', 
    'refresh-time'    => 30*24*60,
    'timeout'         => 10,
  });

  my ($ver) = $data =~ /version (.*?)\s/i;
  
  if (defined $ver) {
    debug("Check Point version found: '$ver'", "debug", \[caller(0)] ) if $debug > 1;
  }
  else {
    debug("Check Point version NOT found. Failed", "fatal", \[caller(0)] ) if $fatal;
    return;
  }

  #Remove the R from the release version number
  $ver =~ s/^R//;

  #Remove .
  $ver =~ s/\.//;

  #4 digit version number
  $ver = sprintf("%04d", $ver);

  debug("return data: '$ver'", "debug", \[caller(0)]) if $debug > 2;
  debug("end", "debug", \[caller(0)]) if $debug > 1;
  return $ver;
}

sub format_cmd {
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  my %input = @_;
  my $cmd;

  $input{'vsid'} = 0 unless defined $input{'vsid'};

  unless (defined $input{'cmd'}) {
    debug("Missing input data 'cmd'", "fatal", \[caller(0)] );
    exit;
  }

  my $ver = get_cp_version();
  unless (defined $ver) {
    debug("Missing input data 'cmd'", "fatal", \[caller(0)] );
    return;
  }

  if ($ver < 8030) {
    debug("CP version is less than 8030. Ver: '$ver'", "debug", \[caller(0)] ) if $debug > 1;

    $cmd = "source /etc/profile.d/vsenv.sh; vsenv $input{'vsid'} &>/dev/null ; $input{'cmd'}";
  }
  elsif ($ver >= 8030) {
    debug("CP version is more or eqal to than 8030. Ver: '$ver'", "debug", \[caller(0)] ) if $debug > 1;

    my $vrf_name_number = sprintf("%05d", $input{'vsid'});
    my $vrf_name        = "CTX".$vrf_name_number;

    $cmd       = "ip netns exec $vrf_name $input{'cmd'}";
  }

  debug("New CMD: $cmd", "debug", \[caller(0)] ) if $debug > 2;

  debug("end", "debug", \[caller(0)]) if $debug > 1;
  return $cmd;
}

#my $found = get_running_process('regex' => "perl");
sub get_running_process {
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  my %input   = @_;
  my $cmd_ps  = "ps xau";

  unless (defined $input{'regex'}) {
    debug("Missing input data 'regex'", "fatal", \[caller(0)] );
    exit;
  }

  debug("run_cmd() $cmd_ps", "debug", \[caller(0)] ) if $debug > 1;
  my @process = run_cmd({
    'cmd'             => $cmd_ps, 
    'return-type'     => 'a', 
    'refresh-time'    => 2, 
    'timeout'         => 5, 
  });

  foreach my $line (@process) {
    debug("Line: '$line'", "debug", \[caller(0)] ) if $debug > 3;

    if ($line =~ /$input{'regex'}/) {
      debug("regex match found. return \$line. regec: '$input{'regex'}', line: '$line'", "debug", \[caller(0)] ) if $debug > 1;
      return $line;
    }
  }

  debug("regex match not found. return 0. regec: '$input{'regex'}'", "debug", \[caller(0)] ) if $debug > 1;
  debug("end", "debug", \[caller(0)]) if $debug > 1;
  return 0;
}

#save_and_exit('exit' = 1, 'die' => 0);
sub save_and_exit {
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  my %input   = @_;

  $input{'exit'}     = 1 unless defined $input{'exit'};

  debug("end", "debug", \[caller(0)]) if $debug > 1;
}


=pod
  help(
    'msg'         => "Missing input data. No data in \@ARGV",
    'die'         => 1,
    'debug'       => 1,
    'debug_type'  => "fatal",
  );
=cut

sub get_json_file_to_hash {
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  my %input   = @_;

  unless (defined $input{'file'}) {
    debug("Missing input data 'file'", "fatal", \[caller(0)] );
    exit;
  }

  unless (-f $input{'file'}) {
    debug("JSON file not found. return ()", "debug", \[caller(0)]) if $debug > 1;
    return ();
  }

  return ();

}

#sub run_exit START
=pod
  help(
    'msg'         => "Missing input data. No data in \@ARGV",
    'die'         => 1,
    'debug'       => 1,
    'debug_type'  => "fatal",
  );
=cut
sub run_exit {
  $debug = $main::debug if defined $main::debug;
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  #sub header START
  my %input   = @_;
  my $return;

  #Default values
  $input{'msg'} = "no exit message" unless defined $input{'msg'};
  
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
      return;
    }
  }

  #sub header END
  
  #sub main code START

  exit;


  #sub main code END
  
  #sub end section START

  #Validate return data
  if ($input{'validate-return-data'} and defined $return and length $return == 0) {
    debug("Return data is not defined. Input data: ".Dumper(%input), "fatal", \[caller(0)] );
    run_exit() if $input{'exit-if-fatal'};
    return;
  }


  debug("end", "debug", \[caller(0)]) if $debug > 1;
  return $return;
  
  #sub end section END

}
#sub run exit END


#sub filename safe START
=pod
  my $filename_safe = get_filename_safe( 'name' => 'filename !! \\');
  my $filename_safe = get_filename_safe( 'name' => 'filename !! \\', 'exit-if-fatal' => 1);

  get_filename_safe(
    'name'        => 'filename !! \\',
    'debug'       => 1,
  );
=cut
sub get_filename_safe {
  $debug = $main::debug if defined $main::debug;
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  #sub header START
  my %input   = @_;
  my $return;

  #Default values
  $input{'version'}               = 1   unless defined $input{'version'};
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

  $return       = $input{'name'};
  debug("filename before: '$return'", "debug", \[caller(0)]) if $debug > 1;

  if ($input{'version'} == 1) {
    debug("version 1", "debug", \[caller(0)]) if $debug > 1;

    $return     =~ s/\W/_/g;
    $return     =~ s/_{2,}/_/g;
    $return     =~ s/^_|_$//g;
  }
  else {
    debug("Wrong version number. Input:\n".Dumper(%input), "fatal", \[caller(0)] );
      run_exit() if $input{'exit-if-fatal'};
      return;
  }

  debug("filename after: '$return'", "debug", \[caller(0)]) if $debug > 1;

  #sub main code END
  
  #sub end section START

  #Validate return data
  if ($input{'validate-return-data'} and defined $return and length $return == 0) {
    debug("Return data is not defined. Input data: ".Dumper(%input), "fatal", \[caller(0)] );
    run_exit() if $input{'exit-if-fatal'};
    return;
  }


  debug("end", "debug", \[caller(0)]) if $debug > 1;
  return $return;
  
  #sub end section END

}
#sub filename safe END


#sub get_fh START
=pod
  my $fh_w = get_fh( 'file' => $filename);

  get_fh(
    'file'            => $filename,
    'max-size'        => 10,  #MB
    'exit-if-fatal'   => 1);
    'debug'           => 1,
  );
=cut
sub get_fh {
  $debug = $main::debug if defined $main::debug;
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  #sub header START
  my %input   = @_;
  my $return;

  #Default values
  $input{'exit-if-fatal'}         = 0   unless defined $input{'exit-if-fatal'};
  $input{'return-if-fatal'}       = 1   unless defined $input{'return-if-fatal'};
  $input{'validate-return-data'}  = 1   unless defined $input{'validate-return-data'};
  $input{'max-size'}              = 10  unless defined $input{'max-size'};
  #$input{'XXX'} = "YYY" unless defined $input{'XXX'};
  
  #Set debug if debug found in input
  if (defined $input{'debug'}) {
    debug("debug defined in input data. debug: $input{'debug'}", "debug", \[caller(0)]) if $config{'log'}{'debug'}{'enable'} and $config{'log'}{'debug'}{'level'} > 1;
    local $config{'log'} = $config{'log'};
    $config{'log'}{'debug'}{'enable'} = $input{'debug'};
  }


  my @input_type = qw( file );
  foreach my $input_type (@input_type) {

    unless (defined $input{$input_type} and length $input{$input_type} > 0) {
      debug("Missing input data for '$input_type'", "fatal", \[caller(0)] );
      run_exit() if $input{'exit-if-fatal'};
      return;
    }
  }
  #sub header END
  
  #sub main code START

  trunk_file_if_bigger_than_mb($input{'file'}, $input{'max-size'}) if -e $input{'file'}; #trunc file if file size is bigger than N

  my $open_status = open $return, ">>", $input{'file'};

  #Validate open
  if ($open_status) {
    debug("file open was a success", "debug", \[caller(0)]) if $debug > 1;
  }
  else {
    debug("File open failed: $!", "fatal", \[caller(0)] );
    run_exit() if $input{'exit-if-fatal'};
    return;
  }

  #sub main code END
  
  #sub end section START

  #Validate return data
  if ($input{'validate-return-data'} and defined $return and length $return == 0) {
    debug("Return data is not defined. Input data: ".Dumper(%input), "fatal", \[caller(0)] );
    run_exit() if $input{'exit-if-fatal'};
    return;
  }


  debug("end", "debug", \[caller(0)]) if $debug > 1;
  return $return;
  
  #sub end section END

}
#sub get_fh END



#sub init_global_begin
=pod
  init_global_begin('version' => 1);
=cut
sub init_global_begin {
  $debug = $main::debug if defined $main::debug;
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  #sub header START
  my %input   = @_;
  my $return;

  #Default values
  $input{'exit-if-fatal'}         = 1   unless defined $input{'exit-if-fatal'};
  $input{'return-if-fatal'}       = 0   unless defined $input{'return-if-fatal'};
  $input{'validate-return-data'}  = 0   unless defined $input{'validate-return-data'};
  #$input{'XXX'} = "YYY" unless defined $input{'XXX'};
  
  #Set debug if debug found in input
  if (defined $input{'debug'}) {
    debug("debug defined in input data. debug: $input{'debug'}", "debug", \[caller(0)]) if $config{'log'}{'debug'}{'enable'} and $config{'log'}{'debug'}{'level'} > 1;
    local $config{'log'} = $config{'log'};
    $config{'log'}{'debug'}{'enable'} = $input{'debug'};
  }


  my @input_type = qw( version );
  foreach my $input_type (@input_type) {

    unless (defined $input{$input_type} and length $input{$input_type} > 0) {
      debug("Missing input data for '$input_type'", "fatal", \[caller(0)] );
      run_exit() if $input{'exit-if-fatal'};
      return;
    }
  }

  #sub header END
  
  #sub main code START

  #run some tests


  #sub main code END
  
  #sub end section START

  #Validate return data
  if ($input{'validate-return-data'} and defined $return and length $return == 0) {
    debug("Return data is not defined. Input data: ".Dumper(%input), "fatal", \[caller(0)] );
    run_exit() if $input{'exit-if-fatal'};
    return;
  }


  debug("end", "debug", \[caller(0)]) if $debug > 1;
  return $return;
  
  #sub end section END

}
#sub init_global_after_config END





#sub init_global_before_config START
=pod
  init_global_before_config('version' => 1);
=cut
sub init_global_before_config {
  $debug = $main::debug if defined $main::debug;
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  #sub header START
  my %input   = @_;
  my $return;

  #Default values
  $input{'exit-if-fatal'}         = 1   unless defined $input{'exit-if-fatal'};
  $input{'return-if-fatal'}       = 0   unless defined $input{'return-if-fatal'};
  $input{'validate-return-data'}  = 0   unless defined $input{'validate-return-data'};
  #$input{'XXX'} = "YYY" unless defined $input{'XXX'};
  
  #Set debug if debug found in input
  if (defined $input{'debug'}) {
    debug("debug defined in input data. debug: $input{'debug'}", "debug", \[caller(0)]) if $config{'log'}{'debug'}{'enable'} and $config{'log'}{'debug'}{'level'} > 1;
    local $config{'log'} = $config{'log'};
    $config{'log'}{'debug'}{'enable'} = $input{'debug'};
  }



  my @input_type = qw( version );
  foreach my $input_type (@input_type) {

    unless (defined $input{$input_type} and length $input{$input_type} > 0) {
      debug("Missing input data for '$input_type'", "fatal", \[caller(0)] );
      run_exit() if $input{'exit-if-fatal'};
      return;
    }
  }

  #sub header END
  
  #sub main code START

  #run some tests

  #sub main code END
  
  #sub end section START

  #Validate return data
  if ($input{'validate-return-data'} and defined $return and length $return == 0) {
    debug("Return data is not defined. Input data: ".Dumper(%input), "fatal", \[caller(0)] );
    run_exit() if $input{'exit-if-fatal'};
    return;
  }


  debug("end", "debug", \[caller(0)]) if $debug > 1;
  return $return;
  
  #sub end section END

}
#sub init_global_after_config END





#sub init_global_after_config START
=pod
  init_global_after_config('version' => 1);
=cut
sub init_global_after_config {
  $debug  = $main::debug  if defined $main::debug;
  #$config = \%main::config if %main::config;
  #

  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

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
    debug("debug defined in input data. debug: $input{'debug'}", "debug", \[caller(0)]) if $$config{'log'}{'debug'}{'enable'} and $$config{'log'}{'debug'}{'level'} > 1;
    local $config{'log'} = $config{'log'};
    $config{'log'}{'debug'}{'enable'} = $input{'debug'};
  }



  my @input_type = qw( version );
  foreach my $input_type (@input_type) {

    unless (defined $input{$input_type} and length $input{$input_type} > 0) {
      debug("Missing input data for '$input_type'", "fatal", \[caller(0)] );
      run_exit() if $input{'exit-if-fatal'};
      return;
    }
  }

  #sub header END
  
  #sub main code START

  #run some tests
  #check all files in $config{'files'}


    #run some local tests for this script
  #Exit if stop file found
  save_and_exit('msg' => "Stop file found $main::config{'file'}{'stop'}. Exit") if -f $main::config{'file'}{'stop'};

  #Exit if this is not a gw
  save_and_exit('msg' => "is_gw() returned 0. This is not a GW. Exit") if $main::config{'init'}{'is_cp_gw'} and is_gw();

  #Exit if this is not a mgmt
  save_and_exit('msg' => "is_mgmt() returned 0. This is not a MGMT. Exit") if $main::config{'init'}{'is_cp_mgmt'} and is_mgmt();

  #Exit if CPU count is low
  if (defined $main::config{'init'}{'cpu_min_count'} and $main::config{'init'}{'cpu_min_count'} and cpu_count() < $main::config{'init'}{'cpu_min_count'}) {
    save_and_exit('msg' => "CPU count os too low. Exit");
  }

  #Create tmp/data directory
  if (defined $main::config{'dir'}{'tmp'} and not -d $main::config{'dir'}{'tmp'} ) {
    create_dir($main::config{'dir'}{'tmp'} );
  }

  LOG_FILE:
  foreach my $log_type (keys %{$config{'log'}}) {
    my $log_file = $$config{'log'}{$log_type}{'file'};
    debug("Log file: $log_file", "debug", \[caller(0)] ) if $$config{'log'}{'debug'}{'enable'} and $$config{'log'}{'debug'}{'level'} > 1;

    unless (defined $log_file) {
      debug("Log file not defined in config", "error", \[caller(0)] ) if $$config{'log'}{'error'}{'enable'};
      next LOG_FILE;
    }


    trunk_file_if_bigger_than_mb($log_file,10);
  }



  #Hash for long time storage. Saved to file
  $main::db                         = get_json_file_to_hash('file' => $main::config{'file'}{'database'});

  #Hash for short time storage. Not saved to file
  %main::tmp                        = ();

  #Run init global after config
  #my $init_global_after_config_status  = init_global_after_config('version' => 1);
  #if ($init_global_after_config_status) {
  #  debug("init global failed: $init_global_after_config_status", "fatal", \[caller(0)] );
  #  exit;
  #}



  #Check for input options
  #unless (@ARGV) {
  #  help(
  #    'msg'         => "Missing input data. No data in \@ARGV",
  #    'die'         => 1,
  #    'debug'       => 1,
  #    'debug_type'  => "warning",
  #  );
  #}


  #Parse input data
  %main::argv     = parse_command_line(@main::ARGV) if @main::ARGV;

  #Print help if no input is given
  #help('msg' => "help started from command line", 'exit'  => 1) if defined $argv{'help'};

  #Activate debug if debug found in command line options
  if (defined $main::argv{'debug'}) {
    debug("\$argv{'debug'} is defined", "debug", \[caller(0)] ) if $main::config{'log'}{'debug'}{'enable'} and $main::config{'log'}{'debug'}{'level'};
    $main::config{'log'}{'debug'}{'enable'} = $argv{'debug'};
  }

  #init JSON
  #my $json = init_json();

  if (defined $return) {
    debug("init local after config failed: $return", "fatal", \[caller(0)] );
    exit;
  }


  #sub main code END
  
  #sub end section START

  #Validate return data
  if ($input{'validate-return-data'} and defined $return and length $return == 0) {
    debug("Return data is not defined. Input data: ".Dumper(%input), "fatal", \[caller(0)] );
    run_exit() if $input{'exit-if-fatal'};
    return;
  }


  debug("end", "debug", \[caller(0)]) if $debug > 1;
  return $return;
  

  #sub end section END

}
#sub init_global_after_config END




#sub fork_and_exit START
=pod
  fork_and_exit( 'version' => 1 );
=cut
sub fork_and_exit {
  $debug = $main::debug if defined $main::debug;
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  #sub header START
  my %input   = @_;
  my $return;

  #Default values
  $input{'exit-if-fatal'}         = 0   unless defined $input{'exit-if-fatal'};
  $input{'return-if-fatal'}       = 1   unless defined $input{'return-if-fatal'};
  $input{'validate-return-data'}  = 1   unless defined $input{'validate-return-data'};
  $input{'version'}               = 1   unless defined $input{'version'};
  #$input{'XXX'} = "YYY" unless defined $input{'XXX'};
  
  #Set debug if debug found in input
  if (defined $input{'debug'}) {
    debug("debug defined in input data. debug: $input{'debug'}", "debug", \[caller(0)]) if $config{'log'}{'debug'}{'enable'} and $config{'log'}{'debug'}{'level'} > 1;
    local $config{'log'} = $config{'log'};
    $config{'log'}{'debug'}{'enable'} = $input{'debug'};
  }



  my @input_type = qw( version stdout stderr );
  foreach my $input_type (@input_type) {

    unless (defined $input{$input_type} and length $input{$input_type} > 0) {
      debug("Missing input data for '$input_type'", "fatal", \[caller(0)] );
      run_exit() if $input{'exit-if-fatal'};
      return;
    }
  }

  #sub header END
  
  #sub main code START

  #fork a child and exit the parent
  fork && exit;

  #Closing so the parent can exit and the child can live on
  #The parent will live and wait for the child if there is no close
  
  #Close STDIN
  close STDIN;

  #Get file handles for stdout and stderr
  my $fh_stdout = get_fh( 'file' => $input{'stdout'});
  my $fh_stderr = get_fh( 'file' => $input{'stderr'});

  #Redirect stdout and stderr for the child to files
  open STDOUT, ">&", $fh_stdout;
  open STDERR, ">&", $fh_stderr;


  #sub main code END
  
  #sub end section START

  #Validate return data
  if ($input{'validate-return-data'} and defined $return and length $return == 0) {
    debug("Return data is not defined. Input data: ".Dumper(%input), "fatal", \[caller(0)] );
    run_exit() if $input{'exit-if-fatal'};
    return;
  }


  debug("end", "debug", \[caller(0)]) if $debug > 1;
  return $return;
  
  #sub end section END

}
#sub template END


=pod
my @interfaces = get_interfaces();
=cut

sub get_interfaces {
  debug("Start", "debug", \((caller(0))[3]) ) if $$config{'log'}{'debug'}{'enabled'};
  my @interfaces;

  my $cmd_ip_address = "ip address show";


  debug("Code error. Should not be here", "error", \((caller(0))[3]) );
}

=pod
my $comment = get_config_comment('config' => \$config, 'interface' => $int) || "";
=cut

sub get_config_comment {
  debug("Start", "debug", \((caller(0))[3]) ) if $$config{'log'}{'debug'}{'enabled'};
  my %input = @_;

  $input{'config'}      ||= "";  #clish config file in scalar ref
  $input{'interface'}   ||= "";  #name of interface

  unless (ref $input{'config'}) {
    debug("Missing input data: config. Code error. Returning with no data", "fatal", \((caller(0))[3]) );
    return;
  }

  unless ($input{'interface'}) {
    debug("Missing input data: interface. Code error. Returning with no data", "fatal", \((caller(0))[3]) );
    return;
  }
  debug("Input data. interface: $input{'interface'}", "debug", \((caller(0))[3]) ) if $$config{'log'}{'debug'}{'enabled'};

  my ($comment) = ${$input{'config'}} =~ /set interface $input{'interface'} comments (.*)/;
  if ($comment) {
    chomp $comment;
    $comment =~ s/"//g;
    $comment =~ s/^\s{1,}//g;
    $comment =~ s/\s{1,}$//g;
    debug("Found comment in config: $comment", "debug", \((caller(0))[3]) ) if $$config{'log'}{'debug'}{'enabled'};
  }
  else {
    debug("Could not find any comment for interface $input{'interface'} in clish config. Will not return any data", "warning", \((caller(0))[3]) );
    return;
  }


  return $comment;
}

=pod
  my $type    = get_interface_type('interface' => $int) || "";
=cut

sub get_interface_type {
  debug("Start", "debug", \((caller(0))[3]) ) if $$config{'log'}{'debug'}{'enabled'};
  my %input = @_;
  my $type;

  $input{'interface'}   ||= "";  #name of interface
  unless ($input{'interface'}) {
    debug("Missing input data: interface. Code error. Returning with no data", "fatal", \((caller(0))[3]) );
    return;
  }
  debug("Input data. interface: $input{'interface'}", "debug", \((caller(0))[3]) ) if $$config{'log'}{'debug'}{'enabled'};

  #TYPES=( bond bond_slave bridge can dummy erspan geneve gre gretap hsr ifb ip6erspan ip6gre ip6gretap ip6tnl ipip ipoib ipvlan ipvtap lowpan macsec macvlan macvtap netdevsim nlmon rmnet sit tap tun vcan veth vlan vrf vti vxcan vxlan xfrm)
  my %interface_type = (
    "lo"          => "local",
    "eth"         => "physical",
    "wan|lan|dmz" => "physical",
    "bareudp"     => "bareudp",
    "bond"        => "bond",
    "bond_slave"  => "bond_slave",
    "bridge"      => "bridge",
    "br"          => "bridge",
    "can" => "can",
    "dummy" => "dummy",
    "erspan" => "erspan",
    "geneve" => "geneve",
    "gre" => "gre",
    "gretap" => "gretap",
    "hsr" => "hsr",
    "ifb" => "ifb",
    "ip6erspan" => "ip6erspan",
    "ip6gre" => "ip6gre",
    "ip6gretap" => "ip6gretap",
    "ip6tnl" => "ip6tnl",
    "ipip" => "ipip",
    "ipoib" => "ipoib",
    "ipvlan" => "ipvlan",
    "ipvtap" => "ipvtap",
    "lowpan" => "lowpan",
    "macsec" => "macsec",
    "macvlan" => "macvlan",
    "macvtap" => "macvtap",
    "netdevsim" => "netdevsim",
    "nlmon" => "nlmon",
    "rmnet" => "rmnet",
    "sit" => "sit",
    "tap" => "tap",
    "tun" => "tun",
    "vcan" => "vcan",
    "veth" => "veth",
    "vlan" => "vlan",
    "vrf" => "vrf",
    "vti" => "vti",
    "vxcan" => "vxcan",
    "vxlan" => "vxlan",
    "xfrm" => "xfrm",
  );

  foreach my $interface_key (keys %interface_type) {
    debug("foreach my $interface_key (keys %interface_type)", "debug", \((caller(0))[3]) ) if $$config{'log'}{'debug'}{'enabled'} > 1;

    if ($input{'interface'} =~ /^$interface_key/i) {
      debug("Match on $input{'interface'} =~ /$interface_key/i. Returning name", "debug", \((caller(0))[3]) ) if $$config{'log'}{'debug'}{'enabled'};
      return uc $interface_type{$interface_key};
    }
  }


  my $file_uevent = "/sys/class/net/$input{'interface'}/uevent";
  if (-f $file_uevent) {
    debug("Found file $file_uevent. will read it and look for DEVTYPE=", "debug", \((caller(0))[3]) ) if $$config{'log'}{'debug'}{'enabled'};

    my $uevent_data = readfile($file_uevent);
    my ($type) = $uevent_data =~ /DEVTYPE=(.*)/;

    if ($type) {
      chomp $type;
      debug("Found type in $file_uevent: $type. Retuning type", "debug", \((caller(0))[3]) ) if $$config{'log'}{'debug'}{'enabled'};
      return $type;
    }
    else {
      debug("Could not find type in $file_uevent: $type", "error", \((caller(0))[3]) ) if $$config{'log'}{'debug'}{'enabled'};
      return;
    }
  }

  debug("Could not find interface type. Retuning no data", "error", \((caller(0))[3]) );


}



#sub template START
=pod
  help(
    'msg'         => "Missing input data. No data in \@ARGV",
    'die'         => 1,
    'debug'       => 1,
    'debug_type'  => "fatal",
  );
=cut
sub sub_template {
  $debug = $main::debug if defined $main::debug;
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

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


  debug("end", "debug", \[caller(0)]) if $debug > 1;
  return $return;
  
  #sub end section END

}
#sub template END




#create error

1;








