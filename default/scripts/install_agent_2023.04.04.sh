#!/bin/bash
#bin

# 2023-06-07-07-35-32

# changelog
# 2023-06-06 - lagt til get_local_id() i user agent

if [ $1 ] && [ $1 = '--zabbix-test-run' ]
then
  echo ZABBIX TEST OK;
  exit;
fi

HOST="zabbix.kjartanohr.no";
PROTO="http";

IP_EXT="92.220.216.51";
IP_INT="10.0.6.102";
DEBUG=1

# curl binary file
CURL_BIN="curl";
curl_cli 2>&1 | grep "not found" &>/dev/null || CURL_BIN="curl_cli"
echo CURL_BIN: $CURL_BIN

CURL_KEY=`grep search /etc/resolv.conf | awk '{print $2}'`
CURL_KEY="$CURL_KEY-`hostname`";
echo $CURL_KEY

IP=$IP_EXT;
CURL="$CURL_BIN -vvv -k -s --referer "$PROTO://installer_agent.sh" --user-agent "$CURL_KEY" --resolve $HOST:80:$IP --resolve $HOST:443:$IP";
echo CURL: $CURL

#timeout 1 curl -vvv $IP_INT 2>&1 | grep "Connected" && IP=$IP_INT ; HOST=$IP_INT ; CURL="$CURL_BIN -vvv -k -s --referer "$PROTO://installer_agent.sh""; echo Using internal IP $IP_INT



URL="$PROTO://$HOST/zabbix/repo/default";
echo URL: $URL

URL_ZABBIX_REPO="$PROTO://$HOST/zabbix/repo/default";
URL_ZABBIX_REPO_INT="$PROTO://$IP_INT/zabbix/repo/default";
echo URL_ZABBIX_REPO: $URL_ZABBIX_REPO


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
$PERL_PATH/perl_mini -v 2>&1 | grep "Larry Wall" &>/dev/null || $CURL --url "$URL/files/perl" -o $PERL_PATH/perl_mini ; chmod +x $PERL_PATH/perl_mini
echo PERL_PATH: $PERL_PATH

# download lib.pm
echo $CURL --url "$URL/files/lib.pm" -o $DIR_TMP/lib.pm
test -f $DIR_TMP/lib.pm  || $CURL --url "$URL/files/lib.pm" -o $DIR_TMP/lib.pm
test -f $DIR_TMP/lib.pm && echo lib.pm downloaded
echo DIR_TMP: $DIR_TMP

# download lib_light.pm
FILE_LIB_LIGHT="$DIR_TMP/lib_light.pm";
echo $CURL --url "$URL_ZABBIX_REPO/lib/lib_light.pm" -o "$FILE_LIB_LIGHT";
test -f "$FILE_LIB_LIGHT" && rm -vf "$FILE_LIB_LIGHT"
test -f "$FILE_LIB_LIGHT" || timeout 10 $CURL --url "$URL_ZABBIX_REPO/lib/lib_light.pm" -o "$FILE_LIB_LIGHT";
test -f "$FILE_LIB_LIGHT" || timeout 10 $CURL --url "$URL_ZABBIX_REPO_INT/lib/lib_light.pm" -o "$FILE_LIB_LIGHT"
test -f "$FILE_LIB_LIGHT" && echo lib_light.pm is downloaded

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

echo starting perl script
echo $PERL_BIN -e 'use warnings; use strict; print "Script starting\n"; my $dry_run = 0; my $clear = `clear`; my $code = join "",<STDIN>; eval $code; print $@ if $@' "$URL" "$PROTO" "$HOST" "$IP" "$PERL_BIN"  "$DIR_BIN" "$DIR_ZABBIX" "$DIR_TMP" "$FILE_LIB_LIGHT"

$PERL_BIN -e 'use warnings; use strict; print "Script starting\n"; my $dry_run = 0; my $clear = `clear`; my $code = join "",<STDIN>; eval $code; print $@ if $@' "$URL" "$PROTO" "$HOST" "$IP" "$PERL_BIN"  "$DIR_BIN" "$DIR_ZABBIX" "$DIR_TMP" "$FILE_LIB_LIGHT" <<'EOF'
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

# 2023-04-02
# lagt til flere sjekker i header
# Byttet til download_file() fremfor curl kommandoer

# 2023-06-07-07-45-14
# Lagt til bruk av get_local_id();
# Funksjon lagt til sammen med Aleksander. Testet på 4 bokser hos en kunde

BEGIN {
  require $ARGV[8];
}

print "perl script started\n";

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
my $file_lib                    = shift @ARGV // die "Missing input lib";
my $dir_zabbix_tmp              = "$dir_zabbix/tmp";
my $dir_zabbix_repo             = "$dir_zabbix/repo";
my $dir_zabbix_repo_scripts     = "$dir_zabbix_repo/scripts/auto";
my $dir_zabbix_config           = "/usr/local/etc";


my $useragent                   = get_local_id();
my ($curl_cmd, $file_curl, $curl_options)      = init_curl();

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

my $debug                       = 1;
#my $dry_run                    = 0;

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
  "enabled"       => 1,     #0/1
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

#unlink $file_perl_5_32_symlink if -f file_perl_5_32_symlink;
#run("perl $dir_zabbix/repo/scripts/auto/install_perl_5.32.0.pl");
#run($cmd_perl_5_32);

my @run_keys = (
  'download_repo-all.sh',
  'install_perl_5.32.0.pl',
  'install_dnsmasq.pl',
  'dnsmasq_watchdog.pl',
  'install_emacs_26.3.pl',
  #'cleanup.pl',
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

system("timeout 60 tail -F /tmp/zabbix_agentd.log") if not defined $ENV{'INSTALL_AGENT_TAIL'} and $ENV{'INSTALL_AGENT_TAIL'} eq '0';



#END OF MAIN SCTIPT

EOF

