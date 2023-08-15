#!/bin/bash
#bin

if [ $1 ] && [ $1 = '--zabbix-test-run' ]
then
  echo ZABBIX TEST OK;
  exit;
fi

HOST="zabbix.kjartanohr.no";
PROTO="http";

IP_EXT="92.220.216.51";
IP_INT="10.0.6.102";

# curl binary file
CURL_BIN="curl";
curl_cli 2>&1 | grep "not found" &>/dev/null || CURL_BIN="curl_cli"
echo CURL_BIN: $CURL_BIN

IP=$IP_EXT;
CURL="$CURL_BIN -vvv -k -s --referer "$PROTO://installer_agent.sh" --resolve $HOST:80:$IP --resolve $HOST:443:$IP";

#timeout 1 curl -vvv $IP_INT 2>&1 | grep "Connected" && IP=$IP_INT ; HOST=$IP_INT ; CURL="$CURL_BIN -vvv -k -s --referer "$PROTO://installer_agent.sh""; echo Using internal IP $IP_INT

echo CURL: $CURL

URL="$PROTO://$HOST/zabbix/repo/default";
echo URL: $URL


if [ $1 ] && [ $1 = '--zabbix-test-run' ]
then
  echo ZABBIX TEST OK;
  exit;
fi

STRING_RANDOM="83dnw893op";

# tmp dir
unset DIR_TMP;
test $DIR_TMP || DIR_TMP=`DIR_TEST="/tmp"; echo >"$DIR_TEST/test-$STRING_RANDOM" 2>/dev/null && echo $DIR_TEST;`
test $DIR_TMP || DIR_TMP=`DIR_TEST="$HOME/tmp"; echo >"$DIR_TEST/test-$STRING_RANDOM" 2>/dev/null && echo $DIR_TEST;`
test $DIR_TMP || DIR_TMP=`DIR_TEST="$HOME"; echo >"$DIR_TEST/test-$STRING_RANDOM" 2>/dev/null && echo $DIR_TEST;`
test $DIR_TMP || DIR_TMP=`DIR_TEST="."; echo >"$DIR_TEST/test-$STRING_RANDOM" 2>/dev/null && echo $DIR_TEST;`
echo DIR_TMP: $DIR_TMP

#PERL_PATH="/usr/bin";
unset PERL_PATH;
test $PERL_PATH || PERL_PATH=`DIR_TEST="/usr/bin"; echo >"$DIR_TEST/test-$STRING_RANDOM" 2>/dev/null && echo $DIR_TEST;`
test $PERL_PATH || PERL_PATH=`DIR_TEST="/tmp"; echo >"$DIR_TEST/test-$STRING_RANDOM" 2>/dev/null && echo $DIR_TEST;`
test $PERL_PATH || PERL_PATH=`DIR_TEST="$HOME"; echo >"$DIR_TEST/test-$STRING_RANDOM" 2>/dev/null && echo $DIR_TEST;`
test $PERL_PATH || PERL_PATH=`DIR_TEST="$HOME/bin"; echo >"$DIR_TEST/test-$STRING_RANDOM" 2>/dev/null && echo $DIR_TEST;`
test $PERL_PATH || PERL_PATH=`DIR_TEST="."; echo >"$DIR_TEST/test-$STRING_RANDOM" 2>/dev/null && echo $DIR_TEST;`
echo PERL_PATH: $PERL_PATH

# download perl mini
test -f $PERL_PATH/perl_mini ||  $CURL --url "$URL/files/perl" -o $PERL_PATH/perl_mini ; chmod +x $PERL_PATH/perl_mini
test -f $PERL_PATH/perl_mini && echo perl mini downloaded $PERL_PATH/perl_mini
echo PERL_PATH: $PERL_PATH

# download lib.pm
test -f $DIR_TMP/lib.pm  || $CURL --url "$URL/files/lib.pm" -o $DIR_TMP/lib.pm
test -f $DIR_TMP/lib.pm && echo lib.pm downloaded
echo DIR_TMP: $DIR_TMP

