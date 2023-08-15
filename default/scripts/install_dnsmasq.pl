#!/usr/bin/perl5.32.0
#bin
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;
use File::Copy;

my $file_repo      = "/usr/share/zabbix/repo/files/auto/dnsmasq";
my $file_local     = "/usr/sbin/dnsmasq";
my $file_local_old = "/usr/sbin/dnsmasq_old";

#This will rename the old dnsmasq binary and copy in the new one

if (defined $ARGV[0] and $ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

if (`$file_local -v` =~ /Dnsmasq version 2.82 /) {
  print "dnsmasq already installed\n";
  exit;
}


unless (-f $file_repo) {
  print "Could not find $file_repo. Need a human here\n";
  exit;
}

unless (-f $file_local) {
  print "Could not find $file_local. Need a human here\n";
  exit;
}

rename $file_local,$file_local_old or die "Can't rename $file_local,$file_local_old: $!\n";

copy($file_repo,$file_local) or die "Can't copy $file_repo to $file_local: $!\n";
chmod 0755, $file_local;

unless (`$file_local -v` =~ /Dnsmasq version 2.82 /) {
  print "Tried to upgrade dnsmasq but failed. Need a human\n";
  exit;
}

system "pkill dnsmasq &>/dev/null";
