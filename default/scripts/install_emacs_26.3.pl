#!/bin/perl

#This will extract emacs and create a symlink for the binary

if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

if (`emacs --version` =~ /26.3/) {
  print "emacs already installed\n";
  exit;
}

print "emacs not installed\n";

exit unless -f "/usr/share/zabbix/repo/files/auto/emacs-26.3.tar.gz";

system "rm -Rf /usr/share/emacs/ &>/dev/null";
system "mkdir /usr/share/emacs/ &>/dev/null";
system "tar xfz /usr/share/zabbix/repo/files/auto/emacs-26.3.tar.gz  -C /usr/share/ &>/dev/null";

system "ln -s /usr/share/emacs/emacs /usr/bin/ &>/dev/null";

