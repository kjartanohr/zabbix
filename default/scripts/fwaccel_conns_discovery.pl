#!/usr/bin/perl5.32.0

# 2023.01.27

BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
  
  #Zabbix health check
  zabbix_check($ARGV[0]) if defined $ARGV[0] and $ARGV[0] eq "--zabbix-test-run";
}

use warnings;
no warnings qw(redefine);
use strict;
use JSON;

$0 = "perl fwaccel conns discovery VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

my %argv = @ARGV;

my $vsid            = shift @ARGV // 0;
my $dir_tmp         = "/tmp/zabbix/fwaccel_conns_discovery//";
our $file_debug     = "$dir_tmp/debug.log";
our $debug          = 0;
our $error          = 1;
my %json;

my $cmd_fwaccel_conns = "fwaccel conns -v";

my $json = JSON->new();
$json->relaxed(1);
$json->ascii(1);
$json->pretty(1);

debug("create_dir()", 'debug', \[caller(0)]) if $debug;
create_dir($dir_tmp);

#Delete log file if it's bigger than 10 MB
debug("trunk_file_if_bigger_than_mb()", 'debug', \[caller(0)]) if $debug;
trunk_file_if_bigger_than_mb($file_debug,10);

debug("run_cmd()", 'debug', \[caller(0)]) if $debug;
my @conns = run_cmd({
  'cmd'             => $cmd_fwaccel_conns,
  'return-type'     => 'a',
  'vsid'            => $vsid,
  'refresh-time'    => 600,
  'timeout'         => 5,
});
debug("run_cmd() done", 'debug', \[caller(0)]) if $debug;
debug("\@conns: ".Dumper(@conns), 'debug', \[caller(0)]) if $debug > 5;
unless (@conns) {
  debug("Could not find any connections. Something is wrong", "fatal", \((caller(0))[3]) );
  exit;
}


#Source          SPort Destination     DPort PR Flags           TCP state        C2S i/f S2C i/f Inst PPAK ID Policy ID (FW/UP)         CPU Held Pkts Total Pkts  Total Bytes Last Seen  Duration   TTL/Timeout Actual TTL/Timeout
#--------------- ----- --------------- ----- -- --------------- ---------------- ------- ------- ---- ------- -----------------         --- --------- ----------- ----------- ---------- ---------- ----------- ------------------
#   13.1.1.1   443   62.1.1.1 54062  6 ..NA......L.....       Source FIN   18/15   15/18   15       0 3170837706/1655108131   37         0          10        988B   3h32m32s    3h33m5s 39818/52570 39818/52510 (eligible)
#    62.1.1.1    53   10.1.1.1 55798 17 ..NA..S...L.....      Unknown 0x0   18/15   15/18   28       0 3170837706/1655108131   39         0           2        554B         6s         6s       34/40  9/12 (aggressive)
#   10.1.1.1 51160 130.117.190.213   443  6 ..NA..S.........      Established   18/15   15/18   31       0 3170837706/1655108131   39         0          32      3.44KB        42s      6m43s   3558/3600 18/60 (aggressive)

my $count = 0;
my $parse = 0;

