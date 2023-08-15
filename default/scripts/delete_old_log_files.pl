#!/usr/bin/perl5.32.0
#bin
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;

$0 = "perl delete old logs";
$|++;

zabbix_check($ARGV[0]);

our $debug                = 0;         #This needs to be 0 when running in production 
my $dry_run               = 0;
my $disk_space_minimum_gb = 20; #Delete all logs until there is at least $disk_space_minimum_gb free
my $logs_days_old         = 7;  #The  default is to keep $logs_days_old with old logs
my $files_deleted_counter = 0;


#Exit if this is a CP MGMT
#Exit if this is not a CP GW
exit unless `cpprod_util FwIsFirewallMgmt` =~ /0/;
exit if -f "/tmp/is_mgmt";
exit unless -f "/tmp/is_gw";
exit if `fwm ver 2>&1` =~ /is Check/;


#Delete logs older than $logs_days_old days
delete_logs_older_than_days($logs_days_old);

my $disk_available_gb = df("/var/log", "available", "GB");
debug("Disk available GB is $disk_available_gb\n");

if ($disk_available_gb < $disk_space_minimum_gb) {
  debug("Disk available $disk_available_gb is less than minimum disk available $disk_space_minimum_gb\n");
  
  my $days = $logs_days_old;

  until ($days == 0) {

    debug("Not enough disk space free. Will delete more");
    delete_logs_older_than_days($days);

    if ( df("/var/log", "available", "GB") > $disk_space_minimum_gb) {
      debug("Minimum disk space requeired required is reached. Exit\n");
      last;
    }
    $days--;
  }
}

print "Deleted $files_deleted_counter log files\n" if $files_deleted_counter;

debug("Check for free disk space after deleting files\n");

if ( df("/var/log", "available", "GB") < $disk_space_minimum_gb) {
  print "Could not delete enough log files to get to the minimum reqired free disk space. Need a human here\n";
  exit;  
}


sub delete_logs_older_than_days {
  my $days = shift || die "sub delete_logs_older_than_days; Need input for days\n";
  debug("sub delete_logs_older_than_days: input days $days\n");

  my @date;

  foreach (0 .. $days){
    my $date_days_ago = `date --date="$_ days ago" +"%Y-%m-%d"`;

    debug("sub delete_logs_older_than_days: Adding $date_days_ago to \@date\n");

    push @date, $date_days_ago;
  }
  
  LOOP: foreach my $file (`find /var/log/opt 2>/dev/null`){
    next unless $file =~ /\d{4}-\d\d-\d\d/; 
    next unless $file =~ /ptr$|log$/; 

    chomp $file;

    debug("sub delete_logs_older_than_days: Found log file $file\n");
  
    foreach my $date (@date){
      chomp $date; 
      
       if ($file =~ /$date/) {
         debug("sub delete_logs_older_than_days: Found $date in \@date. Skipping $file\n");
         next LOOP;
       }
    }
  
    $files_deleted_counter++;

    if ($dry_run) {
      debug("Dry run in true. Will not delete file: $file\n");
    }
    else {
      debug("Dry run in false. Will delete file: $file\n");
      unlink $file; 
    }
  }
  
}
