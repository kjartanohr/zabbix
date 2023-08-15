#!/bin/perl

#Set the path for modules
BEGIN{push @INC,"/usr/share/zabbix/bin/perl-5.10.1/lib"}

use warnings;
#use strict;
use JSON;
my $json = JSON->new ();
$json->pretty([1]);

 

#Print the data immediately. Don't wait for full buffer
$|++;

#Zabbix test that will have to print out zabbix test ok. If not, the script will not download
if ($ARGV[0] && $ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}


#Print the input the script is started with
debug("$0 Input data ".join " ",@ARGV);

my $debug             = 0;                                                        #Set to 1 if you want debug data and no fork
my $version           = 100;                                                      #Version of the script. If the version runnin is older than this, kill the old script
my $log_file          = shift @ARGV || "/tmp/zabbix/fw_ctl_debug_drop/drop.log.tmp";  #What log file to use
$0                 = "fw ctl debug drop discovery VER $version";               #Set the process name
my %db                = ();                                                       #Set an empty hash
my $vsx_stat          = `vsx stat -v 2>&1`;                                            #Get the output from vsx stat
my @json;


#Build the hash from log file
foreach (`cat $log_file 2>/dev/null`){
  debug("Reading from old log file $_");
  chomp; 

  #Split the data in to variables
  my ($vsid,$err,$count) = split/,,,/;

  #Sanity check the input. Skip the line if something is wrong with it
  next unless $vsid && $err && $count;

#  next if $err eq "Total drop";
  next if $err eq "Geo Protection";
  next if $err eq "Drop template (inbound)";
  next if $err eq "Successfully forwarded to other member";
  next if $err eq "PSL Drop: UP_LIMIT";

  next if $count < 100_000;

  $vsid =~ s/^vs_//;
  my $vsname = get_vsname($vsid);
  push @json, ("{#VSNAME},,,$vsname;;;{#VSID},,,$vsid;;;{#NAME},,,$err;;;{#COUNT},,,$count");
}

my $json_out = create_json(@json);
print $json_out;

sub create_json {
my @data3_array;

 

  my $count1 = 0;
  foreach (@_){
    my @split = split/;;;/; 
    my $count2 = 0;

 
    foreach $value (@split) {
      my $count3 = 0;
      
      my ($name,$val) = split/,,,/, $value;
      $data3_array[$count1]{$name} = $val;
      
      $count2++;
    }
    $count1++;
  }


  $json_data = {
    data => [
      @data3_array,
    ],
  };


  my $json_encoded = $json->encode($json_data);
  return $json_encoded

}

sub debug {
  print "DEBUG: $_[0]\n" if $debug;
}

sub get_vsname {
  my $vsid = shift;
  die "No VSID given" unless defined $vsid;

  if ($vsid == 0){
    chomp (my $hostname = `hostname`);
    return $hostname;
  }

  my ($vsname) = $vsx_stat =~ / $vsid \| . (.*?) /;

  return $vsname;
  
}