CONNS:
foreach my $line (@conns) {
  debug("foreach my \$line \@conns: $line", "debug", \((caller(0))[3]) ) if $debug  > 5;

  if ($line =~ /^Idx Interface/) {
    debug("if (\$line =~ /^Idx Interface/) is true", 'debug', \[caller(0)]) if $debug;
    last CONNS;
  }

  if ($line =~ /^-{14}/) {
    debug("if (\$line =~ /^-{14}/) is true", 'debug', \[caller(0)]) if $debug;
    $parse = 1;
  }

  unless ($parse) {
    debug("unless (\$parse) is true", 'debug', \[caller(0)]) if $debug;
    next CONNS
  }

  chomp $line;

  if (length $line == 0) {
    debug("if (length \$line == 0) is true", 'debug', \[caller(0)]) if $debug;
    next CONNS;
  }


  $line =~ s/^\s{1,}//;

  my %data;
  #Source          SPort Destination     DPort PR Flags           TCP state        C2S i/f S2C i/f Inst PPAK ID Policy ID (FW/UP)         CPU Held Pkts Total Pkts  Total Bytes Last Seen  Duration   TTL/Timeout Actual TTL/Timeout
  #   10.1.1.1 51160 130.117.190.213   443  6 ..NA..S.........      Established   18/15   15/18   31       0 3170837706/1655108131   39         0          32      3.44KB        42s      6m43s   3558/3600 18/60 (aggressive)
  #
  ($data{'source-ip'}, $data{'source-port'}, $data{'destination-ip'}, $data{'destination-port'}, $data{'protocol'}, $data{'flags'}, $data{'tcp-state'}, $data{'c2s'}, $data{'if'}, $data{'inst'}, $data{'ppak'}, $data{'policy-id'}, $data{'cpu'}, $data{'package-held'}, $data{'packets-total'}, $data{'bytes-total'}, $data{'last-seen'}, $data{'duration'}, $data{'ttl'}, $data{'ttl-actual'}) = $line =~ /
    (.*?)\s{1,} #source-ip
    (.*?)\s{1,} #source-port
    (.*?)\s{1,} #destination-ip
    (.*?)\s{1,} #destination-port
    (.*?)\s{1,} #protocol
    (.*?)\s{1,} #flags
    (.*?)\s{3,} #tcp-state
    (.*?)\s{1,} #c2s
    (.*?)\s{1,} #if
    (.*?)\s{1,} #inst
    (.*?)\s{1,} #ppak
    (.*?)\s{1,} #policy-id
    (.*?)\s{1,} #cpu
    (.*?)\s{1,} #package-held
    (.*?)\s{1,} #packets-total
    (.*?)\s{1,} #bytes-total
    (.*?)\s{1,} #last-seen
    (.*?)\s{1,} #duration
    (.*?)\s{1,} #ttl
    (.*?)\s{1,} #ttl-actual
    #(.*?)\s{1,} #ttl-unknown
  /x;

  foreach my $key (keys %data) {
    if (not defined $data{$key}) {
      debug("\$data{$key} is not defined. next CONNS. \$line: $line",  'error', \[caller(0)]) if $error;
      next CONNS;
    }
  }

  my $duration_sec = 0;
  if ($data{'duration'} =~ /(\d{1,})h/){
    $duration_sec += ($1 * 60 * 60);
  }
  if ($data{'duration'} =~ /(\d{1,})m/){
    $duration_sec += ($1 * 60);
  }
  if ($data{'duration'} =~ /(\d{1,})s/){
    $duration_sec += $1;
  }

  my $last_seen_sec = 0;
  if ($data{'last-seen'} =~ /(\d{1,})h/){
    $last_seen_sec += ($1 * 60 * 60);
  }
  if ($data{'last-seen'} =~ /(\d{1,})m/){
    $last_seen_sec += ($1 * 60);
  }
  if ($data{'last-seen'} =~ /(\d{1,})s/){
    $last_seen_sec += $1;
  }

  if (defined $argv{'last-seen-min'} and $last_seen_sec > $argv{'last-seen-min'} ){
    print "$last_seen_sec sec. $line\n";
    next CONNS;
  }

  #debug("\$duration_sec: $duration_sec", 'debug', \[caller(0)]) if $debug;
  if ($duration_sec < 1*24*60*60) {
    next CONNS;
  }
  $data{'duration-sec'} = $duration_sec;
  #debug("\$duration_sec: $duration_sec", 'debug', \[caller(0)]) if $debug;
  

  my $bytes_total = 0;
  if ($data{'bytes-total'} =~ /(\d{1,})KB/){  $bytes_total += $1 * 1024 }
  if ($data{'bytes-total'} =~ /(\d{1,})MB/){  $bytes_total += $1 * 1024**2 }
  if ($data{'bytes-total'} =~ /(\d{1,})GB/){  $bytes_total += $1 * 1024**3 }
  if ($data{'bytes-total'} =~ /(\d{1,})TB/){  $bytes_total += $1 * 1024**4 }

  if ($bytes_total < 1*1024**3) {
    next CONNS;
  }
  $data{'bytes-total-byte'} = $bytes_total;

  my %data_keys;
  $count++;
  $data_keys{"{#COUNT}"} = $count;
  foreach my $key (keys %data) {

    my $key_uc = uc $key;

    $data_keys{"{#$key_uc}"} = $data{$key};
  }

  #print Dumper %data_keys;
  push @{$json{'data'}}, \%data_keys ;

  #push @{$json{'data'}}, {
  #  '{#NAME}'       => $int,
  #  '{#COMMENT}'    => $comment,
  #  '{#TYPE}'       => $type,
  #};


}

#print Dumper $json{'data'};

my $json_string = $json->encode(\%json);
print $json_string;

#End of standard header

