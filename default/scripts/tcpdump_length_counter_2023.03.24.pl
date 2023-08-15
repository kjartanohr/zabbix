#!/usr/bin/perl5.32.0
#bin
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}


use warnings;
use strict;

$0 = "perl tcpdump counter VER 100";
$|++;
$SIG{CHLD} = "IGNORE";
$SIG{INT} = \&ctrl_c;

zabbix_check($ARGV[0]);

my  $interface   = shift || die "need a interface: $0 eth0";
my  $cmd_tcpdump = "tcpdump -nn -n -i $interface";
my $print_stats = 1; #Sec
my $print_stats_lines = 10;
my $print_stats_time = time;
my %db;
my %db_length;
my %db_port_lines;
my %db_port_length;


open my $ch, "-|", $cmd_tcpdump or die "Can't open $cmd_tcpdump: $!";

while (<$ch>) {
  chomp;

  #12:18:35.316699 IP 193.227.205.182 > 92.220.216.51:
  my ($ip_src, $ip_dst) = /^.*IP (\d{1,}\.\d{1,}\.\d{1,}\.\d{1,}).*> (\d{1,}\.\d{1,}\.\d{1,}\.\d{1,})/;

  my ($port_src, $port_dst) = /^.*IP \d{1,}\.\d{1,}\.\d{1,}\.\d{1,}\.(\d{1,}) > \d{1,}\.\d{1,}\.\d{1,}\.\d{1,}\.(\d{1,})/;

  next unless $ip_src;
  next unless $ip_dst;

  $port_src = "ICMP" if /ICMP echo/;
  $port_dst = "ICMP" if /ICMP echo/;

  $port_src = "ESP" if /ESP/;
  $port_dst = "ESP" if /ESP/;

  ($port_src) = /: (.*)/ unless $port_src;
  ($port_dst) = /: (.*)/ unless $port_src;

  print "unknown port $_" unless $port_src;

  $port_dst = "unknown port" unless $port_dst;
  $port_src = "unknown port" unless $port_src;

  my ($length) = /length (\d{1,})/;

  $db{$ip_src} +=1;
  $db{$ip_dst} +=1;

  $db_port_lines{$port_dst} +=1;
  $db_port_lines{$port_src} +=1;


  if ($length) {
    $db_length{$ip_src} += $length;
    $db_length{$ip_dst} += $length;

    $db_port_length{$port_dst} += $length;
    $db_port_length{$port_src} += $length;
  }

  if ( (time - $print_stats_time) > $print_stats) {
    print_stats();
    $print_stats_time = time;
  }
}


sub ctrl_c {
  print "CTRL+C\n";
  sleep 1;
  print_stats();
  exit;
}

sub print_stats {
  system "clear";
  print "CMD: $cmd_tcpdump\n\n";
  print "Lines\n";
  my $count_con = 0;
  foreach my $key (reverse sort { $db{$a} <=> $db{$b} } keys %db) {
    my $value = $db{$key};
    while($value =~ s/(\d+)(\d\d\d)/$1\,$2/){};
    last if $count_con++ == $print_stats_lines;
    printf "%-20s%20s",$key,$value;
    print "\n";
  }

  print "\n\nData\n\n";
  my $count_length = 0;
  foreach my $key (reverse sort { $db_length{$a} <=> $db_length{$b} } keys %db_length) {
    my $value = $db_length{$key};
    last if $count_length++ == $print_stats_lines;
    my $value_hr = formatSize($value);
    printf "%-20s%20s",$key,$value_hr;
    print "\n";
  }

  print "\n\nPort lines\n\n";
  my $count_port_lines = 0;
  foreach my $key (reverse sort { $db_port_lines{$a} <=> $db_port_lines{$b} } keys %db_port_lines) {
    my $value = $db_port_lines{$key};
    last if $count_port_lines++ == $print_stats_lines;
    while($value =~ s/(\d+)(\d\d\d)/$1\,$2/){};
    printf "%-20s%20s",$key,$value;
    print "\n";
  }

  print "\n\nPort data\n\n";
  my $count_port_length = 0;
  foreach my $key (reverse sort { $db_port_length{$a} <=> $db_port_length{$b} } keys %db_port_length) {
    my $value = $db_port_length{$key};
    last if $count_port_length++ == $print_stats_lines;
    my $value_hr = formatSize($value);
    printf "%-20s%20s",$key,$value_hr;
    print "\n";
  }
}

sub formatSize {
    my $size = shift;
    my $exp = 0;
    my $units;
    $units = [qw(B KB MB GB TB PB)];
    for (@$units) {
        last if $size < 1024;
        $size /= 1024;
        $exp++;
    }
    return wantarray ? ($size, $units->[$exp]) : sprintf("%.2f %s", $size, $units->[$exp]);
}


