#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
  #require "./lib.pm"
}



use warnings;
use strict;
#use Data::Dumper;
use JSON;

#TODO
#Timeout på vsx kommando
#Timeout på hele scriptet
#Send tilbake fatal hvis timeout
#Validate vsx data. id =~ /\d/
#--test test alle kommandoer og se at alt er OK

$0 = "perl vsx discovery VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

our $debug            = 0;                                                            #Set to 1 if you want debug data and no fork
our $info             = 0;
our $warning          = 1;
our $error            = 1;
our $fatal            = 1;

my  $dir_tmp        = "/tmp/zabbix/vsx_discovery";
our $file_debug     = "$dir_tmp/debug.log";
my  $fork           = 0;

#S - Virtual System
#B - Virtual System in Bridge mode
#R - Virtual Router
#W - Virtual Switch
#my  $vs_type        = shift @ARGV || "S";


our %config                = get_config();

my %argv = parse_command_line(@ARGV);
$argv{'type'} ||= "S";


#Create dir
create_dir($dir_tmp);

#Delete log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);

#End of standard header


#fork a child and exit the parent
#Don't fork if $debug is true
if ($fork and not $debug){
  fork && exit;
}

#Closing so the parent can exit and the child can live on
#The parent will live and wait for the child if there is no close
#Don't close if $debug is true
if ($fork and not $debug){
  close STDOUT;
  close STDIN;
  close STDERR;
}

#debug("", "debug", \[caller(0)] ) if $debug;
#debug("", "info", \[caller(0)] )  if $debug;
#debug("", "error", \[caller(0)] ) if $error;
#debug("", "fatal", \[caller(0)] );

#Eveything after here is the child

#perl -e '$first = 0; print "{\n"; print "\t\"data\":[\n\n"; foreach (`echo "0 | S";vsx stat -v 2>/dev/null`){s/^\s*`?//; next unless /^\d/; @split = split/\s{1,}/;if ($split[2] eq "S"){($vsname) = `source /etc/profile.d/vsenv.sh; vsenv $split[0] 2>/dev/null` =~ /_(.*?) /; foreach (`grep identityServer /tmp/enabled_blades_vs$split[0] &>/dev/null ; source /etc/profile.d/vsenv.sh; vsenv $split[0] 2>/dev/null ; adlog a dc`){chomp; if (/Context is/){($vs_name) = /Context is set to Virtual Device .*?_(.*?)\s/} next if /=/; @split_pdp = split/\s{1,}/; next unless $split_pdp[1] =~ /^\d/; if ($first ne 0){print ","}$first++; print "\n{\t\t\"{#VSID}\":\"$split[0]\", \t\t\"{#VSNAME}\":\"$vsname\", \t\t\"{#IP}\":\"$split_pdp[1]\"}";}}}print "\n\t]}\n";'
#
#perl -e '($search) = `cat /etc/resolv.conf` =~ /search\s{1,}(.*?)\s{1,}/; $search = "Unknown" unless $search; $first = 0; print "{\n"; print "\t\"data\":[\n\n"; if ($first == 0){ $hostname = `hostname`; chomp $hostname; print "\n{\t\t\"{#VSNAME}\":\"$hostname\", \t\t\"{#VSID}\":\"0\", \t\t\"{#HOST}\":\"$hostname\", \t\t\"{#SEARCH}\":\"$search\"}"} foreach (`vsx stat -v 2>/dev/null`){s/^\s*`?//; next unless /^\d/; @split = split/\s{1,}/;if ($split[2] eq "S"){($vsname) = `source /etc/profile.d/vsenv.sh; vsenv $split[0] 2>/dev/null` =~ /_(.*?) /;  $first++; print ",\n{\t\t\"{#VSNAME}\":\"$vsname\", \t\t\"{#VSID}\":\"$split[0]\", \t\t\"{#HOST}\":\"$hostname\", \t\t\"{#SEARCH}\":\"$search\"}";}}print "\n\t]}\n";'


#Get VS info
my %vs = get_vs_detailed('type' => 'S');
unless (%vs) {
  debug("No data from get_vs_detailed(). Something is wrong", "fatal", \((caller(0))[3]) );
  die "No data from get_vs_detailed(). Something is wrong. Fatal error";
}

my $resolv_search = get_resolv_search();
if ($resolv_search) {
  debug("Data from get_resolv_search(): $resolv_search", "debug", \[caller(0)] ) if $debug;
}
else {
  my $msg_die = "No data from get_resolv_search. Something is wrong";
  debug($msg_die, "fatal", \((caller(0))[3]) );
  #die $msg_die;
}

my $hostname = get_hostname();
if ($hostname) {
  debug("Data from get_hostname(): $hostname", "debug", \[caller(0)] ) if $debug;
}
else {
  my $msg_die = "No data from get_hostname(). Something is wrong";
  debug($msg_die, "fatal", \((caller(0))[3]) );
  die $msg_die;
}



my %json;
foreach my $vs_key (keys %vs) {
  debug("key: '$vs_key'. Value: '$vs{$vs_key}'", "debug", \[caller(0)] ) if $debug;

  my $id                = $vs{$vs_key}{'id'}; 
  my $name              = $vs{$vs_key}{'name'}; 
  my $type              = $vs{$vs_key}{'type'}; 
  my $access_policy     = $vs{$vs_key}{'access_policy'}; 
  my $threat_policy     = $vs{$vs_key}{'threat_policy'}; 
  my $installed_policy  = $vs{$vs_key}{'installed_policy'}; 
  my $sic               = $vs{$vs_key}{'sic'}; 

  my $host_name         = $vs{$vs_key}{'host_name'}; 
  my $host_ip           = $vs{$vs_key}{'host_ip'}; 
  my $host_int          = $vs{$vs_key}{'host_int'}; 

  my $vs_ip             = $vs{$vs_key}{'vs_ip'}; 
  my $vs_int            = $vs{$vs_key}{'vs_int'}; 

  next unless $argv{'type'} eq "any" or $argv{'type'} eq $type;

  #TODO.
  #Legg til '' if not defined

  $access_policy    = '' unless defined $access_policy;
  $threat_policy    = '' unless defined $threat_policy;
  $installed_policy = '' unless defined $installed_policy;

  
  push @{$json{'data'}}, {
    '{#VSID}'           => $id,
    '{#VSNAME}'         => $name,
    '{#TYPE}'           => $type,
    '{#ACCESS_POLICY}'  => $access_policy,
    '{#THREAT_POLICY}'  => $access_policy,
    '{#INSTALLED}'      => $installed_policy,
    '{#SIC}'            => $sic,
    '{#SEARCH}'         => $resolv_search,

    '{#HOST}'           => $hostname,
    '{#HOST_IP}'        => $host_ip,
    '{#HOST_INT}'       => $host_int,

    '{#VS_IP}'          => $vs_ip,
    '{#VS_INT}'         => $vs_int,
  };
}

my $json = init_json();

#Convert hash to JSON
my $json_string = $json->encode(\%json);

#print JSON to zabbix
print $json_string;





