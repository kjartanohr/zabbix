#!/bin/bash
#bin

# 2023-04-04 11:21:28

if [ $1 ] && [ $1 = '--zabbix-test-run' ]
then
  echo ZABBIX TEST OK;
  exit;
fi


# source bashrc
test -f $HOME/.bashrc && source $HOME/.bashrc

# search for path
#unset DIR_SCRIPTS;
test $DIR_ZABBIX || export DIR_ZABBIX=`perl -e '$debug = 0; foreach my $line (readline STDIN){chomp $line; next if $line =~ /^\s{0,}#/; next unless $line; $line =~ s/^\s{1,}//; $line =~ s/:{2,}/:/g; print $_ if $debug; if ($line =~ /:/){push @path, $_ foreach split/:/, $line; }else{push @path, $line} } foreach (@path){print "$_\n" if $debug; s/:{2,}/:/g; s/^[\s]|[\s\/]$//g; next unless -d $_; print $_; exit}' <<EOF

  # Check Point zabbix install
  /usr/share/zabbix

  # Android termux
  $HOME/share/zabbix

  # Div
  $HOME/zabbix
  $HOME/bin/zabbix
  $HOME/tmp/zabbix
  /tmp/zabbix

EOF
`
test $DIR_ZABBIX  && DIR_ZABBIX_SCRIPTS="$DIR_ZABBIX_SCRIPTS/repo/scripts/auto";
test $DIR_ZABBIX  && DIR_ZABBIX_FILES="$DIR_ZABBIX_SCRIPTS/repo/files/auto";
test $DIR_ZABBIX  && DIR_ZABBIX_LIB="$DIR_ZABBIX_SCRIPTS/repo/lib";

test $DIR_ZABBIX_SCRIPTS || export DIR_ZABBIX_SCRIPTS="/usr/share/zabbix/repo/scripts/auto/";



$DIR_ZABBIX_SCRIPTS/download_repo-scripts.sh
$DIR_ZABBIX_SCRIPTS/download_repo-lib.sh
$DIR_ZABBIX_SCRIPTS/download_repo-files.sh
$DIR_ZABBIX_SCRIPTS/download_repo-rpms.sh

$DIR_ZABBIX_SCRIPTS/symlink_scripts.pl
