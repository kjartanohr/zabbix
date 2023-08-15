#!/bin/perl
#bin

if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

foreach (`cat /tmp/zabbix_agentd.log`){s/^\s{1,}//;
 ($data) = /(^.*?) /;
  ($pid,$date,$time) = split /:/, $data;

  $time =~ s/(\d\d)(\d\d)(\d\d).*/\1:\2:\3/;
  $time_unix = `date -d "$time" "+%s"`;
  chomp $time_unix;

  if (/End of zbx_popen/){
    $za{$pid} = $time_unix;
    next;
  }

  if (/EXECUTE_STR/){
    $zc{$pid} = $_;
  }

  if (/Requested/){
    $zi{$pid} = $_;
  }

  if ($za{$pid} and /EXECUTE_STR/){
    $time_used = ($time_unix-$za{$pid});

    next unless $time_used > 1;

  print "$time_used $zi{$pid} $zc{$pid}\n";
   $za{$pid} = "";


  }
}
