#!/bin/perl


if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

$vsid            = shift @ARGV || 0;
$dns_server      = shift @ARGV || "8.8.8.8";
$resolve_domain  = shift @ARGV || "vg.no";
$resolve_count   = shift @ARGV || 10;
$timeout         = shift @ARGV || 5;
$timeout_dig     = shift @ARGV || 2;
$debug           = shift @ARGV || 0;
#$time_high       = 9999;

eval {
  local $SIG{ALRM} = sub { die "alarm\n" };
  alarm $timeout;
  print "timeout: $timeout\n" if $debug;

  foreach (1 .. $resolve_count){

    my $cmd = "source /etc/profile.d/vsenv.sh; vsenv $vsid &>/dev/null ; dig +timeout=$timeout_dig $resolve_domain \@$dns_server 2>&1";
    print "$cmd\n" if $debug;
    $out = `$cmd`;
    print $out if $debug;

    #;; Query time: 8 msec
    ($time) = $out =~ m/Query time: (\d*) msec/;
    $time_high = $time if $time > $time_high;

  }
};

print "\$time_high: $time_high\n" if $debug;

if ($@){
  print $time_high // 9999;
  print "timeout: $@\n" if $debug;
  exit;
}

print $time_high;

