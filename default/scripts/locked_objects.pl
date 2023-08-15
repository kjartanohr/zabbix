#!/bin/perl
#bin

if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}


$days_old = shift @ARGV || "30";

foreach (`psql_client -t cpm postgres -c "select creator,lastmodifytime from worksession where state = 'OPEN' and (numberoflocks != '0' or numberofoperations != '0');" 2>/dev/null`){
  ($username,$time) = split /\|/;

  $username =~ s/\s//g;
  next unless $username;

  $time =~ s/\d\d:.*//;
  $time =~ s/\s//g;
  $unix = `date -d "$time" +%s`;

  next unless (time-$unix) > ($days_old*60*60*24);

  print "$username $time\n";
}
