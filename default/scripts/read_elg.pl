#!/bin/perl

$0 = "read elg";
$time = time;
$debug  = 0;

if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}


$filename = "$ARGV[0]";

exit unless -f $filename;

$vsid = $ARGV[1] || 0;
$FWDIR = `source /etc/profile.d/vsenv.sh; vsenv $vsid &>/dev/null ; echo \$FWDIR`;
chomp $FWDIR;
$filename =~ s/FWDIR/$FWDIR/;
$limit = $ARGV[2] || 100;

$file_name = $filename;
$file_name =~ s/\W/_/g;

mkdir "/tmp/zabbix/read_elg" unless -d "/tmp/zabbix/read_elg" ;

$z_file = "/tmp/zabbix/read_elg/$file_name";

if (-f $z_file ){
  @saved = split /\n/, `cat $z_file`;
  $print = 1;
};

foreach (`cat $filename`){
  next if /^$/;
  next if /^\.$/;
  next if /^\s{0,}\)\s{0,}$/;
  next if /^\s{0,}\(\s{0,}$/;
  next if /^\s{0,}: \(\s{0,}$/;
  s/^.*]//;
  s/ \d{1,} / /;
  next if m#zabbix marker|successfully|succ|Done|Opened FDs|Request rtt|blocked for sec|interfaces found|/dev/fw0|stopping debug#i;
  chomp;

  $db{$_} +=1;
}

LOOP:
foreach (keys %db){
  next unless $_;
  next unless $db{$_} > $limit;
  $msg = $_;
  $count = $db{$_};

  $msg_new = "$msg %%% $time\n";

  foreach $saved (@saved){
    print "foreach saved: $saved\n" if $debug;

    ($msg_saved,$time_saved) = split/ %%% /, $saved;

    print "foreach @saved: split msg_saved $msg_saved, time_saved: $time_saved\n" if $debug;

    if ($msg_saved eq $msg) {
      if (($time-$time_saved ) < 60*60){
        print "time - $time_saved < 60*60\n" if $debug;

        print "adding $msg %%% $time_saved to $saved_new\n" if $debug;
        $msg_new = "$msg %%% $time_saved\n";

        print "next LOOP" if $debug;
        next LOOP;
      }
    }
  }

  $saved_new .= $msg_new;
  $change = 1;
  print "$msg\n" if $print;
}

if ($change){
  print "Saving new file: $saved_new\n" if $debug;
  open FH, ">", $z_file or die "Can't write to $z_file: $!\n";

  print FH $saved_new;
  close FH;
}
