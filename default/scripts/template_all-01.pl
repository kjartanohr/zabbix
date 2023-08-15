#!/usr/bin/perl
# 2023.01.12

BEGIN {
  if ($ARGV[0] eq "--zabbix-test-run"){ print "ZABBIX TEST OK"; exit; }
  my $url_zabbix_ext    = "http://zabbix.kjartanohr.no";
  my $url_zabbix_int    = "http://10.0.6.102";
  my $url_lib           = "$url_zabbix_int/zabbix/repo/default/lib/lib-dev.pm";
  my $pwd               = `pwd`; chomp $pwd; $pwd //= ".";
  #my $dir_lib          = "$ENV{'HOME'}/perl5/lib/perl5";
  $pwd =~ s/^\///;
  my $dir_lib           = "$pwd/lib/KFO";
  my $file_lib          = "$dir_lib/lib.pm";
  #push @INC, $pwd, $dir_lib, "$pwd/lib";  
  push @INC, ("./lib", $pwd, $dir_lib, "$pwd/lib", '/usr/share/zabbix/repo/lib', "$ENV{'HOME'}/lib", "$ENV{'HOME'}/perl", "$ENV{'HOME'}/perl5");

  print "$url_lib\n";
  system "mkdir -p -v $dir_lib" if not -d $dir_lib;
  #system qq#curl -v -k "$url_lib" -o "$file_lib"# if not -f $file_lib;
  print qq#curl -k "$url_lib" -o "$file_lib"\n#;
  system qq#curl -k "$url_lib" -o "$file_lib"#;
}

no warnings 'redefine';
use strict;
#use Cwd;
#use lib dirname(Cwd::abs_path($0)) . '/lib';
use KFO::lib;
use JSON;  # used for saving $db
use Time::HiRes; # used for usleep and sleep_ms
use utf8;
use feature 'unicode_strings';
use Data::Dumper;
use Encode;
use CHI;

#Print the data immediately. Don't wait for full buffer
$|++;

#binmode(STDOUT, ":utf8");

# process name
my $process_name                    = "pl-template";
my $version                         = 100;

