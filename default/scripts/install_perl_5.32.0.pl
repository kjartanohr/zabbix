#!/bin/perl
#bin

# 2023-04-11 10:53:41
# Lagt til 3 enkle sjekker

#This will extract perl version 5.32.0 and create a symlink for the binary

my $url_perl_5_32     = "http://zabbix.kjartanohr.no/zabbix/repo/default/files/perl-5.32.0.tar.gz";
my $url_perl_5_10     = "http://zabbix.kjartanohr.no/zabbix/repo/default/files/perl-5.10.1_compiled.tar.gz";
my $debug             = 0;
$debug                = 1 if grep/debug/, @ARGV;
my $dir_perl_5_32     = "/usr/share/zabbix/bin/perl-5.32.0";
my $dir_perl_size     = 148628;
my $file_perl_5_32    = "/usr/share/zabbix/repo/files/auto/perl-5.32.0.tar.gz";

my $cmd_test_1        = qq#perl5.32.0 -e 'BEGIN{require "/usr/share/zabbix/repo/lib/lib.pm"} use warnings; print "OK"'#;
my $cmd_test_2        = qq#find /usr/share/zabbix/bin/perl-5.32.0/ 2>/dev/null | wc -l#;
my $cmd_test_2_ok     = "8046";

my $failed            = 0;

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

my $cmd_du_dir = `du -s $dir_perl_5_32`;
my ($dir_perl_5_32_size_local) = $cmd_du_dir =~ /^(\d{1,})/;

my $dir_perl_5_32_size_ok = 1;
$dir_perl_5_32_size_ok    = 0 if $dir_perl_5_32_size_local > ( $dir_perl_size + 50 );
$dir_perl_5_32_size_ok    = 0 if $dir_perl_5_32_size_local < ( $dir_perl_size - 50 );

if ($dir_perl_5_32_size_ok){
  print "perl already installed\n";
}
else {
  print "perl is not installec correctly. Folder size should be '$dir_perl_size'. Folder size is: '$dir_perl_5_32_size_local'\n";
  $failed = 1;
}

my $cmd_test_2_out = `$cmd_test_2`;
chomp $cmd_test_2_out;
if ($cmd_test_2_out eq $cmd_test_2_ok){
  print "test 2 ok\n";
}
else {
  print "test 2 FAILED. Should be: '$cmd_test_2_ok'. Is: '$cmd_test_2_out'\n";
  $failed = 1;
}


# test 1 START
{
  my $cmd_test_1_out = `$cmd_test_1`;
  if ($cmd_test_1_out eq 'OK'){
    print "test 1 ok. perl 5.32.0 installed\n";
    exit;
  }
  else {
    print "test 1. perl 5.32.0 FAILED. '$cmd_test_1_out'\n";
    $failed = 1;
  }
}
# test 1 END

if ($failed == 0){
  print "all tests OK\n";
  exit;
}

if (not -f $file_perl_5_32){
  print "Missing perl tar gz $file_perl_5_32\n";
  exit;
}

system "rm -Rf $dir_perl_5_32 &>/dev/null";

system "tar xfz /usr/share/zabbix/repo/files/auto/perl-5.32.0.tar.gz -C /usr/share/zabbix/bin/ &>/dev/null";

system "ln -s $dir_perl_5_32/bin/perl /usr/bin/perl5.32.0 &>/dev/null";

# perl5.32.0 -e 'BEGIN{require "/usr/share/zabbix/repo/lib/lib.pm"} use warnings; print "OK"'

# test 1 START
my $cmd_test_1_out = `$cmd_test_1`;
if ($cmd_test_1_out eq 'OK'){
  print "perl 5.32.0 installed\n";
}
else {
  print "perl 5.32.0 install FAILED. '$cmd_test_1_out'\n";
}
# test 1 END