# bash: line 36: ./perl_mini: cannot execute binary file: Exec format error
# validate perl binary
unset PERL_BIN;
echo $PERL_BIN | grep . || PERL_BIN=`$PERL_PATH/perl_mini -v 2>&1 | grep "This is perl" &>/dev/null && echo "$PERL_PATH/perl_mini"`
echo $PERL_BIN | grep . || PERL_BIN=`perl -v 2>&1 | grep "This is perl" &>/dev/null && echo "perl"`
echo PERL_BIN: $PERL_BIN

# validate write access to folder
unset DIR_ZABBIX;
test $DIR_ZABBIX || DIR_ZABBIX=`DIR_TEST="/usr/share"; echo >"$DIR_TEST/test-$STRING_RANDOM" 2>/dev/null && echo $DIR_TEST;`
test $DIR_ZABBIX || DIR_ZABBIX=`DIR_TEST="$HOME/bin"; echo >"$DIR_TEST/test-$STRING_RANDOM" 2>/dev/null && echo $DIR_TEST;`
test $DIR_ZABBIX || DIR_ZABBIX=`DIR_TEST="$HOME"; echo >"$DIR_TEST/test-$STRING_RANDOM" 2>/dev/null && echo $DIR_TEST;`
test $DIR_ZABBIX || DIR_ZABBIX=`DIR_TEST="/tmp"; echo >"$DIR_TEST/test-$STRING_RANDOM" 2>/dev/null && echo $DIR_TEST;`
test $DIR_ZABBIX || DIR_ZABBIX=`DIR_TEST="."; echo >"$DIR_TEST/test-$STRING_RANDOM" 2>/dev/null && echo $DIR_TEST;`
DIR_ZABBIX="$DIR_ZABBIX/zabbix";
echo DIR_ZABBIX: $DIR_ZABBIX

# bin
unset DIR_BIN;
test $DIR_BIN || DIR_BIN=`DIR_TEST="/usr/bin"; echo >"$DIR_TEST/test-$STRING_RANDOM" 2>/dev/null && echo $DIR_TEST;`
test $DIR_BIN || DIR_BIN=`DIR_TEST="/usr/share/bin"; echo >"$DIR_TEST/test-$STRING_RANDOM" 2>/dev/null && echo $DIR_TEST;`
test $DIR_BIN || DIR_BIN=`DIR_TEST="/bin"; echo >"$DIR_TEST/test-$STRING_RANDOM" 2>/dev/null && echo $DIR_TEST;`
test $DIR_BIN || DIR_BIN=`DIR_TEST="$HOME/bin"; echo >"$DIR_TEST/test-$STRING_RANDOM" 2>/dev/null && echo $DIR_TEST;`
test $DIR_BIN || DIR_BIN=`DIR_TEST="$HOME"; echo >"$DIR_TEST/test-$STRING_RANDOM" 2>/dev/null && echo $DIR_TEST;`
test $DIR_BIN || DIR_BIN=`DIR_TEST="."; echo >"$DIR_TEST/test-$STRING_RANDOM" 2>/dev/null && echo $DIR_TEST;`
echo DIR_BIN $DIR_BIN

grep "$DIR_ZABIX" "$HOME/.bashrc" || echo PATH="\$PATH:$DIR_BIN:$DIR_ZABBIX/repo/scripts/auto" ">>$HOME/.bashrc"

$PERL_BIN -e 'use warnings; use strict; print "Script starting\n"; my $dry_run = 0; my $clear = `clear`; my $code = join "",<STDIN>; eval $code; print $@ if $@' "$URL" "$PROTO" "$HOST" "$IP" "$PERL_BIN"  "$DIR_BIN" "$DIR_ZABBIX" "$DIR_TMP" <<'EOF'
#
##START OF MAIN SCRIPT

