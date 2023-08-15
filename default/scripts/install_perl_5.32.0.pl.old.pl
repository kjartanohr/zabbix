#!/bin/perl
#bin

#This will extract perl version 5.32.0 and create a symlink for the binary

my $url_perl_5_32 = "http://zabbix.kjartanohr.no/zabbix/repo/default/files/perl-5.32.0.tar.gz";
my $url_perl_5_10 = "http://zabbix.kjartanohr.no/zabbix/repo/default/files/perl-5.10.1_compiled.tar.gz";

if (defined $ARGV[0] and $ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

#if (-f "/usr/bin/perl5.32.0") {
#  print "perl already installed\n";
#  exit;
#}

# [Expert@gw-cp-kfo:0]# du -s /usr/share/zabbix/bin/perl-5.32.0/
# 148628  /usr/share/zabbix/bin/perl-5.32.0/
# [Expert@gw-cp-kfo:0]#

my $cmd_du_dir = `du -s /usr/share/zabbix/bin/perl-5.32.0/`;
chomp $cmd_du_dir;
if ($cmd_du_dir eq '148628'){
  print "perl already installed\n";
  exit;
}


exit unless -f "/usr/share/zabbix/repo/files/auto/perl-5.32.0.tar.gz";

system "rm -Rf /usr/share/zabbix/bin/perl-5.32.0 &>/dev/null";

system "tar xfz /usr/share/zabbix/repo/files/auto/perl-5.32.0.tar.gz -C /usr/share/zabbix/bin/ &>/dev/null";

system "ln -s /usr/share/zabbix/bin/perl-5.32.0/bin/perl /usr/bin/perl5.32.0 &>/dev/null";
