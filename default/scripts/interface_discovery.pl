#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
  
  #Zabbix health check
  zabbix_check($ARGV[0]) if defined $ARGV[0] and $ARGV[0] eq "--zabbix-test-run";
}

use warnings;
no warnings qw(redefine);
use strict;
use JSON;

$0 = "perl interface discovery VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

my $dir_tmp        = "/tmp/zabbix/interface_discovery//";
our $file_debug    = "$dir_tmp/debug.log";
our $debug         = 0;
my %json;

my $json = JSON->new();
$json->relaxed(1);
$json->ascii(1);
$json->pretty(1);

create_dir($dir_tmp);

#Delete log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);

my @interfaces = get_interfaces();
unless (@interfaces) {
  debug("Could not find any interfaces. Seomthing is wrong", "fatal", \((caller(0))[3]) );
  exit;
}

my $config = run_cmd('clish -c "show configuration"');
unless ($config) {
  debug("Could not get clish config. Something is wrong. Will continue without a config", "error", \((caller(0))[3]) );
}

foreach my $int (@interfaces) {
  debug("foreach my \$int \@interfaces", "debug", \((caller(0))[3]) ) if $debug;

  my $comment = get_config_comment('config' => \$config, 'interface' => $int) || "";
  my $type    = get_interface_type('interface' => $int) || "";

  debug("Interface: $int, Comment: $comment", "debug", \((caller(0))[3]) ) if $debug;


  push @{$json{'data'}}, {
    '{#NAME}'       => $int,
    '{#COMMENT}'    => $comment,
    '{#TYPE}'       => $type,
  };
}

my $json_string = $json->encode(\%json);
print $json_string;

#End of standard header

sub get_interfaces {
  debug("Start", "debug", \((caller(0))[3]) ) if $debug;
  my @interfaces;

  #/sys/class/net/ START
  my $dir_net = "/sys/class/net/";
  debug("Checking if $dir_net exists", "debug", \((caller(0))[3]) ) if $debug;

  if (-d $dir_net) {
    debug("$dir_net found. Will open the directory and list the files", "debug", \((caller(0))[3]) ) if $debug;

    my ($dh_status) = opendir my ($dh_net), $dir_net;
    unless ($dh_status) {
      debug("Could not open directory: $dir_net", "fatal", \((caller(0))[3]) );
    }

    my $file_count = 0;
    foreach my $file (readdir $dh_net) {
      next if $file =~ /^\.$|^\.\.$/;
      $file_count++;

      push @interfaces, $file;
    }

    debug("Found $file_count files", "debug", \((caller(0))[3]) ) if $debug;

    if ($file_count > 0) {
      debug("Found more than 0 files, returning interfaces", "debug", \((caller(0))[3]) ) if $debug;
      return @interfaces;
    }
    else {
      debug("Found 0 files. Something is wrong. Will not return any data", "error", \((caller(0))[3]) );
    }
  }
  #/sys/class/net/ END


  debug("Code error. Should not be here", "error", \((caller(0))[3]) );
}

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
