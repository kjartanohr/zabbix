#!/usr/bin/perl5.32.0
BEGIN{
 require "/usr/share/zabbix/repo/files/auto/lib.pm";
  #require "./lib.pm"
}

#TODO

#Changes


use warnings;
use strict;

my $process_name_org          = $0;
my $process_name              = "disk-usage";
$0                            = "perl $process_name VER 100";

#Print the data immediately. Don't wait for full buffer
$|++;

$SIG{CHLD}                    = "IGNORE";
#$SIG{INT}                     = \&save_and_exit('msg') => 'Signal INIT';

#Zabbix health check
zabbix_check($ARGV[0]);

our $dir_tmp                  = "/tmp/zabbix/$process_name";
our $file_debug               = "$dir_tmp/debug.log";
my  $file_exit                = "$dir_tmp/stop";

our $debug                    = 0;                                                  #This needs to be 0 when running in production
our $info                     = 1;
our $warning                  = 1;
our $error                    = 1;
our $fatal                    = 1;
my  $fork                     = 1;

#Get default config
our %config                   = get_config();

#Init config
$config{'init'}   = {
  'is_cp_gw'                  => 0,
  'is_cp_mgmt'                => 0,
  'cpu_count'                 => 2,
};

#Hash for long time storage. Saved to file
my $db                        = get_json_file_to_hash('file' => $config{'file'}{'database'});

#Hash for short time storage. Not saved to file
my %tmp                       = ();


#Exit if stop file found
save_and_exit('msg' => "Stop file found $config{'file'}{'stop'}. Exit") if -f $config{'file'}{'stop'};

#Exit if this is not a gw
save_and_exit('msg' => "is_gw() returned 0. This is not a GW. Exit") if $config{'init'}{'is_cp_gw'} and is_gw();

#Exit if this is not a mgmt
save_and_exit('msg' => "is_mgmt() returned 0. This is not a MGMT. Exit") if $config{'init'}{'is_cp_mgmt'} and is_mgmt();

#Exit if CPU count is low
save_and_exit('msg' => "CPU count os too low. Exit") if $config{'init'}{'cpu_min_count'} and cpu_count() < $config{'init'}{'cpu_min_count'};

#Create tmp/data directory
create_dir($dir_tmp) unless -d $dir_tmp;

#Trunk log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);

#debug("", "debug", \[caller(0)] ) if $debug;
#debug("", "info", \[caller(0)] )  if $debug;
#debug("", "error", \[caller(0)] ) if $error;
#debug("", "fatal", \[caller(0)] );



#Parse input data
my %argv = parse_command_line(@ARGV);

#Print help if no input is given
help('msg' => "help started from command line", 'exit'  => 1) if defined $argv{'help'};

#Activate debug if debug found in command line options
$debug = $argv{'debug'} if defined $argv{'debug'};

#init JSON
#my $json = init_json();


my %dir_exclude = (

  'proc'    => {
    'enabled'   => 1,
    'comment'   => 'proc folder is a virtual folder',
    'search'    => qr#/proc#,
  },

  'snapshot'    => {
    'enabled'   => 1,
    'comment'   => 'lv snapshot mount',
    'search'    => qr#/lvsnap#,
  },

);

