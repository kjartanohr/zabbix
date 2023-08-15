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
my $process_name              = "no name";
$0                            = "perl $process_name VER 100";

#Print the data immediately. Don't wait for full buffer
$|++;

$SIG{CHLD}                    = "IGNORE";
$SIG{INT}                     = \&save_and_exit('msg') => 'Signal INIT';

#Zabbix health check
zabbix_check($ARGV[0]);

our $dir_tmp                  = "/tmp/zabbix/$process_name";
our $file_debug               = "$dir_tmp/debug.log";
my  $file_exit                = "$dir_tmp/stop";

our $debug                    = 5;                                                  #This needs to be 0 when running in production
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

$config{'url'}    = {
  
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



#Check for input options
unless (@ARGV) {
  help(
    'msg'         => "Missing input data. No data in \@ARGV",
    'die'         => 1,
    'debug'       => 1,
    'debug_type'  => "warning",
  );
}

#Parse input data
my %argv = parse_command_line(@ARGV);

#Print help if no input is given
help('msg' => "help started from command line", 'exit'  => 1) if defined $argv{'help'};

#Activate debug if debug found in command line options
$debug = $argv{'debug'} if defined $argv{'debug'};

#init JSON
#my $json = init_json();




#End of standard header


#Fork a child
unless ($debug) {

  #fork a child and exit the parent
  fork && exit;

  #Closing so the parent can exit and the child can live on
  #The parent will live and wait for the child if there is no close
  close STDOUT;
  close STDIN;
  close STDERR;
}

#Eveything after here is the child


my @cmd = (
);

#Upload files to nextcloud repo

#Delete files

#autoupdatercli install /usr/share/zabbix/repo/files/Check_Point_HCP_AUTOUPDATE_Bundle_T52_AutoUpdate.tar
#hcp -r all --include-charts yes
#Hent ut denne filen /var/log/hcp/last/hcp_report_cp-manager_19_04_22_11_37.tar.gz


sub download_file_2 {
  
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  my %input   = @_;

  unless (defined $input{'url'}) {
    debug("Missing input data 'file'", "fatal", \[caller(0)] );
    exit;
  }

  unless (-f $input{'file'}) {
    debug("JSON file not found. return ()", "debug", \[caller(0)]) if $debug > 1;
    return ();
  }

  return ();

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



sub start_cli_collector {

  #CLI collector
  
  #Laste ned
  #Kjøre på MGMT
  #Start, finn siste tall
  #foreach 1 .. siste tall
  #

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

}