#TODO
# Scriptet starter
#   Test/sjekk. Meld om feil til STDOUT, send en mail, REST API URL
#     DNS
#       DNS oppslag for zabbix.kjartanohr.no
#         default DNS server
#         Alle DNS servere i /etc/resolv.conf
#         8.8.8.8
#         1.1.1.1
#         default gw
#
#     HTTP
#       HTTPS zabbix.kjartanohr.no
#       HTTP zabbix.kjartanohr.no
#
# Mirror
#   Legge til mirror av repo på atea github
#   Last ned mirror fil og bruk URL i mirror fil fremfor statisk kodet URL i kode
#
# Update
#   Sjekk om dette scriptet har en ny versjon
#
# Last ned alle filer
#   Sjekk filstørrelse og mtime på fil remote og lokal
#   Rename gammel lokal fil til .old
#   Last ned ny fil
#   Meldt fra om problemer
#   Retry 10
#
# Test fil
#   Script
#     Startes med script.sh --zabbix-test-run
#     Forventet output er ZABBIX TEST OK
#     Hvis sjekk feiler. Last ned på nytt
#     Hvis alt feiler, rename scrip.sh.old tilbake til script.sh
#       Meld inn feil
#
#     rpm
#       rpm -qipl fping-2.4-1.b2.3.el5.rf.i386.rpm
#         Sjekk at output er riktig
#         hent ut listen av filer i rpm
#
#       rpm -Uvh FIL
#         Sjekk at output er OK
#
#       Sjekk at alle filer i RPM ligger på filsystem
#         Det er en av de vanlige feilene. Noen filer ble ikke installert.
#
#     tar.gz
#       List alle filer
#         Verify output
#
#       Pakk ut fil
#         Sjekk at alle filer matcher tidligere fil-liste
#
#       Sjekk at alle filer ligger på disk
#         Det er en av de vanlige feilene. Noen filer ble ikke installert.
#
#
# Verfy JSON
#   Hver fil i repo har en tilhørende .json fil
#   Symlink til script (/usr/bin/)
#   lokalt filnavn
#   Install directory
#   krever ledig diskplass
#   tester
#     start. script.sh --test
#     forventet output. Test OK
#
#     /usr/bin/perl -v
#     version 5.32.0
#
#   Kommando
#     Kommandoer som skal kjøres før nedlasting
#     Kommandoer som skal kjøres etter nedlasting
#     Kommandoer som skal kjøres før install
#     Kommandoer som skal kjøres etter install
#
#
#
#
# leser config\
# kjør filen/kjør tester
# se at outlput er riktig
# meld OK eller FAILED til STDOUT
# Send en mail om FAILED
# Mirror liste. Atea github
#
#Legge inn statisk IP til zabbix repo om DNS ikke virker
#

# changelog

# 2023.03.03
# Det manglet en sleep i download_url() når curl feilet på en download.
# Dette lager en storm av nye connections.
# Når flere brannmurer er bak en public NAT IP vil det trigge DOS regel på brannmuren for repo

my %config;
my $tmp = {};

my $url                         = shift @ARGV // die "Missing input URL";
my $protocol                    = shift @ARGV // die "Missing input protocol";
my $host                        = shift @ARGV // die "Missing input host";
my $ip                          = shift @ARGV // die "Missing input IP";
my $file_perl                   = shift @ARGV // die "Missing input file_perl";
my $dir_bin                     = shift @ARGV // die "Missing input dir_bin";
my $dir_zabbix                  = shift @ARGV // die "Missing input dir_zabbix";
my $dir_tmp                     = shift @ARGV // die "Missing input dir_tmp";
my $dir_zabbix_tmp              = "$dir_zabbix/tmp";
my $dir_zabbix_repo             = "$dir_zabbix/repo";
my $dir_zabbix_repo_scripts     = "$dir_zabbix_repo/scripts/auto";
my $dir_zabbix_config           = "/usr/local/etc";

my $file_curl                   = whereis('curl', 'curl_cli');
my $useragent                   = get_local_id();
#my $curl_options               = " -v -k --trace-time --create-dirs --location --user-agent '$useragent' ";