my @du_options = (
  #"--null"               #         -0, --null                end each output line with NUL, not newline     -0, --null              end each output line with NUL, not newline
  #"--all"                #         -a, --all                 write counts for all files, not just directories
  #"--apparent-size"      #         --apparent-size           print apparent sizes, rather than disk usage; although the              apparent size is usually smaller, it may be larger due to              holes in ('sparse') files, internal fragmentation,              indirect blocks, and the like
  #"--block-size=SIZE"    #         -B, --block-size=SIZE     scale sizes by SIZE before printing them; e.g., '-BM'              prints sizes in units of 1,048,576 bytes; see SIZE format              below
  "--bytes",              #         -b, --bytes               equivalent to '--apparent-size --block-size=1'
  #"--total",             #         -c, --total               produce a grand total
  #"--dereference-args",  #         -D, --dereference-args    dereference only symlinks that are listed on the command              line
  #"--max-depth=1",       #         -d, --max-depth=N         print the total for a directory (or file, with --all) only              if it is N or fewer levels below the command line              argument;  --max-depth=0 is the same as --summarize
  #"--files0-from=F",     #         --files0-from=F           summarize disk usage of the NUL-terminated file names              specified in file F; if F is -, then read names from              standard input
  #"--dereference-args",  #         -H                        equivalent to --dereference-args (-D)
  #"--human-readable",    #         -h, --human-readable      print sizes in human readable format (e.g., 1K 234M 2G)
  #"--inodes",            #         --inodes                  list inode usage information instead of block usage
  #"-k",                  #         -k                        like --block-size=1K
  #"--dereference",       #         -L, --dereference         dereference all symbolic links
  #"--count-links",       #         -l, --count-links         count sizes many times if hard linked
  #"-m",                  #         -m                        like --block-size=1M
  #"--no-dereference",    #         -P, --no-dereference      don't follow any symbolic links (this is the default)
  "--separate-dirs",      #         -S, --separate-dirs       for directories do not include size of subdirectories
  #"--si",                #         --si                      like -h, but use powers of 1000 not 1024
  #"--summarize",         #         -s, --summarize           display only a total for each argument
  "--threshold=1",        #         -t, --threshold=SIZE      exclude entries smaller than SIZE if positive, or entries greater than SIZE if negative
  #"--time",              #         --time                    show time of the last modification of any file in the directory, or any of its subdirectories
  #"--time=WORD",         #         --time=WORD               show time as WORD instead of modification time: atime, access, use, ctime or status
  #"--time-style=STYLE",  #         --time-style=STYLE        show times using STYLE, which can be: full-iso, long-iso, iso, or +FORMAT; FORMAT is interpreted like in 'date'
  #"--exclude-from=FILE", #         -X, --exclude-from=FILE   exclude files that match any pattern in FILE
  #"--one-file-system",   #         -x, --one-file-system     skip directories on different file systems
  "--exclude='/proc'",    #         --exclude=PATTERN         exclude files that match PATTERN
);

my $cmd_du_options = array_to_string('array' => \@du_options);

#End of standard header

$argv{'path'}   ||= "/";
$argv{'lines'}  ||= 10;

my $cmd_du = qq#du $cmd_du_options $argv{'path'}#;
debug("CMD: $cmd_du", "debug", \[caller(0)] ) if $debug;

open my $fh_r, "-|", "$cmd_du 2>/dev/null" or die "Can't run $cmd_du: $!";

my %dir;
LINE:
while (my $line = readline $fh_r) {

  chomp $line;

  #Skip lines with 0 byte START
  if ($line =~ /^0 /) {
    debug("CMD: $cmd_du", "debug", \[caller(0)] ) if $debug;
    next LINE;
  }
  #Skip lines with 0 byte END

  #Check exclude list START
  foreach my $exclude (keys %dir_exclude) {
    my $search = $dir_exclude{$exclude}{'search'};

    if ($line =~ /$search/) {
      debug("Exclude regex match. next LINE. '$line' =~ /$search/", "debug", \[caller(0)] ) if $debug > 2;
      next LINE;
    }
  }
  #Check exclude list END

  debug("OUT: '$line'", "debug", \[caller(0)] ) if $debug > 4;

  my ($size, $path) = $line =~ /^(\d{1,})\s{1,}(.*)/;

  #Validate data START
  if (not defined $size) {
    debug("Parsing error. Could not get size from line: '$line'", "error", \[caller(0)] ) if $error;
    next LINE;
  }
  if (not defined $path) {
    debug("Parsing error. Could not get path from line: '$line'", "error", \[caller(0)] ) if $error;
    next LINE;
  }
  #Validate data END

  $dir{$path} = $size;
}

