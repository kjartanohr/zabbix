#!/usr/bin/perl5.32.0 
#bin
BEGIN {
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;
use Getopt::Long;

my $old_name = $0;
$0           = "perl snapshot VER 101";
$|++;
$SIG{CHLD}   = "IGNORE";

zabbix_check($ARGV[0]);

my $dir_tmp           = "/tmp/zabbix/snapshot";
our $file_debug       = "$dir_tmp/debug.log";
our $file_lock        = "$dir_tmp/creating_snapshot.lock";
our $file_failed      = "$dir_tmp/creating_snapshot_failed.lock";
our $file_run_hidden  = "$dir_tmp/run_hidden_scan";
our $debug            = 0;

my $create_snapshot        = "";
my $delete_oldest_snapshot = "";
my $show_snapshots         = "";
my $show_snapshot_count    = "";
my $search_string          = "";
my $search_not_string      = "";

GetOptions (
#  "length=i" => \$length,    # numeric
#  "file=s"   => \$data,      # string
  "create-snapshot"        => \$create_snapshot,
  "delete-oldest-snapshot" => \$delete_oldest_snapshot,
  "show-snapshots"         => \$show_snapshots,
  "show-snapshot-count"    => \$show_snapshot_count,
  "debug"                  => \$debug,
  "search=s"               => \$search_string,
  "search-not=s"           => \$search_not_string,

) or die("Error in command line arguments\n");

#help() unless $create_snapshot or $show_snapshots;

#Create $dir_tmp if it does not exist
create_dir($dir_tmp);

#Delete log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);


#get the output from clish show snapshots 
my $show_snapshots_out = `clish -c "show snapshots"`;

#Check the output from the command
if ($show_snapshots_out =~ /9999/) {
  print "Can't run clish get snapshots. Need a human here\n";
  exit;
}


#Run this every 30 days
delete_hidden_zabbix_snapshots();


#Check command line options 

if ($create_snapshot) {
  debug("Found the command option create-snapshot\n");
  start_create_snapshot();
}

elsif ($show_snapshot_count) {
  debug("Found the command option show-snapshot-count\n");

  #Get the snapshots count
  my $snapshot_count = snapshots_count($search_string,$search_not_string);

  print $snapshot_count;

}
elsif ($show_snapshots) {
  debug("Found the command option show-snapshots\n");

  #Get the snapshots
  my @snapshots = get_snapshots($search_string,$search_not_string);

  if ($snapshots[0]) {
    print join "\n", @snapshots;
  }
  else {
    print "No snapshots found\n";
  }

}
elsif ($delete_oldest_snapshot) {
  debug("Found the command option elete-oldest-snapshot\n");
  delete_old_snapshots();

}
else {
  debug("No option input found. running help()\n");
  help();
}



#End of the main script



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

sub get_snapshots {
  my $search         = shift;
  my $exclude        = shift;

  my $start_count    = 0;
  my @snapshots;

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

    chomp;
    push @snapshots, $_;
  }

  return @snapshots;
}

sub create_snapshot {
#  my $name = shift || die "Need a name for the snapshot\n";

  if (snapshot_today_exists()) {
    debug("No need to create a snapshot. It's already created\n");
    return;
  }

  #Get todays date and remove \n from the output
  my $date = `date +%Y_%m_%d`;
  chomp $date; 
  my $name = $date."_ZABBIX";

  system qq#clish -c "lock database override" &>/dev/null#;

  my $out = `clish -c "add snapshot $name"`;

  debug("sub create_snapshot clish -c add snapshot $date: $out");

  if ($out =~ /insufficient space in \/boot./) {
    print "Low disk space on /boot. Deleting oldest snapshot\n";
    debug("Low disk space on /boot. Deleting oldest snapshot\n");

    delete_oldest_snapshots();
  
  }
  elsif ($out =~ /9999/) {
    print "Create snapshot failed. Running fix. Need a human here: $out\n";
    fix_hang();
    exit;
  }

  return 1;
}

sub snapshot_today_exists {
  #Get todays date and remove \n from the output
  my $date = `date +%Y_%m_%d`;
  chomp $date; 
  my $name = $date."_ZABBIX";

  if (snapshots_count($name)) {
    return 1;
  }
  else {
    return 0;
  }
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

  unless (-f $file_failed){
    debug("Could not find $file_failed. Will create the file and return\n");
    touch($file_failed);
    return;
  }

  #Do not continue before the failed file is older than 10 hours
  unless ( (file_seconds_old($file_failed) /60/60) > 10){
    debug("The file $file_failed is not older than 10 hours. Will return\n");
    return;
  }

  run_cmd("umount /mnt/backup/ 2>&1");
  run_cmd("umount /lvsnap/ 2>&1");

  unlink $file_failed;
  #unlink $file_lock;
}