my @curl_options                = (
  "-vvv",                                     #Extra verbose
  #"--verbose-extended",                       #Show HTTP header and body (Checkpoint option) # ikke supportert i R80.10
  #"--dns-servers",                           #<addresses> DNS server addrs to use
  "--insecure",                               #Allow insecure server connections when using SSL
  "--ipv4",                                   #Resolve names to IPv4 addresses
  "--keepalive-time 60",                      #<seconds> Interval time for keepalive probes
  #"--limit-rate 10000",                       #Limit transfer speed to RATE",

  # Disablet denne. brannmurer som er bak andre brannmurer blir droppet
  #"--local-port 30000-30100",                 #Force use of RANGE for local port numbers

  "--location",                               #Follow redirects
  "--max-redirs 10",                          #Maximum number of redirects allowed
  "--max-time 600",                                 #Maximum time allowed for the transfer
  "--progress-bar",                                 #Display transfer progress as a bar
  "--referer '$protocol://installer_agent.sh'",     #Referrer URL
  "--remote-time",                                  #Set the remote file's time on the local output
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


my $url_zabbix_repo             = "$protocol://$host/zabbix/repo/default";

my $url_zabbix_agent_config     = "$url_zabbix_repo/files/zabbix_agentd.conf";

#my $url_zabbix_agent           = "http://zabbix.kjartanohr.no/zabbix/zabbix_agents_3.2.7.linux2_6.i386.tar.gz";
my $url_zabbix_agent            = "$protocol://$host/zabbix/repo/default/files/zabbix_agents_3.2.7.linux2_6.i386.tar.gz";
my $url_zabbix_agent_filename   = get_filename_from_url($url_zabbix_agent);

my $url_perl_5_10               = "$protocol://$host/zabbix/perl-5.10.1_compiled.tar.gz";
my $url_perl_5_10_filename      = get_filename_from_url($url_perl_5_10);

my $url_download_repo           = "$protocol://$host/zabbix/repo/default/scripts/download_repo.pl";
my $url_download_repo_filename  = get_filename_from_url($url_download_repo);

my $url_watchdog                = "$protocol://$host/zabbix/repo/default/files/zabbix_watchdog.pl";

my $cmd_download_files          = "$file_perl $dir_zabbix/repo/scripts/auto/download_repo.pl $protocol://$host/zabbix/repo/default/files/auto/ $dir_zabbix/repo/files/auto/ no-validate";
my $cmd_download_scripts        = "$file_perl $dir_zabbix/zabbix/repo/scripts/auto/download_repo.pl $protocol://$host/zabbix/repo/default/scripts/auto/ $dir_zabbix/repo/scripts/auto/ no-validate";

my $cmd_perl_5_32               = "$dir_zabbix/repo/scripts/auto/install_perl.sh";

my $file_perl_5_32_symlink      = "/usr/bin/perl5.32.0";
my $file_download_repo_pl       = "$dir_tmp/download_repo.pl";

my $file_zabbix_agent_conf      = "$dir_zabbix_repo/files/zabbix_agentd.conf";

my $file_bin_perl = "/bin/perl";

my $debug                       = 0;
#my $dry_run                     = 0;

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

if ($debug){
  $config{'log'}{'debug'}{'enabled'}  = 1;
  $config{'log'}{'debug'}{'level'}    = 9;
}

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



#print join ", ", @ARGV; exit;

die "\n\nFATAL. COULD NOT FIND CURL BINARY.\nSend an email to Kjartan Flåm Ohr and report this.\n" unless $file_curl;
debug("Found curl binary $file_curl\n");

debug("Checking if DNS works\n");
unless (check_dns_resolve($dns_test)) {
  warn "Could not resolve hostname $dns_test. Check your DNS settings";
  warn "Adding static IP-addresses to curl";
  my $curl_dns  = get_curl_static_dns();
  $curl_options = "$curl_dns $curl_options";
}

# Slett $dir_zabbix
# rm -Rf $dir_zabbix

debug("Creating directory $dir_zabbix\n");
run("mkdir -p $dir_zabbix") unless -d $dir_zabbix;

debug("Creating directory $dir_zabbix_tmp\n");
run( "mkdir -p $dir_zabbix_tmp") unless $dir_zabbix_tmp;

debug("Creating directory $dir_zabbix_config\n");
run("mkdir -p $dir_zabbix_config") unless -d $dir_zabbix_config;

debug("Download $url_zabbix_agent\n");
download_file($url_zabbix_agent, filename => "$dir_zabbix_tmp/$url_zabbix_agent_filename");

debug("Extracting $dir_zabbix_tmp/$url_zabbix_agent_filename to $dir_zabbix\n");
run("tar xfz $dir_zabbix_tmp/$url_zabbix_agent_filename -C $dir_zabbix");


debug("Download $url_perl_5_10\n");
download_file($url_perl_5_10, filename => "$dir_zabbix_tmp/$url_perl_5_10_filename");

debug("Extracting $dir_zabbix_tmp/$url_zabbix_agent_filename to $dir_zabbix\n");
run("tar xfz $dir_zabbix_tmp/$url_perl_5_10_filename -C $dir_zabbix/bin/");

debug("Creating symlink for perl 5.10.1 binary\n");
unlink $file_bin_perl if -f $file_bin_perl;
run("ln -s $dir_zabbix/bin/perl-5.10.1/perl $file_bin_perl");

unlink $file_download_repo_pl if -f $file_download_repo_pl;
download_file("$url_download_repo", 'filename' => $file_download_repo_pl);
run("chmod +x $file_download_repo_pl");
run("$file_perl $file_download_repo_pl $protocol://$host/zabbix/repo/default/files/auto/ $dir_zabbix/repo/files/auto/ no-validate", "timeout" => 600);
run("$file_perl $file_download_repo_pl $protocol://$host/zabbix/repo/default/lib/ $dir_zabbix/repo/lib/ no-validate", "timeout" => 600);
run("$file_perl $file_download_repo_pl $protocol://$host/zabbix/repo/default/lib/prod $dir_zabbix/repo/lib/prod no-validate", "timeout" => 600);
run("$file_perl $file_download_repo_pl $protocol://$host/zabbix/repo/default/lib/dev $dir_zabbix/repo/lib/dev no-validate", "timeout" => 600);
run("$file_perl $file_download_repo_pl $protocol://$host/zabbix/repo/default/lib/test $dir_zabbix/repo/lib/test no-validate", "timeout" => 600);
run("$file_perl $file_download_repo_pl $protocol://$host/zabbix/repo/default/scripts/auto/ $dir_zabbix/repo/scripts/auto/ no-validate", "timeout" => 600);

unlink $file_perl_5_32_symlink if -f file_perl_5_32_symlink;
run("perl $dir_zabbix/repo/scripts/auto/install_perl_5.32.0.pl");
run($cmd_perl_5_32);

my @run_keys = (
  'install_dnsmasq.pl',
  'install_emacs_26.3.pl',
  'dnsmasq_watchdog.pl',
  #'cleanup.pl',
  'download_repo-all.sh',
  'interface_monitor.pl --daemon 1',
  'logrotate_config_creator.pl',
  'monitord_fix.pl',
  'ping_background.pl',
  'ping_http.pl',
  'symlink_scripts.pl',
  'top_collector.pl',
);
foreach my $run_key (@run_keys){
  run("$dir_zabbix_repo_scripts/$run_key");
}

run("$dir_zabbix_repo_scripts/dnsmasq_watchdog.pl");

debug("Creating symlink for zabbix config file\n");


download_file("$url_zabbix_agent_config", 'filename' => $file_zabbix_agent_conf) if not -f $file_zabbix_agent_conf;

unlink "$dir_zabbix/conf/zabbix_agentd.conf.old" if -f "$dir_zabbix/conf/zabbix_agentd.conf.old";
rename "$dir_zabbix/conf/zabbix_agentd.conf", "$dir_zabbix/conf/zabbix_agentd.conf.old";
run("ln -s $file_zabbix_agent_conf $dir_zabbix/conf/zabbix_agentd.conf");

unlink "$dir_zabbix_config/zabbix_agentd.conf" if -f "$dir_zabbix_config/zabbix_agentd.conf";
run("ln -s $file_zabbix_agent_conf $dir_zabbix_config/zabbix_agentd.conf");

run("grep zabbix /etc/rc.local || echo '$dir_zabbix_repo_scripts/zabbix_watchdog.pl & '>>/etc/rc.local");
download_file($url_watchdog, "filename" => "$dir_zabbix_repo_scripts/zabbix_watchdog.pl");
run("chmod +x $dir_zabbix_repo_scripts/zabbix_watchdog.pl");
run('nohup $dir_zabbix_repo_scripts/zabbix_watchdog.pl </dev/null >/dev/null 2>&1 &');

run("killall zabbix_watchdog.pl");
run("pkill zabbix_watchdog.pl");
run("pkill zabbix_agentd");

sleep 2;

run("$dir_zabbix/sbin/zabbix_agentd");

run('ps xau|grep zabb|grep -v grep|grep "zabbix_watchdog.pl"  || nohup $dir_zabbix_repo_scripts/zabbix_watchdog.pl </dev/null >/dev/null 2>&1 &');

sleep 5;

#run("ps xauwef|grep zabb");
run("ps xau|grep zabb");
run("ss -pleantu|grep zabb");

system("tail -F /tmp/zabbix_agentd.log");



#END OF MAIN SCTIPT

sub run {
  my $sub_name = (caller(0))[3];
  debug("start", $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 1;
  debug("input: ".Dumper(@_), $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 3;

  my $cmd                       = shift || die "Did not get any CMD";
  my %input                     = @_;
  #my $cmd_out = "Output from command: $cmd\n";
  my $cmd_out = "";

  $input{'pause'}             ||= 0;
  $input{'ask'}               ||= 0;
  $input{'timeout'}           ||= 60;
  $input{'stop_if_found'}     ||= "";
  $input{'stop_if_not_found'} ||= "";
  $input{'stop_msg'}          ||= "";
  #$input{'print'}             ||= $debug;
  $input{'print'}             //= 0;
  $input{'retry'}             ||= 3;
  $input{'dry_run'}           ||= 0;
  $input{'desc'}              //= "unknown description";
  $input{'cache'}             //= 0; 


  #print $clear if $input{'clear'};

  if ($input{'ask'}) {
    debug("$sub_name. \$input{'ask'} is true", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
    my $msg = "$input{'ask'}\n";

    ask(
      $msg,
      answer  => "Y",
      print   => 1,
    );
  }


  if ($input{'dry_run'} == 0) {
    debug("$sub_name. $input{'desc'}. \$input{'dry_run'} is false", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

    my $cmd_cache = cache(
      'type'  => 'get',
      'name'  => $cmd,
    );
    if (defined $cmd_cache){
      debug("\$cmd_cache is defined: $cmd_cache", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
      return $cmd_cache;
    }

       

    eval {
      local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
      alarm $input{'timeout'};

      debug("$sub_name. $input{'desc'}. Running command: $cmd", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
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
    debug("$sub_name. $input{'desc'}. Running command: $cmd", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
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

  # Add to cache
  cache(
    'type'  => 'set',
    'name'  => $cmd,
    'value' => "$cmd_out",
  );


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
  my $sub_name = (caller(0))[3];
  debug("start", $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 1;
  debug("input: ".Dumper(@_), $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 3;

  my $url                 = shift || die "Missing URL";
  my %input               = @_;

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
      run($cmd_mkdir, 'desc' => "create dir $cmd_mkdir");
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
    return 0;
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
      $cmd_curl_download_out = run("$cmd_curl_download", 'desc' => "$sub_name. curl. download file");
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
      #die "Could not get local file size. Exiting" unless $file_local_size;
      debug(((caller(0))[3])." Got local file size: $file_local_size\n");
      return 1;
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
  
  return 1 if -f $input{'filename'};
  return 0 if -f $input{'filename'};
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
    if (defined $path){
      $path =~ s/ .*//;

      if ($path) {
        debug("Found file $file. $path");
        return $path;

      }
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
  my $version = "default";

  #Run the command fw ver to get the installed version
  my $fw = `fw ver`;
  unless ($fw =~ /software version/){
    print "Need a human here. Could not get FW version from fw ver";
    #exit;
  }

  #Get the Check Point version from fw ver
  my ($ver) = $fw =~ / version (.*?) /;
  unless ($ver){
    print "Need a human here. Could not extract FW version from fw ver";
    #exit;
  }
  $version = $ver if defined $ver;

  #Lowercase the version (the R)
  $ver = lc $ver;

  #The URL for the repo
  $url = lc $url;
  $url =~ s/__VER__/$version/g;

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

sub create_dir {
  my $sub_name = (caller(0))[3];
  debug("start", $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 1;
  debug("input: ".Dumper(@_), $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 3;

  my $name = shift || die "Need a directory name to create\n";
  debug("Input directory name: $name", "debug", \[caller(0)] ) if $debug > 2;

  my $out;

  if (-d $name){
    debug("$name directory exists. No need to create", "debug", \[caller(0)] ) if $debug > 2;
    return 1;
  }
  else {
    my $cmd = "mkdir -p $name";
    my $out = run($cmd, 'desc' => "$sub_name. mkdir -p $name");
    debug("$name directory missing. Creating. Out: $out", "debug", \[caller(0)] ) if $debug > 2;
  }

  unless (-d $name) {
    debug("Could not create $name: $out", "fatal", \[caller(0)] );
  }
}


sub init_curl {

  my $file_curl                   = whereis('curl', 'curl_cli');
  #my $useragent                   = get_local_id();
  my $useragent                   = "";
  my $hostname                    = `hostname`;
  chomp $hostname;
  #my $curl_options               = " -v -k --trace-time --create-dirs --location --user-agent '$useragent' ";

  # debug: main::download_file Could not find 200 OK in output, retry 3/60: curl: option --verbose-extended: is unknown

  my @curl_options                = (
    "-vvv",                                     #Extra verbose
    #"--verbose-extended",                      #Show HTTP header and body (Checkpoint option). Denne virker ikke etter R81.X
    #"--dns-servers",                           #<addresses> DNS server addrs to use
    "--insecure",                               #Allow insecure server connections when using SSL
    "--ipv4",                                   #Resolve names to IPv4 addresses
    "--keepalive-time 60",                      #<seconds> Interval time for keepalive probes
    #"--limit-rate 10000",                      #Limit transfer speed to RATE",
    #"--local-port 30000-30100",                #Force use of RANGE for local port numbers
    "--location",                               #Follow redirects
    "--max-redirs 10",                          #Maximum number of redirects allowed
    "--max-time 600",                           #Maximum time allowed for the transfer
    "--progress-bar",                           #Display transfer progress as a bar
    "--referer '$0'",    #Referrer URL
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
    #"--header 'Host: zabbix.kjartanohr.no'",   #Pass custom header(s) to server
    "--url",                                    #URL to work with

    #Not supported
    #"--retry-connrefused 1",                   #Retry on connection refused (use with --retry)
    #"--fail-early",                            #NOT SUPPORTED. Fail on first transfer error, do not continue
    #"--false-start",                           #NOT SUPPORTED. Enable TLS False Start
    #"--styled-output",                         #Enable styled output for HTTP headers
    #"--tcp-fastopen",                          #NOT SUPPORTED. Use TCP Fast Open
  );

  my $curl_options                = array_to_string('array' => \@curl_options);
 
  return ("$file_curl $curl_options", $file_curl, $curl_options);

}

=pod

my $cmd_cache = cache(
  'type'  => 'get',
  'name'  => "$cmd",
);

cache(
  'type'  => 'set',
  'name'  => "$cmd",
  'value' => "$cmd_out",
);

=cut
sub cache {
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
  $input{'validate-return-data'}  //= 1;
  $input{'type'}                  //= 'get';
  $input{'value'}                 //= '';
  #$input{'xxx'} = "yyy" unless defined $input{'xxx'};

  #validate input data start
  if ($config{"val"}{'sub'}{'in'}){
    my @input_type = qw( name );
    foreach my $input_type (@input_type) {

      unless (defined $input{$input_type} and length $input{$input_type} > 0) {
        debug("missing input data for '$input_type'", "fatal", \[caller(0)] ) if $config{'log'}{'fatal'}{'enabled'} and $config{'log'}{'fatal'}{'level'} > 3;
        return 0;
      }
    }
  }
  #validate input data start

  #sub header end

  #sub main code start

  if ($input{'type'} eq 'get'){
    
    $return  = $$tmp{'cache'}{$input{'name'}};
    if (defined $return){
      debug("Found data in cache: '$return'", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
    }
    else {
      debug("data NOT found in cache", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
      return;
    }

  }
  elsif ($input{'type'} eq 'set'){

    $$tmp{'cache'}{$input{'name'}} = $input{'value'};
    debug("New data set in cache:\n$$tmp{'cache'}{$input{'name'}}", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

  }

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



EOF




