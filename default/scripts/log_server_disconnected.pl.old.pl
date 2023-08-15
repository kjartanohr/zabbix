#!/usr/bin/perl5.32.0
#bin
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;

$0 = "perl log server disconnected VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

my $vsid           = shift @ARGV || 0;
my $dir_tmp        = "/tmp/zabbix/log_server_disconnected/$vsid";
our $file_debug    = "$dir_tmp/debug.log";
our $debug         = 0;

create_dir($dir_tmp);


#End of standard header


debug("Running CMD source /etc/profile.d/vsenv.sh; vsenv $vsid &>/dev/null ; cpstat fw -f log_connection\n");

foreach (`source /etc/profile.d/vsenv.sh; vsenv $vsid &>/dev/null ; cpstat fw -f log_connection`) {
  debug($_);
  next unless /Log-Server Disconnected/;
  s/\|/ /g;
  s/^\s{1,}//g;

  my ($ip,$status,$desc,$rate) = split/\s{1,}/;

  print "Log server disconnected $ip\n";

}


__END__

[Expert@cp-ext-1:2]# cpstat fw -f log_connection

Overall Status:                 1
Overall Status Description:     Security Gateway is unable to report logs to one or more log servers
Local Logging Mode Description: Writing logs locally due to connectivity problems
Local Logging Mode Status:      2
Local Logging Sending Rate:     42
Log Handling Rate:              42


Log Servers Connections
---------------------------------------------------------
|IP         |Status|Status Description     |Sending Rate|
---------------------------------------------------------
|10.14.16.35|     0|Log-Server Connected   |          40|
|10.14.16.25|     1|Log-Server Disconnected|           0|
---------------------------------------------------------
