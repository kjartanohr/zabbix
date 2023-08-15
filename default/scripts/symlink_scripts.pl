#!/usr/bin/perl5.32.0
#bin
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;

$0 = "perl symlink scripts VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

zabbix_check($ARGV[0]);

my $dir_script = "/usr/share/zabbix/repo/scripts/auto";
my $dir_bin    = "/usr/bin";
my $debug      = 0;

$debug = 1 if grep/debug/, @ARGV;

#Cleanup
#foreach (<$dir_bin/kfo_*>) {
#  next unless -l;
#  unlink $_;
#}


foreach (<$dir_script/*>) {
  next unless /\.pl$|\.sh$/;
  my ($filename) = /.*\/(.*)/;

  my $bin = 0;

  open my $fh_r,"<", $_ or die "Can't open $_: $!\n";
  $bin = 1 if grep /^#bin$/, <$fh_r>;
  close $fh_r;

  print "bin: $bin. $filename\n" if $debug;
  next unless $bin;
  #print "$_\n";

  if (not -e "$dir_bin/$filename"){
    print "$_ --> $dir_bin/$filename\n";
    symlink $_,"$dir_bin/$filename" or die "Can't symlink $_,$dir_bin/$filename: $!\n";
  }
  if (not -e "$dir_bin/kfo_$filename"){
    print "$_ --> $dir_bin/kfo_$filename\n";
    symlink $_,"$dir_bin/kfo_$filename" or die "Can't symlink $_,$dir_bin/kfo_$filename: $!\n";
  }


}

