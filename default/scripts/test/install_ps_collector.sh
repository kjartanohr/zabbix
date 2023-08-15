#!/usr/bin/perl_mini
use warnings;
use strict;
use Data::Dumper;

#HOST="zabbix.kjartanohr.no";
#IP="92.220.216.51";
#CURL="curl_cli -vvv -k -s --referer 'http://installer_agent.sh' --resolve $HOST:80:$IP --resolve $HOST:443:$IP";
#test -f /usr/bin/perl_mini || echo "Missing perl.    Downloading"; $CURL --url "http://$HOST/zabbix/repo/default/files/perl" -o /usr/bin/perl_mini ; chmod +x /usr/bin/perl_mini
#test -f /tmp/lib.pm        || echo "Missing lib.pm.  Downloading"; $CURL --url "http://$HOST/zabbix/repo/default/files/lib.pm" -o /tmp/lib.pm

#/usr/bin/perl_mini -e 'use warnings; use strict; print "Script starting\n"; my $dry_run = 0; my $clear = `clear`; my $code = join "",<STDIN>; eval $code; print $@ if $@' <<'EOF'
#
##START OF MAIN SCRIPT


my $file_perl                   = "/usr/bin/perl_mini";

my $dir_tmp                     = "/tmp/zabbix/ps-cli_collector";

my $file_curl                   = whereis('curl', 'curl_cli');
my $useragent                   = get_local_id();

my @curl_options                = (
  "-vvv",                                     #Extra verbose
  "--verbose-extended",                       #Show HTTP header and body (Checkpoint option)
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

my $dns_test                    = "zabbix.kjartanohr.no";

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

my $url_cli_collector           = "http://zabbix.kjartanohr.no/zabbix/repo/default/files/ps/cli_collector";
my $file_cli_collector          = "$dir_tmp/cli_collector";

my $debug                       = 1;
my $dry_run                     = 0;

die "\n\nFATAL. COULD NOT FIND CURL BINARY.\nSend an email to Kjartan Flåm Ohr and report this.\n" unless $file_curl;
debug("Found curl binary $file_curl\n");

debug("Checking if DNS works\n");
unless (check_dns_resolve($dns_test)) {
  warn "Could not resolve hostname $dns_test. Check your DNS settings";
  warn "Adding static IP-addresses to curl";
  my $curl_dns  = get_curl_static_dns();
  $curl_options = "$curl_dns $curl_options";
}

debug("Creating directory $dir_tmp\n");
run("mkdir -p $dir_tmp") unless -d $dir_tmp;

#debug("Download $url_cli_collector\n");
#download_file($url_cli_collector, filename => $file_cli_collector);

run("chmod +x $file_cli_collector");

#Return all MGMT ID's
my @mds_id = run_mds_discovery();
#print Dumper @mds_id;
debug(((caller(0))[3])."\@mds_id: ".join(", ", @mds_id)."\n");

foreach my $mds_id (@mds_id) {
  debug(((caller(0))[3])." foreach \@mds_id. \$mds_id: $mds_id\n");
  my @policy_id = run_policy_discovery('id' => $mds_id);

  foreach my $policy_id (@policy_id) {
    my $file = run_cli_collector('mds-id' => $mds_id, 'policy-id' => $policy_id);
  }
}


#END OF MAIN SCTIPT

sub run {
  debug(((caller(0))[3])." Start\n");
  debug(((caller(0))[3])." Input: ".join ", ", @_);
  my $cmd                       = shift || die "Did not get any CMD";
  my %input                     = @_;
  my $cmd_out = "Output from command: $cmd\n";

  $input{'pause'}             ||= 0;
  $input{'ask'}               ||= 0;
  $input{'timeout'}           ||= 10;
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
      open my $cmd_fh, "-|", $cmd or die "Can't run $cmd: $!";
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
  validate_data($file_remote_header, "$cmd_curl_remote_header\n$file_remote_header") || return;

  debug("File remote header: $file_remote_header");

  my ($file_remote_size) = $file_remote_header =~ /Content-Length: (\d{1,})/i;
  validate_data($file_remote_size, "remote file size") || return;

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

  if ($data) {
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
  $input{'timeout'}     ||= 120;

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
      sleep 1;
      next URL_CHECK;
    }
  }

  debug(((caller(0))[3])." Checking remote file size\n");
  my $file_remote_size = get_file_size_remote($url);

  unless ($file_remote_size) {
    debug(((caller(0))[3])." Could not get remote file size\n");
    sleep 1;
    next URL_CHECK;
  }
  debug(((caller(0))[3])." Got remote file size: $file_remote_size\n");


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
      debug(((caller(0))[3])." Timeout for download reached. sleep 1. next\n");
      sleep 1;
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
  debug(((caller(0))[3])." Start\n");
  my $id;

  my @cmd = (
    "hostname",
    "uname -a",
    "fw ver",
    "w",
    "whoami",
  );

  foreach my $cmd (@cmd) {
    debug(((caller(0))[3])." Running command $cmd\n");
    my $cmd_out = `$cmd`;
    chomp $cmd_out;
    debug(((caller(0))[3])." Output from command: $cmd_out\n");

    next if $cmd_out =~ /command not found/;

    $cmd_out =~ s/\n|\r/ /g;
    $cmd_out =~ s/\W/ /g;

    debug(((caller(0))[3])." Output from command after changes: $cmd_out\n");

    $id .= "$cmd_out ";
  }

  debug(((caller(0))[3])." Returning $id\n");
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

  my $cmd_dig = "dig +timeout=2 $hostname";
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
    print "Protocol: $domain\n";
  }
  else {
    die "Missing domain from URL: $input{'url'}";
  }

  #Validate path
  if ($path) {
    print "Protocol: $path\n";
  }
  else {
    die "Missing path from URL: $input{'url'}";
  }


  return ($proto, $domain, $path);
}

