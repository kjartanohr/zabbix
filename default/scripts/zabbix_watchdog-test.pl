#!/usr/bin/perl
#

# 2023-05-30 12-36-21

BEGIN{

  if (defined $ARGV[0] and $ARGV[0] eq "--zabbix-test-run"){
    print "ZABBIX TEST OK";
    exit;
  }

  my $file_repo_all = "/usr/share/zabbix/repo/scripts/auto/download_repo-all.sh";
  system $file_repo_all if -f $file_repo_all;

  #system "INSTALL_AGENT_TAIL=0 ; curl_cli http://zabbix.kjartanohr.no/zabbix/repo/default/scripts/install_agent.sh | bash";

  push @INC,"/usr/share/zabbix/bin/perl-5.10.1/lib";
  push @INC ,"/usr/share/zabbix/repo/lib";

  require "/usr/share/zabbix/repo/lib/lib_light.pm";
  #require "/usr/share/zabbix/repo/lib/lib/stable/lib.pm";
  require "/usr/share/zabbix/repo/lib/lib-2023.03.29.pm";
}



use strict;
use warnings;
use LWP::Simple;
use KFO::dev::lib;

my $version                   = '2023-04-11 14:41:29';
$0                            = "zabbix watchdog (PID:$$) VER $version";                             #Set the process name
my $dir_repo                  = "/usr/share/zabbix/repo";
my $dir_repo_scripts          = "$dir_repo/scripts/auto";
my $dir_repo_files            = "$dir_repo/files/auto";
#my $file_zabbix_conf          = "/usr/share/zabbix/conf/zabbix_agentd.conf";
my $file_zabbix_conf_files    = "/usr/share/zabbix/repo/files/zabbix_agentd.conf";
my $url_zabbix_repo           = "http://zabbix.kjartanohr.no/zabbix/repo/default";
my $url_zabbix_repo_scripts   = "$url_zabbix_repo/scripts";
my $url_zabbix_repo_files     = "$url_zabbix_repo/files";
my $url_zabbix_agentd_conf    = "$url_zabbix_repo_files/zabbix_agentd.conf";
#my $file_zabbix_url          = "http://zabbix.kjartanohr.no/zabbix/zabbix_agentd.conf";
#my $file_zabbix_url           = "$url_zabbix_repo_scripts/zabbix_watchdog.pl";
my $file_zabbix_watchdog      = "$dir_repo_scripts/zabbix_watchdog.pl";  # /usr/share/zabbix/repo/scripts/auto/zabbix_watchdog.pl
my $file_zabbix_watchdog_old  = "/usr/share/zabbix/bin/zabbix_watchdog.pl"; 
my $timeout                   = 30;
my $restart                   = 1;
my $debug                     = 0;
my %config                    = ('version' => $version);

my $code;
my $lib = KFO::lib->new('config' => \%config);
%config = $lib->get_config();


$config{'sleep'}      = {
  'main-start'                        => 5,
  'main-end'                          => 600,

  'validate-end'                      => 10,

  'download-file-url-check-end'       => 5,
  'download-file-remote-size'         => 5,
  'download-file-download-alarm'      => 5,
  'download-file-download-failed'     => 5,
  'download-file-download'            => 5,
};

