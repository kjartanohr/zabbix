#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

#use warnings;
#use strict;

$0 = "perl fw worker discovery VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);


my  $action        = shift @ARGV || die "Need an action to start the script: discovery, cpu\n";
my  $dir_tmp       = "/tmp/zabbix/fw_worker";
our $file_debug    = "$dir_tmp/debug.log";
our $debug         = 0;

exit unless is_gw();

create_dir($dir_tmp);

#End of standard header

if ($action eq "discovery") {
  discovery();
}
  elsif ($action eq "cpu") {
  my $name = shift @ARGV || die "Need a process name to get CPU usage. Missing input\n";

  print int get_cpu_usage_process($name);

}
else {
  print "Missing action on command input\n";
}

  
sub discovery {
  my $first = 0;
  print "{\n";
  print "\t\"data\":[\n\n";
  
  
  foreach (run_cmd("top -H -b -n1","a")){
    s/^\s{1,}//;
    my @split = split/\s+/;
    my ($vsid) = /fwk(\d{1,})_/;
    $vsid = 0 unless $vsid;
  
    if (/fwk\d{1,}_\d{1,}|fw_worker_\d{1,}|fwk\d{1,}_dev_\d{1,}/){
  
      my $vs_name = get_vsname($vsid);
  
      if ($first ne 0){
        print ","
      }
  
      $first++;
  
      print "\n{\t\t\"{#VSID}\":\"$vsid\", \t\t\"{#NAME}\":\"$split[11]\", \t\t\"{#VSNAME}\":\"$vs_name\", \t\t\"{#CPU}\":\"$split[8]\"}";
    }
  } 
  
  print "\n\t]}";
}
