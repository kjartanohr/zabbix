#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;

$0 = "perl Check Point isp redundancy check VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

my $vsid           = shift @ARGV || 0;
my $dir_tmp        = "/tmp/zabbix/isp_redundancy/$vsid/";
our $file_debug    = "$dir_tmp/debug.log";
our $debug         = 1;

create_dir($dir_tmp);


#End of standard header


#fork a child and exit the parent
#Don't fork if $debug is true
unless ($debug){
  fork && exit;
}

#Closing so the parent can exit and the child can live on
#The parent will live and wait for the child if there is no close
#Don't close if $debug is true
unless ($debug) {
  close STDOUT;
  close STDIN;
  close STDERR;
}

#Eveything after here is the child

my (@isp_1_icmp_ip) = (
  "10.0.1.1", #Check Point sin default gateway til ISP 1
  "10.1.1.1", #ISP 1 hopp 2
  "8.8.8.8",  #Google IP ute på internett
  "1.1.1.1",  #Cloudflare IP ute på internett
);

my (@isp_2_icmp_ip) = (
  "10.0.2.1", #Check Point sin default gateway til ISP 2
  "10.1.2.1", #ISP 2 hopp 2
  "8.8.8.8",  #Google IP ute på internett
  "1.1.1.1",  #Cloudflare IP ute på internett
);

my %isp_1_resolve_domain = (
  "vg.no", "8.8.8.8", #Resolve vg.no mot DNS server 8.8.8.8 via ISP 1
  "bt.no", "8.8.8.8", #Resolve vg.no mot DNS server 8.8.8.8 via ISP 1
);

my %isp_2_resolve_domain = (
  "vg.no, "8.8.8.8", #Resolve vg.no mot DNS server 8.8.8.8 via ISP 1
  "bt.no, "8.8.8.8", #Resolve vg.no mot DNS server 8.8.8.8 via ISP 1
);

my @isp_1_http_curl = (
  "https://vg.no/index.html", #Kjø curl mot vg.no via ISP 1
  "https://bt.no/index.html", #Kjø rcurl mot vg.no via ISP 1


my @isp_2_http_curl = (
  "https://vg.no/index.html", #Kjø curl mot vg.no via ISP 1
  "https://bt.no/index.html", #Kjø rcurl mot vg.no via ISP 1

);


my $isp_1_ext_interface = "bond0.101"; #WAN/EXT interface ut fra brannmuren mot ISP 1
my $isp_2_ext_interface = "bond0.102"; #WAN/EXT interface ut fra brannmuren mot ISP 2


foreach my $ip (@isp_1_icmp_ip) {
  #ping $ip;
  #if failed, run isp_1_down();

  #if ping OK and ISP_LINK_1 is down, run isp_1_up
}



sub isp_1_down {
  system "fw -d isp_link ISP_LINK_1 down";
}

sub isp_1_up {
  system "fw -d isp_link ISP_LINK_1 up";
}

