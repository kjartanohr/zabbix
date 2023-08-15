#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;

$0 = "perl licensing VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

my $vsid           = shift @ARGV || 0;
my $dir_tmp        = "/tmp/zabbix/licensing/$vsid/";
our $file_debug    = "$dir_tmp/debug.log";
our $debug         = 0;

my $cmd            = "source /etc/profile.d/vsenv.sh; vsenv $vsid &>/dev/null ; cpstat os -f licensing";

create_dir($dir_tmp);

#Delete log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);


#my $cmd_out = `$cmd`;
my $cmd_out = join "", <DATA>;
my $table = 0;


foreach (split /\n/, $cmd_out) {
  s/\s{1,}//g;
  s/^\s{1,}//;
  s/^\|//;

  $_ = lc $_;

  my ($id, $blade_name, $entitlement_status, $expiration_date, $expiration_impact, $blade_activation, $total_quota, $used_quota) = split/\|/;

  next unless defined $id and $id =~ /^\d/;

  if ($entitlement_status eq "evaluation" and $blade_activation == 1) {
    print "Evaluation found for $blade_name\n";
  }

  if ($used_quota > $total_quota) {
    print "Quota used is higher than license quota $blade_name\n";
  }

  $table++;


}

if ($table == 0) {
  print "No license found in cpstat\n";
}

my %check = (
  "Account ID" => '^\d',
  "Package description" => '.',
  "CK Signature" => '.',
  "Container SKU" => '.',
  "Support level" => '.',
  "Support expiration" => '\d',
  "Activation status" => '2',
);

foreach my $key (keys %check) {
  my $value = $check{$key};

  my ($cpstat_key, $cpstat_value) = $cmd_out =~ /($key):\s{1,}(.*)/;

  if ($cpstat_value =~ /$value/) {
    #print "$cpstat_key OK\n";
  }
  else {
    print "$key FAILED\n";
  }

}


__DATA__



Licensing table
------------------------------------------------------------------------------------------------------------------------------
|ID  |Blade name                |Entitlement status|Expiration date|Expiration impact|Blade activation|Total quota|Used quota|
------------------------------------------------------------------------------------------------------------------------------
|   0|Firewall                  |Evaluation        |     1621019535|                 |               1|          0|         0|
|   1|IPSec VPN                 |Evaluation        |     1621019535|                 |               0|          0|         0|
|   2|IPS                       |Evaluation        |     1645138800|                 |               1|          0|         0|
|   3|Anti-Spam & Email Security|Evaluation        |     1621019535|                 |               0|          0|         0|
|   4|Application Control       |Evaluation        |     1621019535|                 |               0|          0|         0|
|   5|URL Filtering             |Evaluation        |     1621019535|                 |               0|          0|         0|
|   6|Anti-Virus                |Evaluation        |     1621019535|                 |               0|          0|         0|
|   7|Anti-Bot                  |Evaluation        |     1621019535|                 |               0|          0|         0|
|   8|Threat Emulation Local    |Not Entitled      |     4294967295|                 |               0|          0|         0|
|   9|Threat Emulation Cloud    |Entitled          |     1645142400|                 |               0|          0|         0|
|  10|Threat Extraction         |Entitled          |     1645142400|                 |               0|          0|         0|
|  11|Data Loss Prevention      |Evaluation        |     1621019535|                 |               0|          0|         0|
|  13|Content Awareness         |Evaluation        |     1621019535|                 |               0|          0|         0|
|2000|Mobile Access             |Evaluation        |     1621019535|                 |               0|          0|         0|
|  12|Virtual Systems           |Evaluation        |     1621019535|                 |               1|         60|        10|
------------------------------------------------------------------------------------------------------------------------------

Account ID:          0007839696
Package description: 23800 NGTX Appliance - High Performance Package (HPP)
Container CK:        00:1C:7F:42:E5:52
CK Signature:        as69oT6WNF35uzCSxkE7Ec5Fj4N3FGQ738im
Container SKU:       CPAP-SG23800-NGTX-HPP
Support level:       Collaborative Enterprise Support - Premium Add-on for Products
Support expiration:  1645142400
Activation status:   2


