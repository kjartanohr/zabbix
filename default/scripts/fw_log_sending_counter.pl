#!/usr/bin/perl5.32.0
#bin
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;

$0 = "perl fw log counter VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

my $dir_tmp        = "/tmp/zabbix/fw_log_counter/";
our $file_debug    = "$dir_tmp/debug.log";
our $debug         = 0;
my $counter        = 0;

create_dir($dir_tmp);


#End of standard header

foreach my $vsid (get_all_vs_id()) {
  
  foreach (`source /etc/profile.d/vsenv.sh; vsenv $vsid &>/dev/null ; cpstat fw -f log_connection`) {
    next unless /^\|\d.*Log-Server/;
    
    my ($log_counter) = /(\d{1,})\|$/;

    $counter += $log_counter;
  }
}

print $counter;

__END__
cpstat fw -f log_connection                                         

Overall Status:                 0
Overall Status Description:     Security Gateway is reporting logs as defined
Local Logging Mode Description: Logs are written to log server
Local Logging Mode Status:      0
Local Logging Sending Rate:     0
Log Handling Rate:              8


Log Servers Connections
--------------------------------------------------------
|IP        |Status|Status Description     |Sending Rate|
--------------------------------------------------------
|10.99.3.10|     0|Log-Server Connected   |           6|
|10.99.3.11|     2|Log-Server Disconnected|           0|
--------------------------------------------------------


