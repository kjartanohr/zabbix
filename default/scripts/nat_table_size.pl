#!/bin/perl
#bin

if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}


$count = 0;
foreach (`mdsstat`){
  @split = split/\s{0,}\|\s{0,}/;
  next unless $split[1] eq CMA;
  $count++;

  $msg = "$count $split[2]";
  print "$msg\n";
  $result_mgmt .= "$msg\n";

}

print "Select CMA by number: ";
chomp ($question_mgmt = <>);
die "Need a CMA to change. Exiting\n" unless $question_mgmt;

($cma) = $result_mgmt =~/$question_mgmt (.*)/;

$count = 0;
foreach (`source /opt/CPmds-R80/scripts/MDSprofile.sh; mdsenv $cma; cpmiquerybin attr "" network_objects "type='gateway_cluster'" -a __name__,ipaddr`) {
  $count++;
  chomp;
  s/\s{1,}.*//;
  $msg = "$count $_";
  print "$msg\n";
  $result_gw .= "$msg\n";
}

print "Select GW by number: ";
chomp ($question_gw = <>);
die "Need a GW to change. Exiting\n" unless $question_gw;

($gw) = $result_gw =~/$question_gw (.*)/;

$out_nat_size = `source /opt/CPmds-R80/scripts/MDSprofile.sh; mdsenv $cma; echo -e "print network_objects $gw\nquit\n" | dbedit -local`;
($nat_size_old) = $out_nat_size =~ /NAT_cache_nentries: (.*)/;
print "Old NAT size is: $nat_size_old\n";

my $rec_new = ($nat_size_old*2);

print "New NAT table size ($rec_new): ";
chomp ($question_nat = <>);
$question_nat ||= $rec_new;
print "New NAT table size will be: $question_nat\n";

print 'Make change? (y/N): ';
chomp ($question_change = <>);
exit unless $question_change =~ /^y$/i;


$out_nat = `source /opt/CPmds-R80/scripts/MDSprofile.sh; mdsenv $cma; echo -e "modify network_objects $gw firewall_setting:NAT_cache_nentries $question_nat\nupdate_all\nquit\n" | dbedit -local`;
#print $out_nat;

$out_nat_size = `source /opt/CPmds-R80/scripts/MDSprofile.sh; mdsenv $cma; echo -e "print network_objects $gw\nquit\n" | dbedit -local`;
($nat_size_new) = $out_nat_size =~ /NAT_cache_nentries: (.*)/;
print "NAT size is changed to: $nat_size_new\n";

print "\n\nYou need to install the policy for this to take effect\n";
