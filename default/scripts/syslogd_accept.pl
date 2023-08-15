#!/bin/perl

$0 = "check syslogd";

if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

my $debug = 0;

exit unless is_mgmt();

my $config_changed = check_syslogd_config();

if ($config_changed){
  print "Config changed. killing syslogd\n" if $debug;
  system "killall syslogd";
}

my ($running,$ss) = check_if_syslogd_is_running();

unless ($running) {
  if ($ss) {
    my $pid = get_pid($ss);
  
    if ($pid) {
      print "wrong process running as PID $pid\nkill -9 $pid\n" if $debug;
      system "kill -9 $pid";
    }
  }

  #kill syslogd if there any running\n" if $debug;
  system "killall syslogd";
  my $restarted = start_syslogd();
  print 2;
}
else {
  print 1;
}  

sub check_syslogd_config {
  my $cmd_grep = qq#grep -- "info -r" /etc/sysconfig/syslog#;
  print "$cmd_grep\n" if $debug;
  my $out_grep = `$cmd_grep`;
  print "$out_grep\n" if $debug;

  if ($out_grep){
    print "Found -r in syslog config. No changes needed\n" if $debug;

    #Config not changed
    return 0;
  }
  else {
    print "Could not find -r in syslog config. Change needed\n" if $debug;
    system qq#perl -pi -e 's/SYSLOGD_OPTIONS="-m 0 -z 515 -P info"/SYSLOGD_OPTIONS="-m 0 -z 515 -P info -r"/;' /etc/sysconfig/syslog#;
    system "chattr +i /etc/sysconfig/syslog";
    #system "service syslog restart";

    #Config file changed
    return 1;
  }
}


sub check_if_syslogd_is_running {
  my $cmd_ss = qq#ss -pleantu | grep ":514 "#;
  print "$cmd_ss\n" if $debug;
  my $out_ss = `$cmd_ss`; 
  print "$out_ss\n" if $debug;

  #Check if syslogd is running and listening on *
  if ($out_ss =~ /syslogd/ && $out_ss =~ /\*:514/){
    print "syslogd is running and listening on *:514\n" if $debug;
    return 1;
  }
  else {
    print "syslogd not running like it should\nRestart needed\n" if $debug;
    return 0,$out_ss;

  }
}

sub get_pid {
  my $out = shift or die "Need input from ss\n";

  my ($pid) = $out =~ /\(".*?",(\d{1,}),.*?\)/;

  unless ($pid) {  
    ($pid) = $out =~ /\(".*?",pid=(\d{1,}),/;
  }

  return $pid;
}

sub start_syslogd {
  my $cmd_syslog = "syslogd -m 0 -z 515 -P info -r -f /var/run/syslog.conf";
  print "$cmd_syslog\n" if $debug;
  my $out_syslog = `$cmd_syslog`;
  print "$out_syslog\n" if $debug;
  
  return 1;
}

sub is_mgmt {
  my $fwm_out = `fwm ver 2>&1`;
  if ($fwm_out =~ /This is Check Point Security Management Server/){ 
    print "This is a MGMT server\n" if $debug;
    return 1;
  }
  else {
    print "This is NOT a MGMT server\n" if $debug;
    return 0;
  }
}