#EOF


sub run_mds_discovery {

  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  my %input   = @_;
  my @id;

  #CLI collector

  #Laste ned
  #Kjøre på MGMT
  #Start, finn siste tall
  #foreach 1 .. siste tall
  #

=pod
  echo -e "2\n1\n"

  [Expert@cp-manager:0]# echo -e "2\n1\n" | ./cli_collector
  Wellcome to Professional Services CLI Collector
  Please provide the following information in order to collect the required data
  NOTE: The tool is based on log-indexes, please make sure that you have enough space to store logs for the desired period

  Checking if Multi-Domain

  Domain Selection
  1. ADM
  2. ADM-INET
  3. BIB
  4. BK-VALG
  5. BKSKY
  6. BRANN
  7. BYGG
  8. CACTUS
  9. DSM
  10. ELEV
  11. EXT-BRANN
  12. ext-cluster
  13. GJEST
  14. HELSE
  15. HUB
  16. INET
  17. int-cluster
  18. internet-test
  19. MOBILE
  20. MOBILE-TEST
  21. PARTNER
  22. PRINT
  23. TECH
  24. U-HELSE
  25. U-INET
  26. vsx-clusters
  27. WIFI
  28. X-HELSE
  29. X-INET
  Please enter your choice!:
  Performing login to ADM-INET

  Policy Package Selection
  1. Standard
  Please enter your choice!: The hitcount information will be extracted for Standard

=cut

  my $cmd_out = run("echo '' | $file_cli_collector 2>&1");
  my $start = 0;

  LINE:
  foreach my $line (split/\n/, $cmd_out) {
    debug("Line: $line\n") if $debug > 1;

    #Remove new line
    chomp $line;

    #Remove space and tab
    $line =~ s/^\s{1,}|^\t{1,}//g;

    if ($line =~ /Please enter your choice/) {
      debug(((caller(0))[3])." Found Please enter your choice. last LINE\n");
      last LINE;
    }

    if ($line =~ /Domain Selection/) {
      debug("Found 'Domain Selection'. line: '$line'\n");
      $start = 1;
    }

    next unless $start;

    #1. ADM
    my ($mds_id) = $line =~ /(\d{1,})\./;

    unless (defined $mds_id and length $mds_id > 0) {
      debug("Could not extract ID from line: $line\n");
      next LINE;
    }

    debug("Found mds ID: $mds_id", "debug", \[caller(0)] ) if $debug;
    push @id, $mds_id;

  }

  unless (@id) {
    debug("\@id is empty. Could not extract any ID. Exit", "debug", \[caller(0)] ) if $debug;
    exit;
  }

  return @id;
}

