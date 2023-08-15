#!/bin/perl

if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}


my $debug = 0;

#Check if timezone is Oslo. If not, exit
#unless (`clish -c "show timezone" 2>&1` =~ /Oslo/){
#  print "Not timezone Oslo. Exit\n" if $debug;
#  print 9998;
#  exit;
#}


#Get date from zabbix.kjartanohr.no
my $out = `curl_cli -I http://zabbix.kjartanohr.no/ 2>&1`;
print "HTTP HEADER from URL $out\n" if $debug;

#Get the date from header
my ($date) = $out =~ /Date: (.*? GMT)/;
print "Date from URL $date\n" if $debug;

unless ($date){
  print "Could not get date from URL\n" if $debug;
  print 9999;
  exit;
}

#Convert remote date to unix time 
my $t_r = `date +"%s" -d "$date"`;
chomp $t_r;
print "Remote time in unix sec $t_r\n" if $debug;

#Convert local time to unix time
$t_l = `date +"%s"`;
chomp $t_l;
print "Local time in unix sec $t_l\n" if $debug;

#Convert time +2 hours
#$t_r += 120*60;
#print "Remote time: $t_r == Local time: $t_l\n" if $debug;

if ( ($t_r - $t_l) > (2*60) || ($t_l - $t_r) > (2*60) ){
  print "Time is wrong\n" if $debug;
  #my $cmd = qq#date +%s -s "\@$t_r"#;
  my $cmd = qq#date -s "$date" #;
  print "$cmd\n" if $debug;
  system qq#$cmd &>/dev/null#;

  print 2;
}
else {
  print 1;
}
