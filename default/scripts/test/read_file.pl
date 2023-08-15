#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;

$0 = "perl read from file and command  VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

#Split input in to @ARGV
if ($ARGv[0] =~ /;;/) {
  @ARGV = split/\s{0,};;\s{0,}/, $ARGV[0];
}

#open file/cmd

#CMD:command         = CMD to run

#TXT:filename        = Text file to read

#VSID:10             = VSID 10. Run the CMD on VS ID 10. Default is to run the CMD with no VS ID

#MDS:10.0.0.1        = MDS 10.0.0.1. Run the CMD on MDS 10.0.0.1

#MIN:10              = How many minutes before running the command and recreating the buffer file. Default is 10 min. The output from the command will be saved in a buffer file to save system resources

#TIMEOUT:10          = Timeout for the script to run. Typicaly used with a command that can hang for some time. Default timeout is 25. Zabbix max timeout is 30. Recommended is max 2 sec

#SUBA:HELLO::HEY     = Substitute HELLO with HEY on every line from output. s/HELLO/HEY/g;

#SUBL:3::HELLO::HEY  = Substitute HELLO with HEY s/HELLO/HEY/g; on line 3 from output

#FIND:some text      = Stop looping the output if regex /some text/ is found on the line

#SPLIT_CHAR:\s{1,}   = \s{1,}. Split the line in to an array with REGEX \s{1,}

#SPLIT_GET:5         = 5. Get the array content from array index 5. $array[5]

#SUBO:HELLO::HEY     = HELLO::HEY. substitute content HELLO with HEY

#EVAL:some code      = eval code to run on result

#Example
#CMD:ls ;; VSID:10 ;; MIN:60 ;; SUBA:^\s{1,}:: ;;; SUBL:GARBAGE::NOT GARBAGE ;; FIND:something exciting on the line ;; SPLIT_CHAR:\s{1,} ;; SPLIT_GET:3 ;; SUBO:\D:: ;;

my $file           = file_exists(shift @ARGV);
my $type           = shift @ARGV || get_filetype($file) || die "Need a file type";
my $env            = input_check_vsid_or_mds(shift @ARGV);


my $dir_tmp        = "/tmp/zabbix/cmd/$env/";
our $file_debug    = "$dir_tmp/debug.log";
our $debug         = 1;


create_dir($dir_tmp);


#End of standard header

#If CMD,
  #cache output to /tmp/zabbix/cmd/$vsid/$cmd
  #always send CMD time used to debug()
  #if timeout reached. Log command and time used to timeout file. Zabbix will generate alarm from this file


#IF TXT. Check if file is bigger than 100M. Die with message






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

sub get_filetype {
  my $file = shift || die "Need filename to check for filetype\n";

  my $out_file = run_cmd("file -L -N $file");

  if ($out_file =~ /executable/) {
    debug("Filetype is executable");
    return "cmd";
  }
  elsif ($out_file =~ /text/) {
    debug("Filetype is text");
    return "file";
  }
  else {
    return;
  }
}

sub input_check_vsid_or_mds {
  my $input = shift;
  debug("sub translate_id: input $input");

  unless ($input) {
    debug("No VSID og MDS given, returning none\n");
    return "none";
  }

  return "none" if $input eq "none";

  if ($input =~ /vs\d/) {
    debug("Found VSID in input\");

    my ($vsid) = $input =~ /vs(\d{1,})/;

    unless ($vsid) {
      debug("Could not find VS ID in $input\n");
      die "Could not find VS ID in $input\n";
    }

    is_valid_vsid($vsid);

    return $vsid;
  }
}

sub is_valid_vsid {
  my $vsid = shift || die "Need a VSID to validate";

  if ($vsid =~ /\D/) {
    debug("VSID is malformed: $vsid. From input $input\n");
    die"VSID is malformed: $vsid. From input $input\n";
  }

  my $out_vsens = run_cmd("source /etc/profile.d/vsenv.sh; vsenv $vsid");

  if ($out_vsend =~ /Context is set to Virtual Device/) {
    die "This VSID $vsid does not exist";
  }

  return 1;
}

sub file_exists {
  my $file = shift || die "Need a filename to check if it exists";
  debug("sub file_exists: file $file\n");

  unless ($file) {
    debug("No filename given to check if it exists. Die\n");
    die "need a filename to check if it exists";
  }


  if (-f $file) {
    debug("File $file found, returning $file\n";
    return $file;
  }
  else {
    die "File $file does not exist";
  }
}
