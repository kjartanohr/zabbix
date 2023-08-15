#!/usr/bin/perl5.32.0 
BEGIN {
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;

$0 = "perl snapshot VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

my $dir_tmp        = "/tmp/zabbix/snapshot/";
our $file_debug    = "$dir_tmp/debug.log";
our $file_lock     = "$dir_tmp/creating_snapshot.lock";
our $file_failed   = "$dir_tmp/creating_snapshot_failed.lock";
our $debug         = 0;

create_dir($dir_tmp);

exit;

#get the output from clish show snapshots 
my $show_snapshots_out = `clish -c "show snapshots"`;

#Check the output from the command
if ($show_snapshots_out =~ /9999/) {
  print "Can't run clish get snapshots. Need a human here\n";
  exit;
}

#Check if create snapshot is running
if ($show_snapshots_out =~ /Restore point now under creation/) {

  debug("Restore point now under creation\n");

  if (-f $file_lock) {
    debug("Old lock file found $file_lock\n");
  
    my $file_lock_sec_old = file_seconds_old($file_lock); 
    my $file_lock_hour_old = int($file_lock_sec_old / 60 / 60);

    if ($file_lock_hour_old > 4) {
      print "Snapshot creating has been running for $file_lock_hour_old hours. Need a human here\n";
      exit;
    }

    print "Snapshot create has been running for $file_lock_hour_old hours\n";
    exit;

  }
  else {
    debug("Creating lock file\n");
    touch($file_lock);
  }

  print "Snapshot create is running\n";
  exit;
}

#Check if there is an old lock file and delete it
if (-f $file_lock) {
  debug("Deleting $file_lock\n");
  unlink $file_lock;
}


#Check for 0 G free
#if ($show_snapshots_out =~ /Amount of space available for restore points is 0.0G/) {
#  print "There is not enough disk space on the disk for a snapshot\n";
#  exit;
#}


#Check if there is disk space free for 1 snapshot
my $disk_free = check_for_free_disk_space_for_snapshots(1);

#If there is not enough free disk space, print warning and exit
if ($disk_free == 0) {

  debug("Free disk space is low\n");

  #Check if there is any old ZABBIX snapshots and delete if found
  if (snapshots_count("_ZABBIX")) {
    my $snapshot_deleted = delete_oldest_snapshots();
    debug("Out of disk space. Found old zabbix snapshot. Will delete the oldest $snapshot_deleted\n");
    exit;
  }
 
  print "There is not enough disk space on the disk for a snapshot. Need a human here\n";
  exit;
}

#Get the snapshots count
my $snapshot_count = snapshots_count();

if ($snapshot_count == 0) {
  print "No snapshots found. Need a human here\n";
}

#Get the snapshots count for snapshots NOT named ZABBIX
my $snapshot_count_not_zabbix = snapshots_count("","ZABBIX");

if ($snapshot_count_not_zabbix > 4) {
  print "Many none zabbix snapshots found. Please remove some\n";
}


debug("Deleting snapshots\n");
delete_old_snapshots();

debug("Creating snapshots\n");


#Create snapshot
create_snapshot();




sub check_for_free_disk_space_for_snapshots {
  my $snapshot_count = shift || 1;
 
  my ($need) = $show_snapshots_out =~ /will need (\d{1,})/;
  my ($have) = $show_snapshots_out =~ /restore points is (\d{1,})/;

  debug("sub check_for_free_disk_space_for_snapshots: Need $need, Have $have\n");

  if ( ($need * $snapshot_count) >= $have) {
    return 0;
  }

  return 1;
}

sub snapshots_count {
  my $search         = shift;
  my $exclude        = shift;

  my $start_count    = 0;
  my $snapshot_count = 0;

  OUT_LOOP: foreach (split /\n/, $show_snapshots_out) {
    
    #Jump out of loop if a empty line if found
    last OUT_LOOP if /^$/;

    #Start the snapshot count if ---- is found
    if (/---------/) {
      $start_count = 1;
      next OUT_LOOP;
    }

    #Next line if loop if not $start_count is true
    next OUT_LOOP unless $start_count;

    #If there is a regex that have to match, check it
    if ($search) {
      next OUT_LOOP unless /$search/;
    }

    #If there is a regex for exclude
    if ($exclude) {
      next OUT_LOOP if /$exclude/;
    }

    $snapshot_count++;
  }

  return $snapshot_count;
}

sub create_snapshot {
#  my $name = shift || die "Need a name for the snapshot\n";

  #Get todays date and remove \n from the output
  my $date = `date +%Y_%m_%d`;
  chomp $date; 

  my $name = $date."_ZABBIX";

  if (snapshots_count($name)) {
    print "No need to create a snapshot. It's already created\n" if $debug;
    exit;
  }

  system qq#clish -c "lock database override" &>/dev/null#;

  my $out = `clish -c "add snapshot $name"`;

  debug("sub create_snapshot clish -c add snapshot $date: $out");

  if ($out =~ /9999/) {
    print "Create snapshot failed. Running fix. Need a human here: $out\n";
    #fix_hang();
    exit;
  }

  return 1;
}

sub delete_old_snapshots {
  my $keep_old_count = shift || 4;

  system qq#clish -c "lock database override" &>/dev/null#;

  my @snapshots;
  foreach (split /\n/, $show_snapshots_out){
    next unless /_ZABBIX/;
    chomp;
 
    push @snapshots, $_;
  } 

  my $count = 0;
  foreach (reverse sort @snapshots){
    $count++;

    if ($count >= $keep_old_count ){

      my $delete_snapshot_out = `clish -c "delete snapshot $_" 2>&1`;
      debug("sub delete_old_snapshots: clish -c delete snapshot $_");

      if ($delete_snapshot_out =~ /9999/) {
        print "$delete_snapshot_out Need a human here\n";
        exit;
      }
    }
  } 
}

sub delete_oldest_snapshots {

  system qq#clish -c "lock database override" &>/dev/null#;

  my @snapshots;
  foreach (split /\n/, $show_snapshots_out){
    next unless /_ZABBIX/;
    chomp;
 
    push @snapshots, $_;
  } 

   if (defined $snapshots[0]) {
     my $out = `clish -c "delete snapshot $snapshots[0]" &>/dev/null 2>&1`;
     debug($out);
     return $snapshots[0];
   }
}

sub fix_hang {
  debug("sub fix_hang: started\n");

  #Check for hung snapshot
  if (-f $file_lock or $file_failed) {
    debug("sub fix_hang: found $file_lock\n");
    my $file_lock_sec_old = file_seconds_old($file_lock); 
    my $file_lock_hour_old = int($file_lock_sec_old / 60 / 60);

    my $file_failed_sec_old = file_seconds_old($file_failed); 
    my $file_failed_hour_old = int($file_failed_sec_old / 60 / 60);

    if ($file_lock_hour_old > 10 and $file_failed_hour_old > 10) {
      debug("sub fix_hang: $file_lock and $file_failed_hour_old is older than 10 hours. Will run fix\n");
      system "umount /mnt/backup/";
      system "umount /lvsnap/";

      unlink $file_failed;
    }
  }
}
