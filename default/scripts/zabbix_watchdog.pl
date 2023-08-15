#!/usr/bin/perl
#

# 2022.08.15

BEGIN{push @INC,"/usr/share/zabbix/bin/perl-5.10.1/lib"}


if (defined $ARGV[0] and $ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}


use strict;
use warnings;
use LWP::Simple;

my $file_zabbix_conf = "/usr/share/zabbix/repo/files/auto/zabbix_agentd.conf";
my $file_zabbix_url = "http://zabbix.kjartanohr.no/zabbix/repo/default/files/zabbix_agentd.conf";
my $timeout = 30;

my $code;
my $restart = 1;

my $debug = 1;

my %config;

$config{'sleep'}      = {
  'main-start'    => 5,
  'main-end'      => 60,

  'validate-end'  => 10,

  'download-file-url-check-end' => 5,
  'download-file-remote-size'   => 5,
  'download-file-download-alarm'      => 5,
  'download-file-download-failed'      => 5,
  'download-file-download'      => 5,
};

$config{'log'}{'debug'}       = {
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

  'mqtt'          => {
    "enabled"       => 1,     #0/1
    "topic"         => 'rtl/log/__NAME__',
  },
};

$config{'log'}{'info'}       = {
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


my $file_curl                   = whereis('curl', 'curl_cli');
my $useragent                   = get_local_id();
my $hostname                    = `hostname`;
#my $curl_options               = " -v -k --trace-time --create-dirs --location --user-agent '$useragent' ";

# debug: main::download_file Could not find 200 OK in output, retry 3/60: curl: option --verbose-extended: is unknown

my @curl_options                = (
  "-vvv",                                     #Extra verbose
  #"--verbose-extended",                      #Show HTTP header and body (Checkpoint option). Denne virker ikke etter R81.X
  #"--dns-servers",                           #<addresses> DNS server addrs to use
  "--insecure",                               #Allow insecure server connections when using SSL
  "--ipv4",                                   #Resolve names to IPv4 addresses
  "--keepalive-time 60",                      #<seconds> Interval time for keepalive probes
  #"--limit-rate 10000",                       #Limit transfer speed to RATE",
  #"--local-port 30000-30100",                 #Force use of RANGE for local port numbers
  "--location",                               #Follow redirects
  "--max-redirs 10",                          #Maximum number of redirects allowed
  "--max-time 600",                           #Maximum time allowed for the transfer
  "--progress-bar",                           #Display transfer progress as a bar
  "--referer 'http://installer_agent.sh'",    #Referrer URL
  "--remote-time",                            #Set the remote file's time on the local output
  #"--resolve zabbix.kjartanohr.no:80:92.220.216.51",        #Resolve the host+port to this address
  "--retry 10",                               #Retry request if transient problems occur
  #"--stderr",                                #Where to redirect stderr
  "--trace-time",                             #Add time stamps to trace/verbose output
  "--create-dirs",
  "--location",
  "--user-agent '$useragent'",
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
debug("", 'warning', \[caller(0)]) if $config{'log'}{'warning'}{'enabled'} and $config{'log'}{'warning'}{'level'} > 1;

#Static DNS
my %domain                      = (
  "zabbix.kjartanohr.no"  => "92.220.216.51",
  "github.com"            => "140.82.121.4",
  "www.github.com"        => "140.82.121.4",
);

my %dns_server                  = (
  "92.220.216.51"         => 1,               #Backup DNS server zabbix repo server
  "8.8.8.8"               => 1,               #Google DNS
  "1.1.1.1"               => 1,               #CloudFlare DNS
  "127.0.0.1"             => 1,               #Try the local dns server
);




print "Checking if zabbix_agentd is running\n";

if (is_process_running("zabbix_agentd")) {
  print "Agent is running\n";
}
else {
  print "Agent not running\n";
  print "Starting zabbix agent\n";
  system "/usr/share/zabbix/sbin/zabbix_agentd";
}

# TOOD 2023-04-18 12:19:45
# # replace this with something better
run("mkdir -p /usr/local/etc/");
run("rm -f /usr/local/etc/zabbix_agentd.conf") if -f "/usr/share/zabbix/repo/files/auto/zabbix_agentd.conf";
run("ln -s $file_zabbix_conf /usr/local/etc/zabbix_agentd.conf");
run("ln -s $file_zabbix_conf /usr/share/zabbix/conf/zabbix_agentd.conf");
run("ln -s /usr/share/zabbix/bin/perl-5.10.1/perl /usr/bin/");
run("ln -s /usr/share/zabbix/bin/perl-5.10.1/perl /bin/");


MAIN:
while (1) {

  sleep $config{'sleep'}{'main-start'};

  VALIDATE:
  foreach my $try (1 .. 3){

    if (`grep "#END OF FILE" $file_zabbix_conf`){
      print "Config file downloaded and looks right\n";
      $restart = 0;
      last VALIDATE;

    }
    else {
      print "Config file downloaded and looks wrong. Can't find #END OF FILE at the end\n";
      print "Retry download\n";
      download_file($file_zabbix_url, 'filename' => $file_zabbix_conf);
      print "code: '$code'\n";

      sleep $config{'sleep'}{'main-start'};
      print $file_zabbix_conf;
      $restart = 1;
    }
  }

    if ($restart == 1){
      print "Config downloaded and updatet\n";

      print "Stopping zabbix agent\n";
      system "pkill -9 zabbix_agentd";

      print "Starting zabbix agent\n";
      system "/usr/share/zabbix/sbin/zabbix_agentd";

    }

    print "Checking if zabbix_agentd is running\n";

  foreach my $try (1 .. 3){
    if (is_process_running("zabbix_agentd")) {
      print "Agent is running\n";
      last;
    }
    else {
      print "Agent not running\n";
      print "Starting zabbix agent\n";
      system "/usr/share/zabbix/sbin/zabbix_agentd";
    }
  }

  sleep $config{'sleep'}{'main-end'};
}

sub is_process_running {
  my $name = shift || die "Need a name to check for";

  my $agent_running = `pgrep "$name"`;
  chomp $agent_running;

  return $agent_running;

}

sub run {
  debug(((caller(0))[3])." Start\n");
  debug(((caller(0))[3])." Input: ".join ", ", @_);
  my $cmd                       = shift || die "Did not get any CMD";
  my %input                     = @_;
  my $cmd_out = "";

  $input{'pause'}             ||= 0;
  $input{'ask'}               ||= 0;
  $input{'timeout'}           ||= 60;
  $input{'stop_if_found'}     ||= "";
  $input{'stop_if_not_found'} ||= "";
  $input{'stop_msg'}          ||= "";
  $input{'print'}             ||= $debug;
  $input{'retry'}             ||= 3;
  $input{'dry_run'}           ||= 0;


  #print $clear if $input{'clear'};

  if ($input{'ask'}) {
    debug(((caller(0))[3])." \$input{'ask'} is true\n");
    my $msg = "$input{'ask'}\n";

    ask(
      $msg,
      answer  => "Y",
      print   => 1,
    );
  }


  if ($input{'dry_run'} == 0) {
    debug(((caller(0))[3])." \$input{'dry_run'} is false\n");
    eval {
      local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
      alarm $input{'timeout'};

      debug(((caller(0))[3])." Running command: $cmd\n");
      open my $cmd_fh, "-|", "$cmd 2>&1" or die "Can't run $cmd: $!";
      while (<$cmd_fh>) {
        print if $input{'print'};
        $cmd_out .= $_;
      }
      #$cmd_out = `$cmd 2>&1`;

      alarm 0;
    };
  }

  if ($input{'print'}) {
    debug(((caller(0))[3])." \$input{'print'} is true\n");
    print "Running command: \"$cmd\" with timeout: $input{'timeout'}\n\nCMD START\n$cmd_out\nCMD END\n\n";
  }

  if ($input{'stop_if_found'}) {
    debug(((caller(0))[3])." \$input{'stop_if_found'} is true\n");
    if ($cmd_out =~ /$input{'stop_if_found'}/) {
      my $msg;

      if ($input{'stop_msg'}) {
        print "Stop trigger word found in output: \"$input{'stop_if_found'}\"\n$input{'stop_msg'}\n";
      }
      else {
        print "Found $input{'stop_if_found'} in command output. Exiting\n";
      }
      exit;
    }
  }

  pause() if $input{'pause'};

  debug($cmd_out);

  return $cmd_out;
}

sub pause {
  my $msg = shift || "Press ENTER to continue\n";

  ask($msg);
}

sub ask {
  my $msg             = shift || die "Missing question";
  my %input           = @_;

  $input{'answer'}  ||= 0;
  $input{'timeout'} ||= 0;
  $input{'print'}   ||= 0;

  my $answer;

  #print $clear if $input{'clear'};


  if ($input{'answer'}) {
    $msg = "$msg\nCTRL+C to cancel. Press $input{'answer'} to continue: ";
  }
  else {
    $msg = "$msg\nCTRL+C to cancel. Press ENTER to continue";
  }

  print $msg;

  open my $tty, "<", "/dev/tty" or die "Cant open /dev/tty: $!";

  unless ($input{'answer'}) {
    $answer = <$tty>;
    return;
  }

  while (<$tty>){
    chomp;
    next unless $_;
    $answer = $_;
    last;
  };

  if ($input{'answer'}) {
    if ($answer ne $input{'answer'}) {
      print "You answered: \"$answer\". Correct answer was $input{'answer'}. Exiting\n";
      exit;
    }
    else {
      print "You answered: \"$answer\". Continuing\n";
    }
  }

  print "You answered: $answer\n" if $input{'print'};

  return $answer;

}

sub get_file_size_remote {
  my $url = shift || die "Need a URL to check file size\n";

  #Get the remote file size
  my $cmd_curl_remote_header = "$file_curl -I $curl_options $url 2>&1";
  debug("CMD curl: $cmd_curl_remote_header");

  my $out_curl_remote_header = `$cmd_curl_remote_header`;

  my $file_remote_header = $out_curl_remote_header;

  unless (validate_data($file_remote_header, "$cmd_curl_remote_header\n$file_remote_header")){
    die "Data validation failed for curl get header";
  }

  debug("File remote header: $file_remote_header");

  my ($file_remote_size) = $file_remote_header =~ /Content-Length: (\d{1,})/i;
  unless (validate_data($file_remote_size, "remote file size")) {
    die "Data validation failed for Content-Length";
  }

  #my ($file_remote_mtime) = $file_remote_header =~ /Date: (.*)/i;
  #unless (validate_data($file_remote_mtime, "remote mtime")) {
  #  die "Data validation failed for mtime";
  #}

  return $file_remote_size;
}


sub get_file_size_local {
  my $file = shift || die "Need a filename to check file size\n";

  if (not -f $file) {
    debug("Could not find the local $file to check the file size\n");
    return 0;
  }

  debug("Found a matching local file: $file\n");

  #Get the size of the local file
  my $file_size = (stat($file))[7];

  my $status = validate_data($file_size, "stat coult not get local file size");
  if ($status) {
    debug("validate data for \$file_size is OK. File $file size $file_size");
  }
  else {
    debug("validate data for \$file_size FAILED. No data found.");
    return;
  }

  return $file_size;
}

sub validate_data {
  my $data  = shift;
  my $msg   = shift || "unknown error";
  my $die   = shift || "";

  if (defined $data and length $data > 0) {
    debug("Data found: $data\n");
    return 1;
  }
  else {
    my $msg_complete = "Missing data for $msg " if $debug;

    die "$msg_complete\n" if $die;

    print $msg_complete;

    return 0;
  }
}

sub download_file {
  debug(((caller(0))[3])." Start\n");

  my $url                 = shift || die "Missing URL";
  my %input               = @_;

  debug(((caller(0))[3])." INPUT: URL: $url, ".join "\n", %input);

  $input{'filename'}    || die "Need a filename";
  $input{'retry'}       ||= 100;
  $input{'timeout'}     ||= 600;

  #make $curl_options local. Changes will live inside this sub
  my $curl_options_local   = $curl_options;

  debug(((caller(0))[3])." Url: $url");
  debug(((caller(0))[3])." Filename: $input{'filename'}");
  debug(((caller(0))[3])." Retry: $input{'retry'}");
  debug(((caller(0))[3])." Timeout: $input{'timeout'}");

  my $filename = $input{'filename'};



  #Validate hostname before running curl START

  #Parse and validate URL
  my ($proto, $domain, $path) = parse_url('url' => $url);

  debug("Resolving hostname from URL\n");
  unless (check_dns_resolve($domain)) {
    warn "Could not resolve hostname $domain. Check your DNS settings";
    warn "Adding static IP-addresses to curl";
    my $curl_dns        = get_curl_static_dns();
    $curl_options_local = "$curl_dns $curl_options";
  }


  #Validate hostname before running curl END

  my $cmd_curl_download   = qq#$file_curl --output "$input{'filename'}" $curl_options_local "$url" #;
  my $cmd_curl_header     = qq#$file_curl --head $curl_options_local "$url"#;
  my $url_check_count_max = 60;


  if ($input{'filename'}) {
    debug(((caller(0))[3])." Found input filename: $filename\n");
    my ($dir) = $filename =~ /(.*)\//;

    if (not -d $dir) {
      my $cmd_mkdir = "mkdir -p $dir";
      debug(((caller(0))[3])." The directory path for the filename does not exist. Will create the directory path: $cmd_mkdir\n");
      run($cmd_mkdir);
    }

  }

  #if (not $input{'filename'}) {
  #  debug(((caller(0))[3])." No filename given. Will extract it from URL\n");
  #  $input{'filename'} = get_filename_from_url();

  #  die "Could not extract filename from url: $url" unless $input{'filenmae'};
  #  debug(((caller(0))[3])." Filename is set to $input{'filename'}\n");
  #}

  debug(((caller(0))[3])." Checking if URL is reachable: $url\n");
  my $url_check_count = 0;
  URL_CHECK:
  while ($url_check_count < $url_check_count_max) {
    $url_check_count++;

    if ($url_check_count > $url_check_count_max) {
      debug(((caller(0))[3])." Max retry is reached. Try again when $url is reachable\nYou can check with the command: $cmd_curl_header\n");
      warn "Failed to download $url";
      return;
    }

    debug(((caller(0))[3])." Command: $cmd_curl_header\n");
    my $cmd_curl_header_out = `$cmd_curl_header 2>&1`;

    debug("curl header: $cmd_curl_header_out");

    if ($cmd_curl_header_out =~ /200 OK/) {
      debug(((caller(0))[3])." HTTP 200 OK. This URL is valid\n");
      last URL_CHECK;
    }
    else {
      debug(((caller(0))[3])." Could not find 200 OK in output, retry $url_check_count/$url_check_count_max: $cmd_curl_header_out\n");
      sleep $config{'sleep'}{'download-file-url-check-end'};
      next URL_CHECK;
    }
  }

  debug(((caller(0))[3])." Checking remote file size\n");
  my $file_remote_size = get_file_size_remote($url);

  unless ($file_remote_size) {
    debug(((caller(0))[3])." Could not get remote file size\n");
    sleep $config{'sleep'}{'download-file-file-remote-size'};
    return;
  }
  debug(((caller(0))[3])." Got remote file size: $file_remote_size\n");

  if (-f $input{'filename'}) {
    debug(((caller(0))[3])." Checking local file size for file $input{'filename'}. URL $url\n");
    my $file_local_size = get_file_size_local($input{'filename'});
    die "Could not get local file size. Exiting" unless $file_local_size;
    debug(((caller(0))[3])." Got local file size: $file_local_size\n");

    debug(((caller(0))[3])." Checking if remote and local file size is the same: remote: $file_remote_size == local: $file_local_size\n");
    if ($file_remote_size == $file_local_size) {
      debug(((caller(0))[3])." File size is the same. No need to download\n");
      return $input{'filename'};
    }
  }

  debug(((caller(0))[3])." Will try to download $url\n");
  my $cmd_curl_download_out;
  my $url_download_count = 0;
  URL_DOWNLOAD:
  while ($url_download_count < $url_check_count_max) {
    $url_download_count++;

    eval {
      local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required

      debug(((caller(0))[3])." Setting timeout in perl code for $input{'timeout'} seconds\n");
      alarm $input{'timeout'};

      debug(((caller(0))[3])." Running command: $cmd_curl_download\n");
      $cmd_curl_download_out = run("$cmd_curl_download 2>&1");
      debug("CMD curl download file: $cmd_curl_download_out");

      debug(((caller(0))[3])." Resetting alarm\n");
      alarm 0;
    };

    if ($@) {
      debug(((caller(0))[3])." Timeout for download reached. next\n");
      sleep $config{'sleep'}{'download-file-download-alarm'};
      next URL_DOWNLOAD;
    }

    my $file_local_size;
    if (-f $input{'filename'}) {
      debug(((caller(0))[3])." Checking local file size for file $input{'filename'}. URL $url\n");
      $file_local_size = get_file_size_local($input{'filename'});
      die "Could not get local file size. Exiting" unless $file_local_size;
      debug(((caller(0))[3])." Got local file size: $file_local_size\n");
    }
    else {
      debug("Local file not found. No need to check file size for $input{'filename'}. Download Failed. next");
      sleep $config{'sleep'}{'download-file-download-failed'};
      next URL_DOWNLOAD;
    }

    debug(((caller(0))[3])." Checking if remote and local file size is the same: remote: $file_remote_size == local: $file_local_size\n");
    if ($file_remote_size == $file_local_size) {
      debug(((caller(0))[3])." File size is the same. Download OK\n");
      return $input{'filename'};
    }
    else {
      debug(((caller(0))[3])." File size is NOT the same. Retry\n");
      unlink $input{'filename'};
      next URL_DOWNLOAD;
    }
  }
}

sub get_local_id {
  my $sub_name = (caller(0))[3];
  debug("start", $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 1;
  debug("input: ".Dumper(@_), $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 3;

  my $id;

  my @cmd = (
    #qq#grep search /etc/resolv.conf | awk '{print $2}'#,
    #perl -ne 'next if not /search/; @s=split/\s/; print $s[1]'  /etc/resolv.conf
    "hostname -y",
    "hostname",
    #"uname -a",
    #"fw ver",
    #"w",
    #"whoami",
  );

  foreach my $cmd (@cmd) {
    debug(((caller(0))[3])." Running command $cmd\n");
    my $cmd_out = run($cmd, 'desc' => "$sub_name. create local id $cmd");
    chomp $cmd_out;
    #debug(((caller(0))[3])." Output from command: $cmd_out\n");

    next if $cmd_out =~ /command not found/;

    #$cmd_out =~ s/\n|\r/ /g;
    #$cmd_out =~ s/\W/ /g;

    #debug(((caller(0))[3])." Output from command after changes: $cmd_out\n");

    $id .= "$cmd_out-";
  }

  #debug(((caller(0))[3])." Returning $id\n");
  return $id;
}


sub get_filename_from_url {
  debug(((caller(0))[3])." Start\n");
  my $url = shift || die "Need a URL to extract filename from";

  my ($filename) = $url =~ /.*\/(.*)/;

  if ($filename) {
    debug(((caller(0))[3])." Found filename: $filename\n");
    return $filename;
  }
  else {
    debug(((caller(0))[3])." Could not extract filename from $url\n");
    return;
  }
}

sub check_dns_resolve {
  debug(((caller(0))[3])." Start\n");

  my $hostname = shift || die "Need a hostname to resolve";
  debug(((caller(0))[3])." Input hostname: $hostname\n");

  my $cmd_dig = "dig +timeout=10 $hostname";
  debug(((caller(0))[3])." Running command: $cmd_dig\n");

  my $cmd_dig_out = run($cmd_dig);
  debug(((caller(0))[3])." Output from command: $cmd_dig_out\n");

  debug(((caller(0))[3])." Looking for: status: NOERROR\n");
  if ($cmd_dig_out =~ /status: NOERROR/) {
    debug(((caller(0))[3])." Resolve OK\nOutput: $cmd_dig_out");
    return 1;
  }
  else {
    debug(((caller(0))[3])." Resolve FAILED. Output: $cmd_dig_out\n");
    return 0;
  }
}

sub debug {
  return unless $debug;
  @_ = "No error message given" unless @_;

  print "debug: ".join ", ", @_;
  print "\n";
}

sub whereis {
  my @files =  @_ or die "Need a file for whereis";

  foreach my $file (@files) {
    debug("Looking for file $file");

    my $out = `whereis $file`;
    chomp $out;

    my ($path) = $out =~ /: (.*)/;

    if ($path) {
      debug("Found file $file. $path");
      return $path;

    }
  }

  foreach my $file (@files) {
    debug("Looking for file $file");

    foreach my $find_file (`find / -name $file`) {
      next unless $find_file;
      chomp $find_file;
      debug("Found file $file. $find_file");
      return $find_file;

    }

  }


  return;
}

sub array_to_string {
  my %input = @_;
  my $string;

  foreach my $data (@{$input{'array'}}) {
    $string .= "$data ";
  }

  return $string;
}

sub get_curl_static_dns {
  my %input = @_;
  my $string;

  foreach my $host (keys %domain) {
    next unless $host;
    my $ip = $domain{$host};

    #"--resolve zabbix.kjartanohr.no:80:92.220.216.51",        #Resolve the host+port to this address
    $string .= "--resolve '$host:80:$ip' ";
    $string .= "--resolve '$host:443:$ip' ";
  }

  return $string;
}


sub get_url {
  my $url = shift || die "Need a human here. Need a URL to download from";

  #Run the command fw ver to get the installed version
  my $fw = `fw ver`;
  unless ($fw =~ /software version/){
    print "Need a human here. Could not get FW version from fw ver";
    exit;
  }

  #Get the Check Point version from fw ver
  my ($ver) = $fw =~ / version (.*?) /;
  unless ($ver){
    print "Need a human here. Could not extract FW version from fw ver";
    exit;
  }

  #Lowercase the version (the R)
  $ver = lc $ver;

  #The URL for the repo
  $url =~ s/__VER__/$ver/g;

  return $url;

}

sub parse_input {
  my $search  = shift;
  my @input   = @_;

  foreach (@input) {
    next unless /$search/;
    print "Found $search in input\n" if $debug;
    return $_;
  }
}


sub install_rpm {



}





#my ($proto, $domain, $path) = parse_url($url);
sub parse_url {

  my %input = @_;

  unless (defined $input{'url'}) {
    die "Missing input data 'url'";
  }

  print "URL: $input{'url'}\n";

  my ($proto, $domain, $path) = $input{'url'} =~ /^(h.*?):\/\/(.*?)(\/.*)/;

  #Validate protocol
  if ($proto) {
    print "Protocol: $proto\n";
  }
  else {
    die "Missing protocol from URL: $input{'url'}";
  }

  #Validate domain
  if ($domain) {
    print "domain: $domain\n";
  }
  else {
    die "Missing domain from URL: $input{'url'}";
  }

  #Validate path
  if ($path) {
    print "path: $path\n";
  }
  else {
    die "Missing path from URL: $input{'url'}";
  }


  return ($proto, $domain, $path);
}



#END OF FILE

