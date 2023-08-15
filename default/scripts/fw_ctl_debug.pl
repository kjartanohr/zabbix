#!/bin/perl

if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

#Exit if this is a mamagement
exit if `cpprod_util CPPROD_IsMgmtMachine 2>&1` =~ /1/;

$vsid     = shift @ARGV || 0;
$file     = "/tmp/zabbix/fw_ctl_debug_diff/diff_vs$vsid.last";
$file_tmp = "/tmp/zabbix/fw_ctl_debug_diff/diff_vs$vsid.now";

system "mkdir -p /tmp/zabbix/fw_ctl_debug_diff/" unless -d "/tmp/zabbix/fw_ctl_debug_diff/";

open $fh_w,">", $file_tmp or die "Can't write to $file_tmp: $!";

foreach (`fw ctl debug 2>&1`){
  chomp;
  next unless $_;
  ($module) = /Module: (.*)/ if /Module:/;
  ($enabled) = /Enabled Kernel debugging options: (.*)/ if /Enabled Kernel/;

  if ($module && $enabled) {
     #next if $module eq "fw";
     $enabled =~ s/ drop//g;
     print $fh_w "$module $enabled\n" unless $enabled eq "None";
     ($module,$enabled) = undef,undef;
  }
}

close $fh_w;

if (-f $file) {
  foreach (`diff $file $file_tmp`){
    next unless /^<|^>/;
    print;
  }
}

rename $file_tmp,$file;