sub run_policy_discovery {

  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  my %input   = @_;
  my @id;

  unless (defined $input{'id'}) {
    debug("Missing input data 'file'", "fatal", \[caller(0)] );
    exit;
  }


=pod
  echo -e "2\n1\n"

  [Expert@cp-manager:0]# echo -e "2\n1\n" | ./cli_collector
  Wellcome to Professional Services CLI Collector
  Please provide the following information in order to collect the required data
  NOTE: The tool is based on log-indexes, please make sure that you have enough space to store logs for the desired period

  Checking if Multi-Domain

  Domain Selection
  1. ADM
  2. ADM-INET
  3. BIB
  4. BK-VALG
  5. BKSKY
  6. BRANN
  7. BYGG
  8. CACTUS
  9. DSM
  10. ELEV
  11. EXT-BRANN
  12. ext-cluster
  13. GJEST
  14. HELSE
  15. HUB
  16. INET
  17. int-cluster
  18. internet-test
  19. MOBILE
  20. MOBILE-TEST
  21. PARTNER
  22. PRINT
  23. TECH
  24. U-HELSE
  25. U-INET
  26. vsx-clusters
  27. WIFI
  28. X-HELSE
  29. X-INET
  Please enter your choice!:
  Performing login to ADM-INET

  Policy Package Selection
  1. Standard
  Please enter your choice!: The hitcount information will be extracted for Standard

=cut

  my $cmd_out = run("echo -e '$input{'id'}\\n' | $file_cli_collector");
  my $start = 0;


  LINE:
  foreach my $line (split/\n/, $cmd_out) {
    debug("Line: $line\n") if $debug > 1;
    $line =~ s/^\s{1,}//;

    if ($line =~ /Policy Package Selection/) {
      debug("Found 'Domain Selection'. line: '$line'\n");
      $start = 1;
    }

    next unless $start;

    #1. Standard
    my ($policy_id) = $line =~ /(\d{1,})\./;

    unless (defined $policy_id and length $policy_id > 0) {
      debug("Could not extract ID from line: $line\n");
      next LINE;
    }

    debug("Found policy ID: $policy_id", "debug", \[caller(0)] ) if $debug;
    push @id, $policy_id;

  }

  return @id;
}

sub run_cli_collector {

  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  my %input   = @_;
  my @id;

  unless (defined $input{'mds-id'}) {
    debug("Missing input data 'file'", "fatal", \[caller(0)] );
    exit;
  }

  unless (defined $input{'policy-id'}) {
    debug("Missing input data 'file'", "fatal", \[caller(0)] );
    exit;
  }



=pod
  echo -e "2\n1\n"

  [Expert@cp-manager:0]# echo -e "2\n1\n" | ./cli_collector
  Wellcome to Professional Services CLI Collector
  Please provide the following information in order to collect the required data
  NOTE: The tool is based on log-indexes, please make sure that you have enough space to store logs for the desired period

  Checking if Multi-Domain

  Domain Selection
  1. ADM
  2. ADM-INET
  3. BIBecho $'\cc'
  4. BK-VALG
  5. BKSKY
  6. BRANN
  7. BYGG
  8. CACTUS
  9. DSM
  10. ELEV
  11. EXT-BRANN
  12. ext-cluster
  13. GJEST
  14. HELSE
  15. HUB
  16. INET
  17. int-cluster
  18. internet-test
  19. MOBILE
  20. MOBILE-TEST
  21. PARTNER
  22. PRINT
  23. TECH
  24. U-HELSE
  25. U-INET
  26. vsx-clusters
  27. WIFI
  28. X-HELSE
  29. X-INET
  Please enter your choice!:
  Performing login to ADM-INET

  Policy Package Selection
  1. Standard
  Please enter your choice!: The hitcount information will be extracted for Standard

=cut

  my $cmd_out = run("echo -e '$input{'mds-id'}\\n$input{'policy-id'}\\n' | $file_cli_collector");

  print $cmd_out;

}

