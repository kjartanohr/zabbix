#!/usr/bin/perl5.32.0
BEGIN{

  #init global pre checks
  #init_local_begin('version' => 1);

  #Global var
  our %config;

  require "/usr/share/zabbix/repo/files/auto/lib.pm";
  require "/usr/share/zabbix/repo/scripts/auto/lib-2022.10.03.pm";

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

our $debug                    = 0;
my $version                   = 100;
my $process_name_org          = $0;
my $process_name              = "curl test";
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

my @curl_options                = (
  "-vvv",                                     #Extra verbose
  #"--verbose-extended",                       #Show HTTP header and body (Checkpoint option) # ikke supportert i R80.10
  #"--dns-servers",                           #<addresses> DNS server addrs to use
  "--insecure",                               #Allow insecure server connections when using SSL
  "--ipv4",                                   #Resolve names to IPv4 addresses
  "--keepalive-time 60",                      #<seconds> Interval time for keepalive probes
  #"--limit-rate 10000",                       #Limit transfer speed to RATE",
  "--local-port 30000-30100",                 #Force use of RANGE for local port numbers
  "--location",                               #Follow redirects
  "--max-redirs 10",                          #Maximum number of redirects allowed
  "--max-time 600",                           #Maximum time allowed for the transfer
  "--progress-bar",                           #Display transfer progress as a bar
  "--referer 'url_check.pl'",                 #Referrer URL
  "--remote-time",                            #Set the remote file's time on the local output
  #"--resolve zabbix.kjartanohr.no:80:92.220.216.51",        #Resolve the host+port to this address
  "--retry 10",                               #Retry request if transient problems occur
  #"--stderr",                                #Where to redirect stderr
  "--trace-time",                             #Add time stamps to trace/verbose output
  "--create-dirs",
  "--location",
  "--user-agent '$process_name'",
  "--speed-limit 10000",                      #Stop transfers slower than this
  "--speed-time 10",                          #Trigger 'speed-limit' abort after this time
  #"--header 'Host: zabbix.kjartanohr.no'",    #Pass custom header(s) to server
  "--url",                                    #URL to work with

  #Not supported
  #"--retry-connrefused 1",                    #Retry on connection refused (use with --retry)
  #"--fail-early",                            #NOT SUPPORTED. Fail on first transfer error, do not continue
  #"--false-start",                           #NOT SUPPORTED. Enable TLS False Start
  #"--styled-output",                         #Enable styled output for HTTP headers
  #"--tcp-fastopen",                          #NOT SUPPORTED. Use TCP Fast Open
);

my $curl_options                = array_to_string('array' => \@curl_options);




#Get default config
our %config                     = get_config();

#log config
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
  "enabled"       => 1,     #0/1
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
    "enabled"       => 1,     #0/1
    "topic"         => 'rtl/log/__NAME__',
  },
};
$debug                    =  $config{'log'}{'debug'}{'enabled'};

$config{'log'}{'info'}       = {
  "enabled"       => 1,     #0/1
  'name'          => 'debug',
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
  'name'          => 'debug',
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
  'name'          => 'debug',
  "level"         => 5,     #1-9
  "print"         => 1,     #Print to STDOUT
  "print-warn"    => 0,     #Print to STDERR
  "log"           => 1,     #Save to log file
  "file"          => "$config{'dir'}{'log'}/fatal.log", #Log file
  "file-fifo"     => 0,     #Create a fifo file for log
  "file-size"     => 100*1024*1024,    #MB max log file size
  "cmd"           => "",    #Run CMD if log. Variable: _LOG_
  "lines-ps"      => 10,    #Max lines pr second
  "die"           => 1,     #Die/exit if this type of log is triggered

  'mqtt'          => {
    "enabled"       => 1,     #0/1
    "topic"         => 'rtl/log/__NAME__',
  },
};

debug("\@ARGV: ".Dumper(@ARGV),  'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
%argv = KFO::lib::parse_command_line('argv' => \@ARGV, 'config' => \%config);
debug("\%argv: ".Dumper(%argv), 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

#Set debug flag if found on command line
if (defined $argv{'debug'}){
  $debug                              = $argv{'debug'};
  $config{'log'}{'debug'}{'level'}    = $argv{'debug'};
}


#legacy debug on/off
$debug = $config{'log'}{'debug'}{'level'} if $config{'log'}{'debug'}{'enabled'};


#Init config
$config{'init'}{'is_cp_gw'}     = 0;
$config{'init'}{'is_cp_mgmt'}   = 0;
$config{'init'}{'is_cp_gw'}     = 0;
$config{'init'}{'cpu_count'}    = 0;
$config{'init'}{'cpu_idle'}     = 0;

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
#init_global_after_config('version' => 1);

#End of standard header

#print Dumper %config;

#Fork a child and exit the main script
fork_and_exit( 'version' => 1, 'stdout' => $config{'file'}{'stdout'}, 'stderr' => $config{'file'}{'stderr'}) if $config{'init'}{'fork'} and not $config{'log'}{'debug'}{'enable'};
#Eveything after here is the child


#main code START

main_code();


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

  debug("\$argv{'url'}: $argv{'url'}", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  my $cmd_curl = qq# time curl_cli -k --connect-timeout 10 --show-error --verbose-extended -vvv --url "$argv{'url'}" 2>&1#;
  debug("\$cmd_curl: '$cmd_curl'", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

  my $data = run_cmd({
    'cmd'             => $cmd_curl,
    'return-type'     => 's',
    'vsid'            => $argv{'vsid'},
    'refresh-time'    => 60,
    'timeout'         => 20,
  });

=pod
[Expert@gw-cp-kfo:0]# time curl_cli -k -vvv --connect-timeout 10 vg.no
* Rebuilt URL to: vg.no/
*   Trying 195.88.55.16...
* TCP_NODELAY set
* Connected to vg.no (195.88.55.16) port 80 (#0)
< HTTP/1.1 301 Moved
< Date: Wed, 07 Dec 2022 15:01:47 GMT
< Server: Varnish
< X-Varnish: 311120344
< location: https://www.vg.no/
< Content-Length: 0
< Connection: keep-alive
<
* Connection #0 to host vg.no left intact

real    0m0.041s
user    0m0.012s
sys     0m0.003s


Connected to www.vg.no
HTTP/1.1 200 OK

=cut

  my $hash_ref = {};

  print $data;


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

