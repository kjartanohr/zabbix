#!/usr/bin/perl5.32.0
#bin
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;

$0 = "perl search for objects VER 100";
$|++;
$SIG{CHLD} = "IGNORE";
my %db;

zabbix_check($ARGV[0]);

my $search         = shift @ARGV || die "Need somthing to search for";


#End of standard header

my @search = qw(
  objects.C
  objects_*.C
);

my @exclude = qw(
  tmp
);

my %files;

foreach my $search (@search) {
  my $cmd_find = "find / -name '$search'";
  print "$cmd_find\n";

  foreach my $file (`$cmd_find 2>/dev/null`) {

    foreach my $exclude (@exclude) {
      next if $file =~ /$exclude/i;
    }

    chomp $file;
    #print "$file\n";

    $files{$file} = "";
  }
}

foreach my $file (keys %files) {

  open my $fh_r, "<", $file or die "Can't read file $file: $!";

  while (my $line = readline $fh_r){

    if ($line =~ /$search/i) {
      chomp $line;

      next if defined $db{$line};
      $db{$line} = 1;

      print "File: '$file'. Line: '$.'. Data: '$line'\n";
    }
  }
}