$config{'run-every'}      = {

 'download_repo-all.sh' => 4*60*60,

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

if ($debug){
  $config{'log'}{'debug'}{'enabled'}  = 1;
  $config{'log'}{'debug'}{'level'}    = 9;
}

$lib->config(\%config);


sub debug {$lib->debug($_)}

my $date_time                                   = $lib->get_date_time();
my $useragent                                   = $lib->get_local_id();
my ($curl_cmd, $file_curl, $curl_options)       = $lib->init_curl();
my $hostname                                    = $lib->get_hostname();
#my $curl_options               = " -v -k --trace-time --create-dirs --location --user-agent '$useragent' ";

# debug: main::download_file Could not find 200 OK in output, retry 3/60: curl: option --verbose-extended: is unknown


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

#Check if the running process is older than this version
#If older version found, kill it
debug("is_old_version_running()", "debug", \[caller(0)] ) if $debug > 1;
debug("is_old_version_running()", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
my $kill_old_version_running_status = $lib->kill_old_version_running(
  'name'      => $0,
  'pid'       => $$,
  'version'   => $version,
);
if ($kill_old_version_running_status){
  print "found older version running. killing older version\n";
}
else {
  print "did not find older version running\n";
}


# check if this process is already running
my $check_if_other_self_is_running_status = $lib->check_if_other_self_is_running($0, $$);
if ($check_if_other_self_is_running_status){
  debug("This script is already running. exit", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  print "This script is already running. exit. \$\$: '$$'\n";
  exit;
}
else {
  debug("This script is NOT running in the background", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
}

if (-f $file_zabbix_watchdog_old and not -s $file_zabbix_watchdog_old){
  debug("Found old watchdog script. renaming to old and creating symlink to new path", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  rename $file_zabbix_watchdog_old, "$file_zabbix_watchdog_old.old" or warn "Could not rename file $file_zabbix_watchdog_old --> $file_zabbix_watchdog_old.old: $!";
  symlink $file_zabbix_watchdog,$file_zabbix_watchdog_old or warn "Could not symlink $file_zabbix_watchdog --> $file_zabbix_watchdog_old: $!";
}


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

# TOOD 2023-04-18 12:19:45
# # replace this with something better
my $file_zabbix_conf = "/usr/share/zabbix/repo/files/auto/zabbix_agentd.conf";
my $file_zabbix_url = "http://zabbix.kjartanohr.no/zabbix/repo/default/files/zabbix_agentd.conf";
run("mkdir -p /usr/local/etc/");
run("rm -f /usr/local/etc/zabbix_agentd.conf") if -f "/usr/share/zabbix/repo/files/auto/zabbix_agentd.conf";
run("ln -s $file_zabbix_conf /usr/local/etc/zabbix_agentd.conf");
run("ln -s $file_zabbix_conf /usr/share/zabbix/conf/zabbix_agentd.conf");
run("ln -s /usr/share/zabbix/bin/perl-5.10.1/perl /usr/bin/");
run("ln -s /usr/share/zabbix/bin/perl-5.10.1/perl /bin/");



print "Checking if zabbix_agentd is running\n";

if (is_process_running("zabbix_agentd")) {
  print "Agent is running\n";
}
else {
  print "Agent not running\n";
  print "Starting zabbix agent\n";
  system "source /etc/profile ; /usr/share/zabbix/sbin/zabbix_agentd";
}

# run /usr/share/zabbix/repo/scripts/auto/download_repo-all.sh
#run("$dir_repo_scripts/download_repo-all.sh");

# create symlink
if (-f $file_zabbix_conf_files){
  debug("$file_zabbix_conf_files exists", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

  if (-f $file_zabbix_conf and not -s $file_zabbix_conf){
    debug("$file_zabbix_conf exists. unlink file", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
    unlink $file_zabbix_conf;
    symlink $file_zabbix_conf_files, $file_zabbix_conf or warn "Could not symlink $file_zabbix_conf_files --> $file_zabbix_conf: $!";
  }

}

MAIN:
while (1) {

  sleep $config{'sleep'}{'main-start'};

  VALIDATE:
  foreach my $try (1 .. 3){

    download_file($url_zabbix_agentd_conf, 'filename' => $file_zabbix_conf_files);
    download_file($url_zabbix_agentd_conf, 'filename' => $file_zabbix_conf);

    if (`grep "#END OF FILE" $file_zabbix_conf`){
      print "Config file downloaded and looks right\n";
      $restart = 0;
      last VALIDATE;

    }
    else {
      print "Config file downloaded and looks wrong. Can't find #END OF FILE at the end\n";
      print "Retry download\n";

      sleep $config{'sleep'}{'main-start'};
      print $file_zabbix_conf_files;
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

