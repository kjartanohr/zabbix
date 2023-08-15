#!/bin/perl
#bin
BEGIN{push @INC,"/usr/share/zabbix/bin/perl-5.10.1/lib"}

use warnings;
use strict;

$0 = "perl tcpdump packet counter";
$|++;
$SIG{CHLD} = "IGNORE";
$ARGV[0] = "" unless $ARGV[0];

if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

my %ip;
my $time = time;


open my $fh_r,"-|", "tcpdump -n -p -i any";
open my $fh_w,"|-", "gzip -9 >tcpdump_packet_counter_output-$$.gz";

while (my $line = <$fh_r>) {
  print $fh_w $line;
  chomp $line;

  my ($ip) = $line  =~ /IP (\d{1,}\.\d{1,}\.\d{1,}\.\d{1,})/;

  next unless $ip;
  #print "IP \"$ip\"\n";

  $ip{$ip} += 1;

  if ( (time - $time) > 2) {
    $time = time;
    system "clear";

    my $count = 0;
    foreach my $key (sort { $ip{$b} <=> $ip{$a} } keys %ip) {
      my $hits = $ip{$key};

      while($hits =~ s/(\d+)(\d\d\d)/$1\,$2/){};
      my $hits_length = length $hits;
      $hits_length +=5;

      printf "%20s %s\n", $hits, $key;
      last if $count++ > 20;
    }
    my $file_tcpdump_size = `du -hs tcpdump_packet_counter_output-$$.gz`;
    print "You can find the tcpdump raw data in the file tcpdump_packet_counter_output-$$.gz\n";
    print "File size of log is $file_tcpdump_size";

  }
}
