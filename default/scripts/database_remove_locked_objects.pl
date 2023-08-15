#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;

$0 = "perl NAME OF SCRIPT VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

#Eveything after here is the child

my @changes;
my $cmd_select = qq# psql_client cpm postgres -c "SELECT objid, name, dlesession, cpmitable, subquery1.lockingsessionid, subquery1.operation FROM dleobjectderef_data, (SELECT lockedobjid, lockingsessionid, operation FROM locknonos) subquery1 WHERE subquery1.lockedobjid = objid and not deleted and dlesession >=0;"
#;

foreach (`$cmd_select`){
  print;

  s/^\s{1,}//; 
  my @split = split/\s{1,}/; 
 
  next unless /-.*?.*?-.*?-/; 
  next if /---/; 

  my $cmd_delete = qq#psql_client cpm postgres -c "delete from locknonos where lockedobjid='$split[0]';" #;

  #print "$cmd_delete\n";
  push @changes, $cmd_delete;
}

foreach (@changes) {
  print "$_\n";
}

print "Do you want to continue? This will delete all the locked objects listet above y/N: ";
chomp (my $answer = <>);

die "Cancel. You did not press y" unless $answer eq "y";

foreach (@changes) {
  print "$_\n";
  system $_;
}
