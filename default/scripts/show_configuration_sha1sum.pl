#!/bin/perl
BEGIN{push @INC,"/usr/share/zabbix/bin/perl-5.10.1/lib"}

use warnings;
use strict;

$0 = "perl show configuration sha1sum";
$|++;
$SIG{CHLD} = "IGNORE";
$ARGV[0] = "" unless $ARGV[0];

if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

my $debug           = 0; 
my $out;

$debug = 1 if $ARGV[0] eq "debug";

my @ignore = (
  "add vpn tunnel ",
  "set hostname ",
  "set interface .*? ipv4-address",
  "set user .*? password-hash",
  "set user .*? gid .*? shell",
  "set user .*? realname ",
  "set bgp external remote-as .*secret ",
  "set as .*",
  "set interface .*? auto-negotiation", 
);

LOOP:
foreach (sort `clish -c "show configuration"`){
  next if /^$/;
  next if /^#/;

  foreach my $ignore (@ignore) {
    next LOOP if $_ =~ /$ignore/;
  }

  print if $debug;
  $out .= $_;
}

my $checksum = `echo "$out"|sha1sum`;
$checksum =~ s/ .*//;
print $checksum;