sub start_create_snapshot {

  #Check if there is a snapshot for today
  if (snapshot_today_exists()) {
    debug("No need to create a snapshot. It's already created\n");
    return;
  }

  #Check if create snapshot is running
  if ($show_snapshots_out =~ /Restore point now under creation/) {
  
    debug("Restore point is already under creation\n");
  
    if (-f $file_lock) {
      debug("Old lock file found $file_lock\n");
    
      my $file_lock_sec_old = file_seconds_old($file_lock); 
      my $file_lock_hour_old = int($file_lock_sec_old / 60 / 60);
  
      if ($file_lock_hour_old > 4) {
        fix_hang();
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
  #End of Check if create snapshot is running  


  #Check if there is an old lock file and delete it
  if (-f $file_lock) {
    debug("Deleting old $file_lock\n");
    unlink $file_lock;
  }
  
  
  #Check for 0 G free
  #if ($show_snapshots_out =~ /Amount of space available for restore points is 0.0G/) {
  #  print "There is not enough disk space on the disk for a snapshot\n";
  #  exit;
  #}
  
  
  #Check if there is disk space free for 1 snapshot
  my $disk_free = check_for_free_disk_space_for_snapshots(1);
  
  #If there is not enough free disk space
  if ($disk_free == 0) {
  
    debug("Free disk space is low\n");
  
    #Check if there is any old ZABBIX snapshots and delete if found
    if (snapshots_count("_ZABBIX")) {
      
      debug("Found a ZABBIX snapshot. Will try to delete it\n");

      my $snapshot_deleted = delete_oldest_snapshots();
      debug("Out of disk space. Found old zabbix snapshot. Will delete the oldest $snapshot_deleted\n");
    }
   
    
    debug("Will check again if there is free disk space to create a snapshot\n");
    if (check_for_free_disk_space_for_snapshots(1) == 1){
      
      debug("There is enough disk space to create a new snapshot. Creating now\n");
      
      #Create snapshot
      create_snapshot();
    }
    else {
    print "There is not enough disk space on the disk for a snapshot. Need a human here\n";
    return;
    }
  }

  debug("Free disk space for a new snapshot found, will create a snapshot now\n");

  #Create snapshot
  create_snapshot();
  
}

sub delete_hidden_zabbix_snapshots {
  my @snapshots_lvscan;
  my @snapshots_clish;


  touch($file_run_hidden) unless -f $file_run_hidden;
  
  if (file_hours_old($file_run_hidden) < 30) {
    debug("$file_run_hidden is less than 30 days old, will return\n");
    return;
  }
  

  debug("sub delete_hidden_zabbix_snapshots\n");

  #lvscan code

  my $cmd_lvscan = "lvscan";
  debug("sub delete_hidden_zabbix_snapshots: running the command $cmd_lvscan\n");

  foreach (`$cmd_lvscan`) {

    unless (/lv_\d{4}_\d\d_\d\d_ZABBIX/) {
      debug("sub delete_hidden_zabbix_snapshots: Skipping line. Does not match ZABBIX naming standard: $_\n");
      next;
    }

    my ($name_lvscan) = /lv_(\d{4}_\d\d_\d\d_ZABBIX)/;
    push @snapshots_lvscan, $name_lvscan;
  }
  #lvscan code end

  #get snapshot list from show snapshots
  @snapshots_clish = get_snapshots();


  foreach my $snapshot_lvscan (@snapshots_lvscan) {
    
    if (grep /$snapshot_lvscan/, @snapshots_clish){
      debug("Found $snapshot_lvscan in clish show snapshots output\n");
    }
    else {
      debug("Could not find $snapshot_lvscan in clish show snapshots output. Will delete $snapshot_lvscan\n");
      print "Could not find $snapshot_lvscan in clish show snapshots output. Will delete $snapshot_lvscan\n";

      my $cmd_lvremove = "lvremove -d -f /dev/vg_splat/lv_$snapshot_lvscan 2>&1";

      run_cmd($cmd_lvremove);
    }
  }
}

sub help {

  my $date = `date +%Y_%m_%d`;
  chomp $date; 
  my $snapshot_name = $date."_ZABBIX";

  print <<"EOF";
$old_name --debug                      
                                       Enables debug. Prints every command and step by step position in the script
                                       The debug information can be found in $file_debug even without enabling --debug

$old_name --create-snapshot            
                                       Create a new snapshot with todays date $snapshot_name
                                       This will run the  --delete-oldest-snapshot first if there is more than 4 ZABBIX snapshots  

$old_name --show-snapshots             
                                       List all the snapshots with the clish command "show snapshots"
                                       --search     ZABBIX will give return all the snapshots named INPUT. Case sensitive regex
                                       --search-not excludes all snapshots named INPUT

$old_name --show-snapshot-count        
                                       How many snapshots are there
                                       --search ZABBIX will return how many snapshots named ZABBIX. Case sensitive regex
                                       --search-not excludes all snapshots named INPUT

$old_name --delete-oldest-snapshot     
                                       Deletes the oldest _ZABBIX snapshot it can find

EOF
}
