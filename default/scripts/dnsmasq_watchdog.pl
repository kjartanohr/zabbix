#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;

$0 = "perl dnsmask watchdog 101";
$|++;
$SIG{CHLD} = "IGNORE";


my $dir_tmp        = "/tmp/zabbix/dnsmasq_watchdog";
our $file_debug    = "$dir_tmp/debug.log";
our $debug         = 0;

create_dir($dir_tmp);

my %vs             = get_all_vs();

zabbix_check($ARGV[0]);

debug("Script started\n");

#Check if config files for dnsmasq is created
create_config();

#Start dnsmasq if not running 
start_dnsmasq();


sub start_dnsmasq {
  my $ps = `ps xau`;
  foreach my $item (%vs) {
    next unless $vs{$item};
    my $vsname = $vs{$item};

    if ($ps =~ m#dnsmasq.*/etc/dnsmasq_$vsname.conf#) {
      debug("dnsmasq running for $vsname\n");
    }
    else {
      print "dnsmasq not running for $vsname. Starting\n";

      my ($version) = `dnsmasq -v` =~ /Dnsmasq version (.*?) /;

      if ($version eq "2.45") {
        system "source /etc/profile.d/vsenv.sh; vsenv $item &>/dev/null ; dnsmasq -C /etc/dnsmasq_$vsname.conf";
      }
      elsif ($version eq "2.82") {
        system "source /etc/profile.d/vsenv.sh; vsenv $item &>/dev/null ; dnsmasq  --local-ttl=3600 --min-cache-ttl=3600 -c 1000000 -C /etc/dnsmasq_$vsname.conf";
      }
      else {
        print "Unknown version of dnsmasq. using defaults. Need a human here\n";
        system "source /etc/profile.d/vsenv.sh; vsenv $item &>/dev/null ; dnsmasq -C /etc/dnsmasq_$vsname.conf";
      }

      #system "source /etc/profile.d/vsenv.sh; vsenv $item &>/dev/null && dnsmasq -q --all-servers -c 1000 -N -C /etc/dnsmasq_$vsname.conf";
    }
  }

  #dnsmasq -C /etc/dnsmasq_MOBILE-gw.conf  
}


sub create_config {
  foreach my $item (%vs) {
    next unless $vs{$item};
    my $vsname = $vs{$item};
    debug("Checking if config file exists for $vsname\n");

    unless (-f "/etc/dnsmasq_$vsname.conf"){
      print "Could not find config file for $vsname. Creating av symlink to /etc/dnsmasq.conf\n";
      system "ln -s /etc/dnsmasq.conf /etc/dnsmasq_$vsname.conf";
    }else {
      debug("Config file found for $vsname. Skipping\n");
    }
  }
}
