#!/bin/perl

$0 = "dnsmask watchdog";

if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}


my %vs = get_all_vs();
my $debug = 0;

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
      print "dnsmasq running for $vsname\n" if $debug;
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
    print "Checking if config file exists for $vsname\n" if $debug;

    unless (-f "/etc/dnsmasq_$vsname.conf"){
      print "Could not find config file for $vsname. Creating av symlink to /etc/dnsmasq.conf\n";
      system "ln -s /etc/dnsmasq.conf /etc/dnsmasq_$vsname.conf";
    }else {
      print "Config file found for $vsname. Skipping\n" if $debug;
    }
  }
}


sub get_all_vs {
  my %return;

  chomp(my $hostname = `hostname`);
  $return{0} = $hostname;
  foreach (`vsx stat -v 2>/dev/null`){
    s/^\s*`?//;
    next unless /^\d/;
    my @split = split/\s{1,}/;

    next unless $split[2] eq "S";

    my ($vsname) = `source /etc/profile.d/vsenv.sh; vsenv $split[0] 2>/dev/null` =~ /_(.*?) /;
  
    $return{$split[0]} = $vsname;
  }

  return %return;
}