sub get_config_comment {
  debug("Start", "debug", \((caller(0))[3]) ) if $debug;
  my %input = @_;

  $input{'config'}      ||= "";  #clish config file in scalar ref
  $input{'interface'}   ||= "";  #name of interface

  unless (ref $input{'config'}) {
    debug("Missing input data: config. Code error. Returning with no data", "fatal", \((caller(0))[3]) );
    return;
  }

  unless ($input{'interface'}) {
    debug("Missing input data: interface. Code error. Returning with no data", "fatal", \((caller(0))[3]) );
    return;
  }
  debug("Input data. interface: $input{'interface'}", "debug", \((caller(0))[3]) ) if $debug;

  my ($comment) = ${$input{'config'}} =~ /set interface $input{'interface'} comments (.*)/;
  if ($comment) {
    chomp $comment;
    $comment =~ s/"//g;
    $comment =~ s/^\s{1,}//g;
    $comment =~ s/\s{1,}$//g;
    debug("Found comment in config: $comment", "debug", \((caller(0))[3]) ) if $debug;
  }
  else {
    debug("Could not find any comment for interface $input{'interface'} in clish config. Will not return any data", "warning", \((caller(0))[3]) );
    return;
  }


  return $comment;
}


sub get_interface_type {
  debug("Start", "debug", \((caller(0))[3]) ) if $debug;
  my %input = @_;
  my $type;

  $input{'interface'}   ||= "";  #name of interface
  unless ($input{'interface'}) {
    debug("Missing input data: interface. Code error. Returning with no data", "fatal", \((caller(0))[3]) );
    return;
  }
  debug("Input data. interface: $input{'interface'}", "debug", \((caller(0))[3]) ) if $debug;

  #TYPES=( bond bond_slave bridge can dummy erspan geneve gre gretap hsr ifb ip6erspan ip6gre ip6gretap ip6tnl ipip ipoib ipvlan ipvtap lowpan macsec macvlan macvtap netdevsim nlmon rmnet sit tap tun vcan veth vlan vrf vti vxcan vxlan xfrm)
  my %interface_type = (
    "lo"          => "local",
    "eth"         => "physical",
    "wan|lan|dmz" => "physical",
    "bareudp"     => "bareudp",
    "bond"        => "bond",
    "bond_slave"  => "bond_slave",
    "bridge"      => "bridge",
    "br"          => "bridge",
    "can" => "can",
    "dummy" => "dummy",
    "erspan" => "erspan",
    "geneve" => "geneve",
    "gre" => "gre",
    "gretap" => "gretap",
    "hsr" => "hsr",
    "ifb" => "ifb",
    "ip6erspan" => "ip6erspan",
    "ip6gre" => "ip6gre",
    "ip6gretap" => "ip6gretap",
    "ip6tnl" => "ip6tnl",
    "ipip" => "ipip",
    "ipoib" => "ipoib",
    "ipvlan" => "ipvlan",
    "ipvtap" => "ipvtap",
    "lowpan" => "lowpan",
    "macsec" => "macsec",
    "macvlan" => "macvlan",
    "macvtap" => "macvtap",
    "netdevsim" => "netdevsim",
    "nlmon" => "nlmon",
    "rmnet" => "rmnet",
    "sit" => "sit",
    "tap" => "tap",
    "tun" => "tun",
    "vcan" => "vcan",
    "veth" => "veth",
    "vlan" => "vlan",
    "vrf" => "vrf",
    "vti" => "vti",
    "vxcan" => "vxcan",
    "vxlan" => "vxlan",
    "xfrm" => "xfrm",
  );

  foreach my $interface_key (keys %interface_type) {
    debug("foreach my $interface_key (keys %interface_type)", "debug", \((caller(0))[3]) ) if $debug > 1;

    if ($input{'interface'} =~ /^$interface_key/i) {
      debug("Match on $input{'interface'} =~ /$interface_key/i. Returning name", "debug", \((caller(0))[3]) ) if $debug;
      return uc $interface_type{$interface_key};
    }
  }


  my $file_uevent = "/sys/class/net/$input{'interface'}/uevent";
  if (-f $file_uevent) {
    debug("Found file $file_uevent. will read it and look for DEVTYPE=", "debug", \((caller(0))[3]) ) if $debug;

    my $uevent_data = readfile($file_uevent);
    my ($type) = $uevent_data =~ /DEVTYPE=(.*)/;

    if ($type) {
      chomp $type;
      debug("Found type in $file_uevent: $type. Retuning type", "debug", \((caller(0))[3]) ) if $debug;
      return $type;
    }
    else {
      debug("Could not find type in $file_uevent: $type", "error", \((caller(0))[3]) ) if $debug;
      return;
    }
  }

  debug("Could not find interface type. Retuning no data", "error", \((caller(0))[3]) );


}

