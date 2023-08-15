#!/bin/perl
#bin

if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

my $table_name   = "rad_services";
my $object_name  = "urlf_rad_service_0";
my $field_name   = "cache_max_hash_size";


my $result_mgmt = get_mds();
print $result_mgmt;

print "Select CMA by number: ";
chomp ($question_mgmt = <>);
die "Need a CMA to change. Exiting\n" unless $question_mgmt;

my ($cma) = $result_mgmt =~/$question_mgmt (.*)/;


my $result_gw = get_gw();
print $result_gw;

print "Select GW by number: ";
chomp ($question_gw = <>);
die "Need a GW to change. Exiting\n" unless $question_gw;

($gw) = $result_gw =~/$question_gw (.*)/;


my $table_size_old = get_table_size();
print "Old size for $table_name is: $table_size_old\n";

my $rec_new = ($table_size_old*2);

print "New $table_name table size ($rec_new): ";
chomp ($question_size = <>);
$question_size ||= $rec_new;
print "New table size will be: $question_size\n";

print 'Make change? (y/N): ';
chomp ($question_change = <>);
exit unless $question_change =~ /^y$/i;


$out_db_edit = `source /opt/CPmds-R80/scripts/MDSprofile.sh; mdsenv $cma; echo -e "modify $table_name $object_name $field_name $question_size\nupdate_all\nquit\n" | dbedit -local`;

$table_size_new = get_table_size();
print "table size is changed to: $table_size_new\n";

print "\n\nYou need to install the policy for this to take effect\n";

sub get_table_size {

  my $out_db_read = `source /opt/CPmds-R80/scripts/MDSprofile.sh; mdsenv $cma; echo -e "print $table_name $object_name\nquit\n" | dbedit -local`;
  ($num_size_old) = $out_db_read =~ /$field_name: (.*)/;

  return $num_size_old;
}

sub get_mds {
  $count = 0;
  my $result_mgmt;
  foreach (sort `mdsstat`){
    @split = split/\s{0,}\|\s{0,}/;
    next unless $split[1] eq CMA;
    $count++;
  
    $msg = "$count $split[2]";
    $result_mgmt .= "$msg\n";
  
  }
  return $result_mgmt;
}
  
sub get_gw {
  $count = 0;
  foreach (`source /opt/CPmds-R80/scripts/MDSprofile.sh; mdsenv $cma; cpmiquerybin attr "" network_objects "type='gateway_cluster'" -a __name__,ipaddr`) {
    $count++;
    chomp;
    s/\s{1,}.*//;
    $msg = "$count $_";
    $result_gw .= "$msg\n";
  }
  return $result_gw;
}