print "\nDirectory size\n\n";

my @dir_top;
my $count_lines = 0;
foreach my $path (reverse sort { $dir{$a} <=> $dir{$b} } keys %dir) {
  my $size = $dir{$path};

  my $size_h = human_readable_byte($size, "GB");
  $size_h = int $size_h;

  if ($size_h < 1) {
    debug("Directory size is under 1 GB. next", "debug", \[caller(0)] ) if $debug > 4;
    next;
  }


  if ($count_lines++ == $argv{'lines'}) {
    debug("Max output lines reached. last", "debug", \[caller(0)] ) if $debug > 4;
    last;
  }

  push @dir_top, $path if scalar @dir_top < 3;

  print "size: '$size_h GB'\t Path: '$path'\n";

}

print "\n\nPress CTRL+D to continue\n\n";
my $input = <>;

foreach my $dir (@dir_top) {
  #-rw-rw----   1 1001M 2022-02-17 22:53:46.011755877 +0100 "2022-02-17_225346_43.log"
  #ls -go --human-readable --all --full-time --hide-control-chars --quote-name -S --no-group --color
  
  my $cmd_ls = qq#ls -go --human-readable --all --full-time --hide-control-chars --quote-name -S --no-group --color "$dir"#;
  debug("CMD: $cmd_du", "debug", \[caller(0)] ) if $debug;

  print "\n\nFiles in directory: $dir\n";

  open my $fh_r_ls, "-|", "$cmd_ls 2>/dev/null" or die "Can't run $cmd_ls: $!";

  my $count_lines_ls = 0;
  LS:
  while (my $line = readline $fh_r_ls) {

    chomp $line;

    #-rw-rw----   1 1001M 2022-02-17 22:53:46.011755877 +0100 "2022-02-17_225346_43.log"
    my ($acl, $int, $size, $date, $time, $time_zone, $filename) = split/\s{1,}|\t/, $line, 7;

    if (not $filename) {
      debug("Filename not found in line. next", "debug", \[caller(0)] ) if $debug > 4;
      next LS;
    }


    my $size_clean = $size;
    $size_clean =~ s/\D//g;

    if ($size =~ /K$/) {
      debug("File size type is K. next", "debug", \[caller(0)] ) if $debug > 4;
      next LS;
    }

    if ($size_clean < 1) {
      debug("File size is under 1. next", "debug", \[caller(0)] ) if $debug > 4;
      next LS;
    }

    if ($count_lines_ls++ == $argv{'lines'}) {
      debug("Max output lines reached. last", "debug", \[caller(0)] ) if $debug > 4;
      last LS;
    }


    print "$line\n";
  }



}

sub get_dir {
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  my %input   = @_;
  my @dir;

  $input{'exclude-regex'} = qr/^\.$|^\.\.$/ unless defined $input{'exclude-regex'};

  unless (defined $input{'path'}) {
    debug("Missing input data 'path'", "fatal", \[caller(0)] );
    exit;
  }

  unless (-d $input{'path'}) {
    debug("Input directory does not exist: $input{'path'}", "error", \[caller(0)]) if $error;
    return;
  }

  opendir my $dh, $input{'path'} or die "Can't open $input{'path'}: $!";

  DIR:
  while (my $dir = readline $dh) {

    if ($dir =~ $input{'exclude-regex'}) {
      debug("Directory matched exclude-regex. Dir: '$dir'. Regex: '$input{'exclude-regex'}'", "debug", \[caller(0)]) if $debug > 2;
      next DIR;
    }

    push @dir, $dir;
  }

  return @dir;
}

sub array_to_string {
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  my %input   = @_;

  unless (defined $input{'array'} and $input{'array'}) {
    debug("Missing input data 'array'", "fatal", \[caller(0)] );
    return;
  }

  my $string;

  foreach my $data (@{$input{'array'}}) {
    $string .= "$data "; 
  }

  return $string;

}



