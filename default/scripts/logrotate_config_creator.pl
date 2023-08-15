#!/bin/perl

$0 = "logrotate config creator";

if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}


foreach (`find / -type f -size +200M 2>/dev/null`){
  next if m#/home#;
  next unless /\.log$|\.elg$/;
  next if m#/opt/CPInstLog#;
  next if m#20\d\d-\d\d-\d\d.*log#;
  next if m#zabbix_agentd.log#;
  next if m#fw.log$#;
  #next if m##;
  chomp; 

  create_logrotate_config_file($_);

}


sub create_logrotate_config_file {
  my $filename = shift || die "Need a filename";

  #($name) = $filename =~ m#.*/(.*)#;
  $name = $filename;
  $name =~ s/\W/_/g; 

  return if -f "/etc/logrotate.d/$name";

  open $fh_w,">", "/etc/logrotate.d/$name" or die "Can't write to /etc/logrotate.d/$name: $!\n";

  print $fh_w <<EOF;
$filename {
    daily
    notifempty
    rotate 10
    compress
    size 100M
    #minsize 100M
    copytruncate
    dateext
    missingok
}
EOF

  close $fh_w;
}