my $name_org                        = $0;
my $process_name_org                = $0;
$0                                  = "perl $process_name VER $version";
my $process_name_safe               = $0;
$process_name_safe                  = eval{local $_ = $0; s/[\s\/]{1,}/-/g; s/\W/_/g; s/_{2,}/_/g; s/-{2,}/-/g; s/^[-_]|[-_]$//g; return $_};
my %argv                            = @ARGV;
my %config                          = ();
my $config                          = \%config;
my $db                              = {};
my $tmp                             = {};
my $tmp_1h                          = {};
my $cache                           = \%{$$db{'cache'}};

# init KFO::lib
debug("KFO::lib->new()", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 3;
my $lib = KFO::lib->new('config' => \%config);
$lib->config(           'config' => \%config);

# init $db
my $json_init                       = $lib->init_json();

# init config
init_config();

$config{'msg'}{'help'} = qq#$process_name_org ' --username="test-user" --password="vpn123" --comment="Cert comment" --file="cert.p12" '#;

# run the main code
print run_code();


sub run_code {
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
  $input{'validate-input-data'}   //= 0;
  $input{'validate-return-data'}  //= 1;
  $input{'debug'}                 //= 0;
  #$input{''}  //= 1;

  local $config{'log'}{$sub_name}{'enabled'}  = $input{'debug'} if $input{'debug'};
  local $config{'log'}{$sub_name}{'level'}    = $input{'debug'} if $input{'debug'};

  #validate input data start
  if ($input{'validate-input-data'} or $config{"val"}{'sub'}{'in'}){
    my @input_type = qw(  );
    foreach my $input_type (@input_type) {

      unless (defined $input{$input_type} and length $input{$input_type} > 0) {
        debug("missing input data for '$input_type'", "fatal", \[caller(0)] ) if $config{'log'}{'error'}{'enabled'} and $config{'log'}{'error'}{'level'} > 1;
        return 0;
      }
    }
  }
  #validate input data start

  #sub header end

  #sub main code start

  $return = "main code";

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

sub init_config {

  # config dir
  $config{'dir'}{'home'}              = "$ENV{'HOME'}/perl/$process_name_safe";
  $config{'dir'}{'tmp'}               = "$config{'dir'}{'home'}/tmp";
  $config{'dir'}{'mtime'}             = "$config{'dir'}{'home'}/mtime";
  $config{'dir'}{'log'}               = "$config{'dir'}{'home'}/log";
  $config{'dir'}{'data'}              = "$config{'dir'}{'home'}/data";
  $config{'dir'}{'config'}            = "$config{'dir'}{'home'}/config";
  $config{'dir'}{'lib'}               = "$config{'dir'}{'home'}/lib";
  $config{'dir'}{'code'}              = "$config{'dir'}{'home'}/code";

  # create dir
  foreach my $dir (keys %{$config{'dir'}}){$lib->create_dir($dir)}

  #JSON
  $config{'file'}{'database'}         = "$config{'dir'}{'data'}/database.json";
  $config{'json'}{'enabled'}          = 1;

  #Files
  $config{'file'}{'stdout'}           = "$config{'dir'}{'log'}/stdout.log";
  $config{'file'}{'stderr'}           = "$config{'dir'}{'log'}/stderr.log";


  debug("\$lib->get_json_file_to_hash();", 'warning', \[caller(0)]) if $config{'log'}{'warning'}{'enabled'} and $config{'log'}{'warning'}{'level'} > 1;
  $db = $lib->get_json_file_to_hash('file' => $config{'file'}{'database'}) if -f $config{'file'}{'database'};


  #Create tmp/data directory
  #create_dir($dir_tmp) unless -d $dir_tmp;
  $config{'run_init_dir'}             = 1;                            #0/1. Run init_dir();


  #Trunk log file if it's bigger than 10 MB
  #$lib->trunk_file_if_bigger_than_mb($file_debug,10);

  $config{'log'}{'debug'}             = {
    "enabled"       => 0,     #0/1
    'name'          => 'debug', 
    "level"         => 2,     #1-9
    "print"         => 1,     #Print to STDOUT
    "print-warn"    => 0,     #Print to STDERR
    "log"           => 0,     #Save to log file
    "file-fifo"     => 0,     #Create a fifo file for log
    "file-size"     => 100*1024*1024,    #MB max log file size
    "cmd"           => "",    #Run CMD if log. Variable: _LOG_
    "lines-ps"      => 10,    #Max lines pr second
    "die"           => 0,     #Die/exit if this type of log is triggered
    'api-kfo'       => 0,
    'mqtt'          => {
      "enabled"       => 0,     #0/1
      "topic"         => "$process_name_safe/log/__NAME__",
    },
  };

  $config{'log'}{'info'}              = {
    "enabled"       => 1,     #0/1
    'name'          => 'debug', 
    "level"         => 5,     #1-9
    "print"         => 1,     #Print to STDOUT
    "print-warn"    => 0,     #Print to STDERR
    "log"           => 1,     #Save to log file
    "file-fifo"     => 0,     #Create a fifo file for log
    "file-size"     => 100*1024*1024,    #MB max log file size
    "cmd"           => "",    #Run CMD if log. Variable: _LOG_
    "lines-ps"      => 10,    #Max lines pr second
    "die"           => 0,     #Die/exit if this type of log is triggered
    'api-kfo'       => 0,
    'mqtt'          => {
      "enabled"       => 0,     #0/1
      "topic"         => "$process_name_safe/log/__NAME__",
    },
  };

  $config{'log'}{'warning'}           = {
    "enabled"       => 1,     #0/1
    'name'          => 'debug', 
    "level"         => 5,     #1-9
    "print"         => 1,     #Print to STDOUT
    "print-warn"    => 0,     #Print to STDERR
    "log"           => 1,     #Save to log file
    "file-fifo"     => 0,     #Create a fifo file for log
    "file-size"     => 100*1024*1024,    #MB max log file size
    "cmd"           => "",    #Run CMD if log. Variable: _LOG_
    "lines-ps"      => 10,    #Max lines pr second
    "die"           => 0,     #Die/exit if this type of log is triggered
    'api-kfo'       => 0,
    'mqtt'          => {
      "enabled"       => 0,     #0/1
      "topic"         => "$process_name_safe/log/__NAME__",
    },
  };

  #debug("", "error", \[caller(0)] ) if $config{'log'}{'error'}{'enabled'};
  $config{'log'}{'error'}           = {
    "enabled"       => 1,     #0/1
    'name'          => 'debug', 
    "level"         => 5,     #1-9
    "print"         => 1,     #Print to STDOUT
    "print-warn"    => 0,     #Print to STDERR
    "log"           => 1,     #Save to log file
    "file-fifo"     => 0,     #Create a fifo file for log
    "file-size"     => 100*1024*1024,    #MB max log file size
    "cmd"           => "",    #Run CMD if log. Variable: _LOG_
    "lines-ps"      => 10,    #Max lines pr second
    "die"           => 0,     #Die/exit if this type of log is triggered
    'api-kfo'       => 0,
    'mqtt'          => {
      "enabled"       => 0,     #0/1
      "topic"         => "$process_name_safe/log/__NAME__",
    },
  };

  $config{'log'}{'fatal'}           = {
    "enabled"       => 1,     #0/1
    'name'          => 'debug', 
    "level"         => 5,     #1-9
    "print"         => 1,     #Print to STDOUT
    "print-warn"    => 0,     #Print to STDERR
    "log"           => 1,     #Save to log file
    "file-fifo"     => 0,     #Create a fifo file for log
    "file-size"     => 100*1024*1024,    #MB max log file size
    "cmd"           => "",    #Run CMD if log. Variable: _LOG_
    "lines-ps"      => 10,    #Max lines pr second
    "die"           => 0,     #Die/exit if this type of log is triggered
    'api-kfo'       => 0,
    'mqtt'          => {
      "enabled"       => 0,     #0/1
      "topic"         => "$process_name_safe/log/__NAME__",
    },
  };

  $config{'log'}{'sub::run_code'}     = {
    "enabled"       => 1,     #0/1
    'name'          => 'debug', 
    "level"         => 5,     #1-9
    "print"         => 1,     #Print to STDOUT
    "print-warn"    => 0,     #Print to STDERR
    "log"           => 1,     #Save to log file
    "file-fifo"     => 0,     #Create a fifo file for log
    "file-size"     => 100*1024*1024,    #MB max log file size
    "cmd"           => "",    #Run CMD if log. Variable: _LOG_
    "lines-ps"      => 10,    #Max lines pr second
    "die"           => 0,     #Die/exit if this type of log is triggered
    'api-kfo'       => 0,
    'mqtt'          => {
      "enabled"       => 0,     #0/1
      "topic"         => "$process_name_safe/log/__NAME__",
    },
  };


  # check for debug in input argv
  if (defined $argv{'debug'}) {
    $config{'log'}{'debug'}{'enabled'}  = $argv{'debug'};
    $config{'log'}{'debug'}{'level'}    = $argv{'debug'};
  }

  my $sub_name = "main";



  #foreach my $sig (keys %SIG){
  foreach my $sig ('TERM', 'INT', 'HUP'){ $SIG{$sig} = \&KFO::lib::ctrl_c; }
  $SIG{'CHLD'}                        = "IGNORE";



}

sub sub_template {
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
  $input{'validate-input-data'}   //= 1;
  $input{'validate-return-data'}  //= 1;
  $input{'debug'}                 //= 0;
  #$input{''}  //= 1;

  local $config{'log'}{$sub_name}{'enabled'}  = $input{'debug'} if $input{'debug'};
  local $config{'log'}{$sub_name}{'level'}    = $input{'debug'} if $input{'debug'};

  #validate input data start
  if ($input{'validate-input-data'} or $config{"val"}{'sub'}{'in'}){
    my @input_type = qw( name );
    foreach my $input_type (@input_type) {

      unless (defined $input{$input_type} and length $input{$input_type} > 0) {
        debug("missing input data for '$input_type'", "fatal", \[caller(0)] ) if $config{'log'}{'error'}{'enabled'} and $config{'log'}{'error'}{'level'} > 1;
        return 0;
      }
    }
  }
  #validate input data start

  #sub header end

  #sub main code start

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


