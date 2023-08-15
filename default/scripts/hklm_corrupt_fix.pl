#!/usr/bin/perl5.32.0
#bin
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;
use File::Copy qw(copy);

$0 = "perl HKLM corruption fix";
$|++;

zabbix_check($ARGV[0]);

my $debug   = 0;                     #This needs to be 0 when running in production 
my $dry_run = 0;                     #Do not make any changes
my %dir;


#Get all HKLM directories
my @dir = get_hklm_directory();
debug("Found HKLM DIR @dir");

DIR:
foreach my $dir (@dir) {
  print "HKLM directory found $dir\n" if $debug;

  unless (-f "$dir/HKLM_registry.data") {
    print "Missing HKLM_registry.data file! The MGMT/GW will crash after a reboot/cpstop;cpstart. Need a human here to help\n";
    exit;
  }

  my $size_hklm = get_file_size("$dir/HKLM_registry.data");
  print "Size of HKLM_registry.data: $size_hklm\n" if $debug;

  my $size_hklm_old = get_file_size("$dir/HKLM_registry.data.old");
  print "Size of HKLM_registry.data.old: $size_hklm\n" if $debug;


  #if the HKLM size is bigger than 0 byte
  if ($size_hklm > 0) {
    print "HKLM_registry.data is not empty (NOT corrupt). Will delete old corrupt files\n" if $debug;

    my $deleted_files = join "\n", delete_corrupt_files($dir);

    #print "Old corrupt files deleted $deleted_files\n" if $deleted_files;
    print "Old corrupt files deleted\n" if $deleted_files;

    #my $deleted_count = scalar split/\n/, $deleted_files;
    #print "Deleted old corrupt files: $deleted_count\n" if $deleted_files;
    next DIR;
  }

  print "HKLM_registry.data is empty (corrupt)\n" if $debug;

  unless (-f "$dir/HKLM_registry.data.old") {
    print "Missing HKLM_registry.data.old file. Need a human here to help";
    exit;
  }


  if ($size_hklm_old == 0) {
    print "Empty HKLM_registry.data.old file. Need a human here to help";
    exit;
  }

  if ($size_hklm_old > 0) {
    print "HKLM_registry.data.old is here. Will copy HKLM_registry.data.old to HKLM_registry.data\n" if $debug;
    
    print "$dir/HKLM_registry.data.old, $dir/HKLM_registry.data\n" if $debug;
    copy "$dir/HKLM_registry.data.old", "$dir/HKLM_registry.data" unless $dry_run;
    
    $size_hklm = get_file_size("$dir/HKLM_registry.data");
    print "New file size for HKLM_registry.data if $size_hklm\n" if $debug;
    
    if ($size_hklm == 0) {
      print "Could not fix the corruption. Need a human here to help";
      exit;
    }

    if ($size_hklm > 0) {
      print "HKLM_registry corruption fixed $dir. Need a human here to review the corruption\n";

      my $deleted_files = join "\n", delete_corrupt_files($dir);
      print "Old corrupt files deleted $deleted_files\n" if $deleted_files;
  
      next DIR; 
    }
  }
}

sub delete_corrupt_files {
  my $dir = shift || return;
  my @return;

  foreach my $file (`find $dir -name "*.corrupt.*" 2>/dev/null`){
    chomp $file;

    print "sub: delete_corrupt_files. Corrupt file found $file\n" if $debug;
    push @return, $file;
    
    unlink $file unless $dry_run;
  }

  return @return; 
}
