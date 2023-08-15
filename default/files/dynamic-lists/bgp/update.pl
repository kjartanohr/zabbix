#!/usr/bin/perl
use warnings;
use strict;

my $cmd_wget_bin = "wget";
my $cmd_wget_opt = "";
my $dir = "/home/kfo/repo/files/dynamic-lists/bgp";

my $urls = {
  
  'https://bgp.potaroo.net/as2.0/bgptable.txt' => {
    'filename' => 'bgptable-ipv4.txt',
  },
  'http://bgp.potaroo.net/v6/as2.0/bgptable.txt' => {
    'filename' => 'bgptable-ipv6.txt',
  },
  'https://bgp.potaroo.net/as2.0/bgp-active.txt' => {
    'filename' => 'bgp-active.txt',
  },
  'https://bgp.potaroo.net/as2.0/bgp-all.txt' => {
    'filename' => 'bgp-all.txt',
  },
  'https://bgp.potaroo.net/as2.0/bgp-ribfib.txt' => {
    'filename' => 'bgp-ribfib.txt',
  },
  'https://bgp.potaroo.net/as2.0/bgp-valid.txt' => {
    'filename' => 'bgp-valid.txt',
  },
  'https://bgp.potaroo.net/as2.0/bgp-suppressed.txt' => {
    'filename' => 'bgp-suppressed.txt',
  },
  'https://bgp.potaroo.net/as2.0/bgp-damped.txt' => {
    'filename' => 'bgp-damped.txt',
  },
  'https://bgp.potaroo.net/as2.0/bgp-history.txt' => {
    'filename' => 'bgp-history.txt',
  },
  'https://bgp.potaroo.net/as2.0/bgp-total-space.txt' => {
    'filename' => 'bgp-total-space.txt',
  },
  'https://bgp.potaroo.net/as2.0/bgp-spec.txt' => {
    'filename' => 'bgp-spec.txt',
  },
  'https://bgp.potaroo.net/as2.0/bgp-prefix-root-vector.txt' => {
    'filename' => 'bgp-prefix-root-vector.txt',
  },
  'https://bgp.potaroo.net/as2.0/bgp-as-count.txt' => {
    'filename' => 'bgp-as-count.txt',
  },
  'https://bgp.potaroo.net/as2.0/bgp-aspaths.txt' => {
    'filename' => 'bgp-aspaths.txt',
  },
  'https://bgp.potaroo.net/as2.0/bgp-prefix-vector.txt' => {
    'filename' => 'bgp-prefix-vector.txt',
  },
  'https://bgp.potaroo.net/as2.0/bgp-upd-entries.txt' => {
    'filename' => 'bgp-upd-entries.txt',
  },
  'https://bgp.potaroo.net/as2.0/bgp-upd-entries-ann.txt' => {
    'filename' => 'bgp-upd-entries-ann.txt',
  },
  'https://bgp.potaroo.net/as2.0/bgp-upd-entries-wdl.txt' => {
    'filename' => 'bgp-upd-entries-wdl.txt',
  },
  'https://bgp.potaroo.net/as2.0/bgp-upd-entries-chg.txt' => {
    'filename' => 'bgp-upd-entries-chg.txt',
  },
  'https://bgp.potaroo.net/as2.0/bgp-upd-addrs.txt' => {
    'filename' => 'bgp-upd-addrs.txt',
  },
  'https://bgp.potaroo.net/as2.0/bgp-pth-total.txt' => {
    'filename' => 'bgp-pth-total.txt',
  },
  'https://bgp.potaroo.net/as2.0/bgp-asorgprefix-vector.txt' => {
    'filename' => 'bgp-asorgprefix-vector.txt',
  },
  'https://bgp.potaroo.net/as2.0/bgp-as-adj_count.txt' => {
    'filename' => 'bgp-as-adj_count.txt',
  },
  'https://bgp.potaroo.net/as2.0/asnames.txt' => {
    'filename' => 'asnames.txt',
  },
  'https://bgp.potaroo.net/as2.0/bgp-multi-org-prefix.txt' => {
    'filename' => 'bgp-multi-org-prefix.txt',
  },
  'https://bgp.potaroo.net/as2.0/bgp-table-asppath.txt' => {
    'filename' => 'bgp-table-asppath.txt',
  },
  'https://bgp.potaroo.net/as2.0/report.txt' => {
    'filename' => 'report.txt',
  },
  'https://bgp.potaroo.net/ipv4-stats/allocated-afrinic.html' => {
    'filename' => 'allocated-afrinic.html',
  },
  'https://bgp.potaroo.net/iso3166/v6.csv' => {
    'filename' => 'iso3166-v6.csv',
  },
  'https://bgp.potaroo.net/iso3166/v6.csv' => {
    'filename' => 'iso3166-v6.csv',
  },
  'https://bgp.potaroo.net/iso3166/as.csv' => {
    'filename' => 'iso3166-as.csv',
  },
  'https://bgp.potaroo.net/ipv4-stats/prefixes_iana_pool.txt' => {
    'filename' => 'prefixes_iana_pool.txt',
  },
  'https://bgp.potaroo.net/ipv4-stats/prefixes_rir_pool.txt' => {
    'filename' => 'prefixes_rir_pool.txt',
  },
  'https://bgp.potaroo.net/ipv4-stats/prefixes_unadv_pool.txt' => {
    'filename' => 'prefixes_unadv_pool.txt',
  },
  'https://bgp.potaroo.net/ipv4-stats/prefixes_adv_pool.txt' => {
    'filename' => 'prefixes_adv_pool.txt',
  },
  'https://bgp.potaroo.net/ipv4-stats/rir_pool_prefixes.txt' => {
    'filename' => 'rir_pool_prefixes.txt',
  },
  'https://bgp.potaroo.net/ipv4-stats/slash8.txt' => {
    'filename' => 'ipv4-stats-slash8.txt',
  },
  'https://bgp.potaroo.net/ipv4-stats/age_distribution.txt' => {
    'filename' => 'ipv4-stats-age_distribution.txt',
  },
  'https://bgp.potaroo.net/iso3166/v4cc.html' => {
    'filename' => 'iso3166-v4cc.html',
  },
  'https://bgp.potaroo.net/iso3166/v6dcc.html' => {
    'filename' => 'iso3166-v6dcc.html',
  },
  'https://www.cidr-report.org/v6/as2.0/aggr.html' => {
    'filename' => 'v6-as2.0-aggr.html',
  },
  'https://www.cidr-report.org/v6/as2.0/' => {
    'filename' => 'v6-as2.0.html',
  },
  'https://www.cidr-report.org/v6/as2.0/reserved-ases.html' => {
    'filename' => 'v6-as2.0-reserved-ases.html',
  },
  'https://www.cidr-report.org/v6/as2.0/bogus-as-advertisements.html' => {
    'filename' => 'v6-as2.0-bogus-as-advertisements.html',
  },
  'https://www.iana.org/assignments/as-numbers/as-numbers.txt' => {
    'filename' => 'iana-as-numbers-as-numbers.txt',
  },
  'https://www.iana.org/assignments/as-numbers/as-numbers-1.csv' => {
    'filename' => 'iana-as-numbers-as-numbers-1.csv',
  },
  'https://bgp.potaroo.net/v6/as2.0/bgp-total-space.txt' => {
    'filename' => 'v6-bgp-total-space.txt',
  },
  'https://bgp.potaroo.net/v6/as2.0/bgp-spec.txt' => {
    'filename' => 'bgp.potaroo-v6-bgp-spec.txt',
  },
  'https://bgp.potaroo.net/v6/as2.0/bgp-as-count.txt' => {
    'filename' => 'potaroo-v6-bgp-as-count.txt',
  },
  'https://bgp.potaroo.net/v6/as2.0/bgp-aspaths.txt' => {
    'filename' => 'potaroo-v6-bgp-aspaths.txt',
  },
  '' => {
    'filename' => '',
  },
};

URL:
foreach my $url (keys %{$urls}){

  next unless defined $url;
  next unless $url;

  my $filename = $$urls{$url}{'filename'};

  my $cmd_wget = qq!cd $dir ; $cmd_wget_bin $cmd_wget_opt --output-document="$filename" $url!;
  print "$cmd_wget\n";
  system $cmd_wget;

  my $mtime = (stat($filename))[9];
  my $filename_timestamp = "$filename.timestamp";

  if (-f $filename_timestamp){
    open my $fh_r_timestamp, "<", $filename_timestamp or die "Can't read $filename_timestamp: $!";
    my $timestamp_old = readline $fh_r_timestamp;
    close $fh_r_timestamp;

    if ($mtime eq $timestamp_old){
      print "if (\$mtime eq \$timestamp_old)\n is true. next URL\n";
      next URL;
    }
  }

  open my $fh_timestamp, ">", $filename_timestamp or die "Can't write to $filename_timestamp: $!";
  print $fh_timestamp $mtime;
  close $fh_timestamp;
}

