#!/bin/perl

$0 = "read fwk.elg";

if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}


$vsid = $ARGV[0] || 0;
$FWDIR = `source /etc/profile.d/vsenv.sh; vsenv $vsid &>/dev/null ; echo \$FWDIR`;
chomp $FWDIR;
$filename = "FWDIR/log/fwk.elg";
$filename =~ s/FWDIR/$FWDIR/;
$limit = $ARGV[1] || 100;


$z_file = "/tmp/zabbix/fwk_$vsid";

if (-f $z_file ){
  @saved = split /\n/, `cat $z_file`;
  $print = 1;
};

foreach (`cat $filename`){
  s/^.*?];//;
  s/ \d{2,} / /;
  next if /zabbix marker|fwk_start.*OK|SecureXL.*t p/;
  chomp;

  $db{$_} +=1;
}

LOOP:
foreach (keys %db){
  next unless $db{$_} > $limit;
  $msg = "$_ $db{$_}";
  $saved_new .= "$msg\n";

  foreach $saved (@saved){
    next LOOP if $saved eq $msg;
  }

  $change = 1;
  print "$msg\n" if $print;
}

if ($change){
  open FH, ">", $z_file or die "Can't write to $z_file: $!\n";

  print FH $saved_new;
  close FH;
}
