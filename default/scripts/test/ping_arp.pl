#!/bin/perl
BEGIN{push @INC,"/usr/share/zabbix/bin/perl-5.10.1/lib"}

use warnings;
use strict;


#Zabbix test that will have to print out zabbix test ok. If not, the script will not download
if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

my $debug  = 0;
my $fork   = 0; #Fork out arping, makes this way faster
$fork = 0 if $debug;

my $vsid   = $ARGV[0] || 0;
my $dir    = "/tmp/zabbix/ping_arp/$vsid";
$0         = "perl arping $vsid main";
my %mac_scanned;

#Create the needed directories
create_directory();

#Running ip neighbour and running ARPing on all the IP-addresses
#Create files in the new directory
get_new_mac();

#Get new MAC
#Diff files in new and cur
foreach my $new (what_is_new_mac()) {
  next unless $new;
  print "New $new\n";
}

#ARPing the MAC addresses in the cur directory. To check if they are still answering
foreach my $lost (ping_cur_mac()) {
  print "Lost $lost\n";
}

#Move the newly scanned from new to cur
move_new_arp_to_cur_arp();


sub is_fork_running {
  my $found = 0;

  foreach (`ps xau`) {
    next unless /perl arping /;
    next if / main/;

    return 1;
  }
}

sub debug {
  print "DEBUG: $_[0]\n" if $debug;
}

sub save_state {
  my $ip    = shift;
  my $mac   = shift;
  my $int   = shift;
  my $file  = "$dir/new/$mac";

  open my $fh_w,">",$file or die "Can't write to $file: $!\n";
  print $fh_w "$int $mac $ip";
  close $fh_w;
}

sub what_is_new_mac {
  my @return;

  opendir my $dh_r, "$dir/new" or die "Can't open $dir/new: $!\n";
  my @dir_new = readdir $dh_r;
  close $dh_r;

  foreach my $new_mac (@dir_new) {
    if (-f "$dir/cur/$new_mac") {
      rename "$dir/new/$new_mac","$dir/cur/$new_mac";
    }
    else {
      if (-f "$dir/old/$new_mac") {
        print "MAC found in old. Not new $new_mac\n" if $debug;
      }
      else {
        print "MAC found not found in cur og old. New $new_mac\n" if $debug;
        my $text = readfile("$dir/new/$new_mac");
        push @return, $text;
      }
    }
  }

  #system "mv $dir/cur/* $dir/old/ &>/dev/null";

  return @return;
}

sub move_new_arp_to_cur_arp {
  system "mv $dir/new/* $dir/cur/ &>/dev/null";
}

sub readfile {
  my $filename = shift;

  open my $fh_r, "<", $filename or return "$filename not found";
  my $text = join "", <$fh_r>;
  close $fh_r;

  return $text;
}

sub ping_cur_mac {
  my @return;

  opendir my $dh_r, "$dir/cur" or die "Can't open $dir/cur: $!\n";
  my @cur = readdir $dh_r;
  close $dh_r;

  foreach my $file (@cur) {
    next if $file =~ /^\./;

    #fork a child and exit the parent
    #Don't fork if $fork is false
    if ($fork){
      fork && next;
    }

    #Eveything after here is the child

    #bond1.103 4e:74:50:07:13:7f 10.0.3.29
    my ($int, $mac, $ip) = split/ /, readfile("$dir/cur/$file");
    print "Read from $file: INT $int, MAC, $mac, IP $ip\n" if $debug;

    $0 = "perl arping $vsid $int $ip $mac";

    if (arping($int,$mac,$ip)) {
      print "Current MAC $int, $mac, $ip is answering\n" if $debug;
      $mac_scanned{$mac} = 1;
    }
    else {
      print "Current MAC $int, $mac, $ip is NOT answering\n" if $debug;
      rename "$dir/cur/$file","$dir/old/$file";
      $mac_scanned{$mac} = 2;

    }
    exit if $fork; #Exit fork
  }


  if ($fork){
    print "Starting waith for forks to end\n" if $debug;
    #Wait for the arping to run
    sleep 1;

    while (is_fork_running()) {
      sleep 1;
    }
  }

  opendir $dh_r, "$dir/cur" or die "Can't open $dir/cur: $!\n";
  my @cur_new = readdir $dh_r;
  close $dh_r;

  foreach my $cur (@cur) {
    if (grep /$cur/, @cur_new) {
      print "Mac address is still in cur directory $cur\n" if $debug;
    }
    else {
      print "Mac address is removed from cur directory $cur\n" if $debug;
      push @return, readfile("$dir/old/$cur");
    }
  }
  return @return;
}

sub arping {
  my $int = shift;
  my $mac = shift;
  my $ip  = shift;

  my $cmd = "arping -f -w 3 -c 3 -I $int $ip";
  print $cmd if $debug;

  my $out = `$cmd`;
  print $out if $debug;

  my ($found)     = $out =~ /reply from /;
  unless ($found) {
    print "MAC not found, return $int $mac $ip\n" if $debug;
    return
  }

  my ($mac_found) = $out =~ /$ip.*$mac/i;

  print "MAC found, return 1  $int $mac $ip\n" if $debug;

  return 1 if $mac_found;
}

sub get_new_mac {
  NEW: foreach (`source /etc/profile.d/vsenv.sh; vsenv $vsid &>/dev/null ; ip neigh`){
    next unless /lladdr/;

    #Split output in to lines
    my ($ip,$dev,$int,$lladdr,$mac) = split/\s{1,}/;

    print "IP $ip, int $int, mac $mac\n" if $debug;

    next unless $ip && $int && $mac;

    if ($mac_scanned{$mac} && $mac_scanned{$mac} == 1){
      print "MAC already scanned. Writing new file and skipping the rest $mac\n" if $debug;
      save_state($ip,$mac,$int);
      next;

    }

    #fork a child and exit the parent
    #fork if $fork is true
    if ($fork) {
      fork && next;
    }

    #Eveything after here is the child
    $0 = "perl arping $vsid $ip $mac";

    my $found = arping($int,$mac,$ip);

    #Exit if arping is not ok
    if ($fork) {
      exit unless $found;
    }

    print "$mac found\n" if $debug;

    save_state($ip,$mac,$int);

    if ($fork) {
      exit unless $found;
    }
  }

  if ($fork) {
    #Wait for the arping to run
    sleep 1;

    while (is_fork_running()) {
      sleep 1;
    }
  }

}

sub create_directory {

  system "mkdir -p $dir/new" unless -d "$dir/new";
  system "mkdir -p $dir/old" unless -d "$dir/old";
  system "mkdir -p $dir/cur" unless -d "$dir/cur";
}
