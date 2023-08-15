#!/usr/bin/perl

BEGIN {
  if ($ARGV[0] eq "--zabbix-test-run"){
    print "ZABBIX TEST OK";
    exit;
  }
}

use warnings;
use strict;

my @filter = @ARGV;

my @files = (
  "/var/www/html/nextcloud/data/nextcloud.log",
);

my @search = (
  "*.log",
  "*_log",
);


foreach my $search (@search) {
  foreach my $file (`find / -mount -name "$search"`){
    chomp $file;
    push @files, "'$file'";
  }
}

my $files = join " ", @files;

my $cmd_tail =  qq#tail -v -n0 -F $files#;
print "$cmd_tail\n";

open my $fh_r, "-|", $cmd_tail or die "Can't run command $cmd_tail: $!";

LOG:
while (my $line = readline $fh_r) {
  chomp $line;

  my $continue;

  REGEX:
  foreach my $regex (@filter) {

    if ($regex =~ /^\+/) {
      $continue = 0 unless defined $continue;
      $regex =~ s/^.//;

      if ($line =~ /$regex/i) {
        $continue = 1;
        last REGEX;

      }
    }

    if ($regex =~ /^-/) {
      $continue = 1 unless defined $continue;
      $regex =~ s/^.//;

      if ($line =~ /$regex/) {
        $continue = 0;
        last REGEX;

      }
    }

  }

  if (not defined $continue or $continue) {

  }
  else {
    next LOG;
  }

  print "$line\n";
}
