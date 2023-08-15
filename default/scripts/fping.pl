#!/bin/perl
BEGIN{push @INC,"/usr/share/zabbix/bin/perl-5.10.1/lib"}

use warnings;
use strict;
use POSIX ":sys_wait_h";

$0 = "perl fping";
$|++;
$SIG{CHLD} = "IGNORE";
my %vs;
$ARGV[0] = "" unless $ARGV[0];
my $restart = 0;


my $dir_tmp         = "/tmp/zabbix/ping/";
my $file_list       = "/tmp/zabbix/ping/list.txt";
my $file_log        = "/tmp/zabbix/ping/ping.log";
my $file_exclude    = "/tmp/zabbix/ping/exclude.txt";
my $file_timestamp  = "/tmp/zabbix/ping/timestamp.log";
my $sleep           = 10;
my $time_restart    = 600;
my $debug           = 0;

my %temp            = ();

unless (-d $dir_tmp){system "mkdir -p $dir_tmp";}
unless (-f $file_list){create_list();}
unless (-f $file_exclude){system "touch $file_exclude"}
unless (-f $file_timestamp){create_timestamp();}


open my $fh_log_w, ">>","$file_log" or die "Can't open $file_log: $!";
open my $fh_exclude_r, "<","$file_exclude" or die "Can't open $file_exclude: $!";
my @exclude = join "\n", <$fh_exclude_r>;
close $fh_exclude_r;


if ($ARGV[0] eq "--restart"){
  kill_fping();
  $restart = 1;
}
elsif ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

#Print errors to zabbix agent from file
get_errors();

#Restart fping after $time_restart
if ($restart || ((time-get_timestamp())> $time_restart)){
  print "kill fping\n" if $debug;
  kill_fping();
}

if (check_if_running()){
  exit;
}

create_timestamp();
get_vs_name();

#foreach VS
foreach my $dir (keys %vs) {

  if (grep /$dir/,@exclude){next}

  unless ($debug) {
    my $pid = fork;
    next unless $pid == 0;
  }

  while (1) {
    print "Child $dir\n" if $debug;

    open my $fh_ping_r, "-|", "source /etc/profile.d/vsenv.sh; vsenv $dir &>/dev/null ; fping -f $file_list -A -e  -u  -c 30 -p 100 2>&1" or die "Can't run command: $!\n";

    OUTPUT:
    while (my $line = <$fh_ping_r>){
      next unless $line =~ /%/;

      my ($ip) = $line =~ /^(.*?) /;

      if ($line =~ /0%, /) {

        #Check if IP is dead
        if (defined $temp{'dead'}{$ip}) {
          print "\$temp{'dead'}{$ip} is defined. This IP has 0% packet loss. Delete \$temp{'dead'}{$ip}\n" if $debug;
          delete $temp{'dead'}{$ip};
        }

        #Check if IP is alive
        if (defined $temp{'alive'}{$ip}) {
          print "\$temp{'alive'}{$ip} is defined. This IP has 0% packet loss. No need to print. next\n" if $debug > 1;
          next OUTPUT;
        }
        $temp{'alive'}{$ip} = 1;

        print "0% percent packet loss: $line\n" if $debug;


      }
      else {

        if (defined $temp{'dead'}{$ip}) {
          print "\$temp{'dead'}{$ip} is defined. This IP has packet loss. No need to warn about packet loss. next\n" if $debug;
          next OUTPUT;
        }
        $temp{'dead'}{$ip} = 1;

        if (defined $temp{'alive'}{$ip}) {
          print "\$temp{'alive'}{$ip} is defined. This IP has packet loss. delete \$temp{'alive'}{$ip}\n" if $debug;
          delete $temp{'alive'}{$ip};
        }

        print "Packet loss: $line\n" if $debug;
      }

      #my $time = get_date_time();

      print $fh_log_w "$vs{$dir} $ip\n";
      print "$vs{$dir} $line" if $debug;
    }
    close $fh_ping_r;
    sleep $sleep;
  }

  exit;
}
exit 0;

sub create_list {
  open my $fh_w, ">", $file_list or die "Can't open $file_list: $!\n";
  print $fh_w <<EOF;
8.8.8.8
1.1.1.1
vg.no
EOF
}

sub create_timestamp {
  open my $fh_timestamp_w, ">","$file_timestamp" or die "Can't open $file_timestamp: $!";
  print $fh_timestamp_w time();
  close $fh_timestamp_w;
}

sub get_errors {
  open my $fh_log_r, "<","$file_log" or die "Can't open $file_log: $!";
  foreach (<$fh_log_r>){
    chomp;
    print "$_ ";
  }
  close $fh_log_r;

  open my $fh_log_w, ">","$file_log" or die "Can't open $file_log: $!";
  close $fh_log_w;

}

sub get_timestamp {
  open my $fh_timestamp_r, "<","$file_timestamp" or die "Can't open $file_timestamp: $!";
  my $timestamp =  <$fh_timestamp_r>;
  close $fh_timestamp_r;
  chomp $timestamp;
  return $timestamp;

}

sub kill_fping {
  foreach (`ps xau`){
    next unless /perl fping/;
    my @s = split/\s{1,}/;
    next if $s[1] == $$;
    system "kill $s[1]";
  }
}

sub get_vs_name {
  foreach (`vsx stat -v 2>&1`){
    if (/VSX is not/){
      chomp(my $hostname = `hostname`);
      $vs{0} = $hostname;
      return;
    }
    s/^\s{1,}//;
    next unless /^\d/;
    my @s = split/\s{1}/;
    next unless $s[2] eq "S";

    $vs{$s[0]} = $s[3];
  }
}


sub check_if_running {
   my $count = 0;

   foreach (`ps xau`){
    next unless /perl fping/;
    my @s = split/\s{1,}/;
    next if $s[1] == $$;

    $count++;

  }

  return 1 if $count;
}

