#!/usr/bin/perl

BEGIN {
  if ($ARGV[0] eq "--zabbix-test-run"){
    print "ZABBIX TEST OK";
    exit;
  }
}

print "hello\n";
