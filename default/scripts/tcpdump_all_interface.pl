#!/usr/bin/perl5.32.0
#bin

$0 = "perl tcpdump all interface VER 100";
$|++;
$SIG{INT} = \&kill_tcpdump;

if (defined $ARGV[0] and $ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}


my $search = shift @ARGV;

unless ($search) {
  print "\nWhat do you want to search for in the tcpdump output: ";
  $search = <>;
  chomp $search;
}

foreach my $int (get_all_interafces()) {
#foreach my $int ("bond1.102") {

  fork && next;

  my $pid = open my $fh_r,"-|", "tcpdump -n -i $int 2>&1";

  while (my $line = <$fh_r>) {
    next unless $line =~ /^\d\d/;

    next unless $line =~ /$search/;

    print "$int $line";

    last;
  }
  kill(9, $pid);

  exit;
}


sleep 2;
print "\n\ntcpdump is running in the background for every interface. Press CTRL+C to kill them all or wait for them to end\n";

sleep 60*60;
kill_tcpdump();


sub get_all_interafces {
  my @return;

  foreach (`/sbin/ifconfig`) {
    next if /^\s/;
    my @split = split/\s{1,}/;

    push @return,$split[0]
  }
  return @return;

}

sub kill_tcpdump {
  system "killall -9 tcpdump";
}
