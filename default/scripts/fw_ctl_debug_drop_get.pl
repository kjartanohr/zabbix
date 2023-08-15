#!/bin/perl

#Set the path for modules
BEGIN{push @INC,"/usr/share/zabbix/bin/perl-5.10.1/lib"}


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
my $vsid_input        = shift @ARGV;                                              #What VSID to get the value from
my $name_input        = shift @ARGV || die 0;                                     #What name to get the value from
my $log_file          = shift @ARGV || "/tmp/zabbix/fw_ctl_debug_drop/drop.log";  #What log file to use
$0                    = "fw ctl debug drop get value VER $version";               #Set the process name


foreach (`cat $log_file 2>/dev/null`){
  debug("Reading from old log file $_");
  chomp; 

  #Split the data in to variables
  my ($vsid,$err,$count) = split/,,,/;

  #Sanity check the input. Skip the line if something is wrong with it
  #next unless $vsid && $err && $count;

  $vsid =~ s/^vs_//;

  if ( ($name_input eq $err) && ($vsid_input eq $vsid) ){
    print $count || 0;
    exit;
  }
}

#If everything failed print 0 to zabbix
print 0;

sub debug {
  print "DEBUG: $_[0]\n" if $debug;
}
