#!/usr/bin/perl5.32.0
#bin
# 2023.03.27
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

# total for total trafikk
#

if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}


use warnings;
use strict;
use Net::DNS::Resolver;
use Time::HiRes qw( usleep );
use Parallel::ForkManager;
use Storable qw (store retrieve );
use Data::Dumper;


$0                            = "pl-tcpdump-length";
$|++;
$SIG{CHLD}                    = "IGNORE";
$SIG{INT}                     = \&ctrl_c;
#$SIG{__DIE__}                = \&ctrl_c;

zabbix_check($ARGV[0]);
my $date_start                = get_date_time();
my $date_start_safe           = $date_start;
$date_start_safe              =~ s/[: ]/-/g;


my $interface                 = shift // `ip route | perl -ane 'print \$F[4] if \$F[0] eq "default";'`;
#my $interface                 = shift || die "need a interface: $0 eth0";
my $cmd_tcpdump               = "timeout 60 tcpdump -e -s 4000 -nn -n -q -i $interface 2>&1";
#my $cmd_tcpdump              = "tcpdump -nn -n -q -i $interface";
#my $cmd_tcpdump              = "tcpdump -nn -n -i $interface";
#my $cmd_tcpdump              = "cat tcpdump.test";

my $debug                     = 0;
my $dir_home                  = "/var/log/$0";      system "mkdir -p $dir_home"   unless -d $dir_home;
my $dir_db                    = "$dir_home/db";     system "mkdir -p $dir_db"     unless -d $dir_db;
my $dir_stats                 = "$dir_home/stats";  system "mkdir -p $dir_stats"  unless -d $dir_stats;

my $add_to_db_min_count       = 2000;
my $print_stats               = 10; #Sec
my $print_stats_lines         = 15;

my @dns_servers               = "127.0.0.1";
my $file_db                   = "$dir_home/pl-tcpdump-length-$interface.db";
my $file_db_dns               = "$dir_home/$0-dns.db";
my $file_stats                = "$0-$interface-stats.txt";
my $file_stats_local          = $file_stats;
my $file_stats_home           = "$dir_stats/$date_start_safe-$file_stats";
my $file_stats_home_tmp       = "$file_stats_home.tmp";
my $file_stats_home_old       = "$file_stats_home.old";

unlink $file_stats_local if -f $file_stats_local;

my $hostname                  = `hostname`; chomp $hostname;

my %config;

$config{'db'}{'save'} = {
};

$debug = 1 if grep /debug/, @ARGV;


my $resolver    = init_resolver();

my $print_stats_time  = time;
my $db = {};
$db             = get_db($file_db);
%{$$db{'dns'}}     = %{get_db($file_db_dns)};
my $tmp  = {};

my %dns_cache;


my $map    = {

  'alias' => {

    'dns'       => {
      'enabled'   => 1,
      'name'      => 'DNS',
      'desc'      => '',
    },

    'teams'       => {
      'enabled'   => 1,
      'name'      => 'Microsoft Teams',
      'desc'      => '',
    },

    'teams'       => {
      'enabled'   => 1,
      'name'      => 'Microsoft Teams',
      'desc'      => '',
    },

    'google dns'       => {
      'enabled'   => 1,
      'name'      => 'Google DNS',
      'desc'      => '',
    },
  },

  'ports'   => {
    '53'          => 'dns',
    '8080'        => 'proxy',
    '80'          => 'http',
    '443'         => 'https',
    '3478-3481'   => 'teams',
    '10001-10010' => 'pl-dns',
    '10400-10410' => 'teams',
    '3771'        => 'teams',
  },

  'ips'   => {
    '8.8.8.8'    => 'google dns',
    '13.70.151.216/32, 13.71.127.197/32, 13.72.245.115/32, 13.73.1.120/32, 13.75.126.169/32, 13.89.240.113/32, 13.107.3.0/24, 13.107.64.0/18, 51.140.155.234/32, 51.140.203.190/32, 51.141.51.76/32, 52.112.0.0/14, 52.163.126.215/32, 52.170.21.67/32, 52.172.185.18/32, 52.178.94.2/32, 52.178.161.139/32, 52.228.25.96/32, 52.238.119.141/32, 52.242.23.189/32, 52.244.160.207/32, 104.215.11.144/32, 104.215.62.195/32, 138.91.237.237/32' => 'teams',
  },

  'calc'   => [
    10,
    1*60,
    2*60,
    10*60,
  ],



};

my %proto = (
  249 => "ARP Req",
  250 => "ARP Res",
  247 => "RARP Req",
  248 => "RARP Res",
);

print "starting. please wait...\n";

parse_protocol_name();
#print Dumper $$map{'ports'}; exit;

# remove old dns answers
resolve_clean();

# check for unresolved dns queue
resolve_dns(1);
delete $$db{'dns'}{'queue'};


print_stats();

while (1){
open my $ch, "-|", $cmd_tcpdump or die "Can't open $cmd_tcpdump: $!";

while (<$ch>) {
  chomp;

  # TOOD
  # Fyll inn alle felt manuelt
  if (/length 0/){
    next;
  }

  my $proto_custom;
  if (/(oui Cisco|ARP|LLDP|ICMP|ESP|STP|ip-proto-\d\d)/){
    $proto_custom = $1;
    next;
  }


  #
  # 12:18:35.316699 IP 193.227.205.182 > 92.220.216.51:
  #my ($ip_src, $ip_dst) = /^.*IP (\d{1,}\.\d{1,}\.\d{1,}\.\d{1,}).*> (\d{1,}\.\d{1,}\.\d{1,}\.\d{1,})/;

  #my ($port_src, $port_dst) = /^.*IP \d{1,}\.\d{1,}\.\d{1,}\.\d{1,}\.(\d{1,}) > \d{1,}\.\d{1,}\.\d{1,}\.\d{1,}\.(\d{1,})/;

  # Could not parse line: 11:22:26.886391 fa:ff:8f:5a:24:fb > 00:08:00:01:00:01, IPv4, length 62: 92.220.216.51 > 95.141.81.190: ip-proto-50
  # 14:40:52.045022 Out e4:43:4b:ab:53:54 vlan 816, p 0, 85.19.187.122.8080 > 10.145.195.130.49538: tcp 1460
  # 14:27:30.047677 fa:ff:8f:5a:24:fb > 00:08:00:01:00:01, IPv4, length 62: 92.220.216.51 > 95.141.81.190: ip-proto-50
  # 14:20:18.150531 00:08:00:01:00:01 > fa:ff:8f:5a:24:fb, IPv4, length 226: 193.227.205.182 > 92.220.216.51: ESP(spi=0xa2ab5d6f,seq=0xc8a0), length 192
  # 08:52:05.692289 00:1c:7f:44:62:a9 > c4:b2:39:ae:73:9f, IPv4, length 118: 10.14.16.15.22 > 10.13.4.2.41139: tcp 64
  my ($l_time, $mac_src, $mac_direction, $mac_dst, $ipv, $length, $ip_src, $port_src, $ip_direction, $ip_dst, $port_dst, $proto_name, $proto_number) = /(.*?) (.*?) (.*?) (.*?), (.*?), length (.*?): ((?:\d{1,}\.{0,1}){4})(?:[\.:](.*?)){0,1} (.*?) ((?:\d{1,}\.{0,1}){4})(?:[\.:](.*?)){0,1}: (.*?) (.*)/;

  #$ip_src =~ s/\.$//;
  #$ip_dst =~ s/\.$//;

  if (not defined $ip_src or not defined $ip_dst){
    print "Could not parse line: $_\n" if $debug;
    #exit;
    next;
  }
  
  #$port_src   //= 0;
  #$port_dst   //= 0;

  if (not defined $ip_src or not defined $ip_dst or not defined $port_src or not defined $port_dst ){
    print "Could not parse line: $_\n" if $debug;
    #exit;
    next;
  }


  if (not $ip_src =~ /^\d/ or not $ip_dst =~ /^\d/ or not $port_src =~ /^\d/ or not $port_dst =~ /^\d/){
    print "Could not parse line: $_\n" if $debug;
    #exit;
    next;
  }


  $$tmp{'time-start'} //= time;
  if ((time - $$tmp{'time-start'}) > 10){
    $$tmp{'time-start'} = time;
    undef $tmp;
  }

  # dns resolve 
  $$db{'dns'}{'queue'}{'time-start'} //= time;
  if ((time - $$db{'dns'}{'queue'}{'time-start'}) > 120){
    $$db{'dns'}{'queue'}{'time-start'} = time;
    print "time to resolve_dns(1);\n" if $debug;
    resolve_dns(1);
    delete $$db{'dns'}{'queue'};
  }

  # save_db
  $$db{'time-saved'} //= time;
  if ((time - $$db{'time-saved'}) > 120){
    $$db{'time-saved'} = time;
    print "time to save_db_all(1);\n" if $debug;
    save_db_all(1);
  }




  # reduce cpu usage
  my $add_to_stats_ip = 0;
  $add_to_stats_ip = 1 if $add_to_stats_ip == 0 and defined $$db{'stats'}{'ip'}{$ip_src};
  $add_to_stats_ip = 1 if $add_to_stats_ip == 0 and defined $$db{'stats'}{'ip'}{$ip_dst};
  $add_to_stats_ip = 1 if $add_to_stats_ip == 0 and ++$$tmp{'count'}{$ip_src} > $add_to_db_min_count;
  $add_to_stats_ip = 1 if $add_to_stats_ip == 0 and ++$$tmp{'count'}{$ip_dst} > $add_to_db_min_count;


  # DNS resolve
  #if ($add_to_stats_ip){
  #  $$db{'dns'}{'queue'}{'IN'}{'PTR'}{$ip_src} = 'waiting' unless defined $$db{'dns'}{'IN'}{'PTR'}{$ip_src} and not defined $$db{'dns'}{'queue'}{'IN'}{'PTR'}{$ip_src};
  #  $$db{'dns'}{'queue'}{'IN'}{'PTR'}{$ip_dst} = 'waiting' unless defined $$db{'dns'}{'IN'}{'PTR'}{$ip_dst} and not defined $$db{'dns'}{'queue'}{'IN'}{'PTR'}{$ip_dst};
  #}
  $$db{'dns'}{'queue'}{'IN'}{'PTR'}{$ip_src} = 'waiting' unless defined $$db{'dns'}{'IN'}{'PTR'}{$ip_src} and not defined $$db{'dns'}{'queue'}{'IN'}{'PTR'}{$ip_src};
  $$db{'dns'}{'queue'}{'IN'}{'PTR'}{$ip_dst} = 'waiting' unless defined $$db{'dns'}{'IN'}{'PTR'}{$ip_dst} and not defined $$db{'dns'}{'queue'}{'IN'}{'PTR'}{$ip_dst};


  # 09:11:22.645564 IP 85.19.187.123.8080 > 10.138.13.160.60239: Flags [.], ack 158, win 4660, length 0

  #print "\$l_time: $l_time, \$ip_src: $ip_src. \$port_src: $port_src. \$ip_dst: $ip_dst. \$port_dst: $port_dst \n";
  #next unless $ip_src;
  #next unless $ip_dst;

  #$port_src = "ICMP" if /ICMP echo/;
  #$port_dst = "ICMP" if /ICMP echo/;

  #$port_src = "ESP" if /ESP/;
  #$port_dst = "ESP" if /ESP/;

  #($port_src) = /: (.*)/ unless $port_src;
  #($port_dst) = /: (.*)/ unless $port_src;
  #$port_src   //= 0;
  #$port_dst   //= 0;

  #print "unknown port $_" unless $port_src;

  my $proto_port;
  $proto_port   //= $port_dst;
  $proto_port   //= $port_src;
  $proto_port   //= 0;
  $proto_port   = $port_src if not $proto_port == 0 and $port_src < $port_dst;

  #$port_dst = "unknown port" unless $port_dst;
  #$port_src = "unknown port" unless $port_src;

  my $proto_dst //= get_protocol_name($port_dst);
  my $proto_src //= get_protocol_name($port_src);
  #$port_src = $proto if $proto;
  #$port_dst = $proto if $proto;

  #my ($length) = /length (\d{1,})/;

  if (not defined $length){
    print "\$length is undefined: $_\n" if $debug;
    $length = 0;
  }

  my $time = time;

  #$$db{'stats'}{'total'}{'total'}{'total'} += $length;

  my %stats_keys = (
    'total'                     => 'total', 
    #'ip'                       => "$ip_src,$ip_dst", 
    'ip-ip'                     => "$ip_src <-> $ip_dst,$ip_dst <-> $ip_src", 
    'ip-src-dst'                => "$ip_src -> $ip_dst", 
    'ip-dst-src'                => "$ip_dst -> $ip_src", 
    'ip-src'                    => $ip_src, 
    'ip-dst'                    => $ip_dst, 
    'port'                      => "$port_src,$port_dst", 
    #'port-src'                 => $port_src, 
    'port-dst'                  => $port_dst, 
    'proto'                     => "$proto_dst,$proto_src",
  );

  $stats_keys{'ip'}             = "$ip_src,$ip_dst" if $add_to_stats_ip;
  $stats_keys{'ip-port'}        = "$ip_src:$port_src,$ip_src:$port_dst,$ip_dst:$port_src,$ip_dst:$port_dst" if $add_to_stats_ip;

  foreach my $stats_keys (keys %stats_keys){

    my $db_type = \%{$$db{'stats'}{$stats_keys}{'total'}{'total'}};
    $$db_type{'time'}{'start'}         //= $time;
    $$db_type{'time'}{'start-date'}    //= get_date_time();
    $$db_type{'lines'}                 +=1;
    $$db_type{'length'}                +=$length;

    foreach my $stats_key_value (split/,/, $stats_keys{$stats_keys}){

      next if not defined $stats_key_value;
      next if not $stats_key_value;
      #print "\$stats_keys: $stats_keys. \$stats_add: $stats_key_value\n";
      my $db_stats = \%{$$db{'stats'}{$stats_keys}{$stats_key_value}};

      # add to total stats
      my $db_total = \%{$$db_stats{'total'}};
      $$db_total{'time'}{'start'}         //= $time;
      $$db_total{'time'}{'start-date'}    //= get_date_time();
      $$db_total{'lines'}                 +=1;
      $$db_total{'length'}                +=$length;

      #print Dumper $db; exit;

      # calc stats START
      foreach my $calc_key (@{$$map{'calc'}}){
        my $calc = \%{$$db_stats{'calc'}{$calc_key}};


        $$calc{'length'}              //= 0;
        $$calc{'time'}{'start'}       //= $time;
        $$calc{'time'}{'start-date'}  //= get_date_time();

        # reset calc key START
        my $time_since_start = (time - $$calc{'time'}{'start'});
        if ($time_since_start > $calc_key){
          $$calc{'length'}          = 0;
          $$calc{'time'}{'start'}   = $time;
        }
        # reset calc key END

        # add to counter
        $$calc{'length'}  += $length;
        $$calc{'lines'}   += 1;

        next;
        # peak stats START

        my @peak_keys = qw(length lines);
        foreach my $peak_key (@peak_keys){
          
          my $calc_sec    = ($$calc{'length'} / $calc_key); 
          my $calc_peak   = \%{$$calc{'peak'}{$peak_key}};

          $$calc_peak{'max'}{'value'} //= 0;

          # max peak START
          if ($calc_sec > $$calc_peak{'max'}{'value'}){
            $$calc_peak{'max'}{'value'} =  $calc_sec;
            $$calc_peak{'max'}{'time'}  =  $time;
          }
          # max peak END

          # min peak START
          $$calc_peak{'min'}{'value'} //= 99999;

          if ($calc_sec < $$calc_peak{'min'}{'value'}){
            $$calc_peak{'min'}{'value'} =  $calc_sec;
            $$calc_peak{'min'}{'time'}  =  $time;
          }
          # min peak END

        }


        # peak stats END

      }
      # calc stats END
      #print Dumper $db; exit;
    

    } 
  }


  if ((time - $print_stats_time) > $print_stats) {
    print_stats();
    $print_stats_time = time;
  }
}
}

print "encode of code. master print_stats();\n";
print_stats();

print "end of code. master save_db_all()\n";
save_db_all();


sub ctrl_c {
  print "exiting.. need to resolve the dns queue and save the database file. Please do NOT stop this\n";
  print Dumper @_ if $debug;
  print Dumper $@ if $debug;
  print Dumper $! if $debug;
  exit if defined $$db{'fork'};
  print "CTRL+C\n" if $debug;
  print_stats();

  resolve_dns(1);
  delete $$db{'dns'}{'queue'};
  save_db_all();
  
  exit;
}

sub print_stats {
  system "clear";
  print "print stats\n" if $debug;
  my $date_now = get_date_time();

  my $print_out;
  
  print "CMD: $cmd_tcpdump. \n";
  print "Time start: $date_start. Time now: $date_now\n";
  if ($debug){
    my $dns_queue = scalar keys %{$$db{'dns'}{'queue'}{'IN'}{'PTR'}};
    print "hostname: $hostname. dns queue: $dns_queue\n"; 
  }


    # $db -> stats -> ip/port/prot -> total/ip-src/ip-dst/port/pro -> total -> length/lines

    # IP 
    my $db_out = {};
    my $db_new = {};
    $$db_new{'stats'}{'total'} = $$db{'stats'}{'total'};
    #delete $$db{'stats'}{'total'};

    open my $fh_stats_txt, ">", $file_stats_home_tmp or die "Can't write to $file_stats_home_tmp: $!";

    #print Dumper $db; exit;

    foreach my $stats_type (keys %{$$db{'stats'}}){

      if ($stats_type eq 'total'){
        %{$$db_new{'stats'}{$stats_type}} = %{$$db{'stats'}{$stats_type}};
        #delete $$db{'stats'}{$stats_type};
        #next;
      }

    
      # print Dumper $stats_type; exit;
      my $db_name_count_max = 200;
      my $db_name_count     = 0;
      foreach my $stats_name (keys %{$$db{'stats'}{$stats_type}}){

        if ($stats_name eq 'total'){
          %{$$db_new{'stats'}{$stats_type}{$stats_name}} = %{$$db{'stats'}{$stats_type}{$stats_name}};
          #delete $$db{'stats'}{$stats_type}{$stats_name};
          #next;
        }

        # validate
        my $db_stats = \%{$$db{'stats'}{$stats_type}{$stats_name}};
        #print Dumper $db_stats; exit;
        if (not defined $$db_stats{'total'}{'lines'}){
          #print "\$\$db_stats{'total'}{'lines'} not defined\n" if $debug;
          print "\$\$db{'stats'}{$stats_type}{$stats_name} is not defined\n" if $debug;
          print "\$db_stats: ".Dumper $db_stats if $debug;
          #print Dumper $$db{'stats'}{$stats_type};
          ctrl_c();
        }

        $db_name_count++;
        #if ($db_name_count > $db_name_count_max){
        #  delete $$db{'stats'}{$stats_type}{$stats_name};
        #  next;
        #}

        next if $stats_name eq 'total';
        $$db_out{$stats_type}{'lines'}{$stats_name}    = $$db_stats{'total'}{'lines'};
        $$db_out{$stats_type}{'length'}{$stats_name}   = $$db_stats{'total'}{'length'};
        $$db_out{$stats_type}{'length'}{'total'}      += $$db_stats{'total'}{'length'};
      }
    }

    #print "db_out\n";
    #print Dumper $db_out; exit;
   
    #print "total: ".formatSize($$db_new{'stats'}{'total'}{'total'}{'total'}{'length'})."\n" if $debug;
  print "total: ".formatSize($$db{'stats'}{'total'}{'total'}{'total'}{'length'})."\n";

  foreach my $stats_type (sort keys %{$db_out}){
    my $db_stats = \%{$$db_out{$stats_type}};
    #print Dumper $db_stats; exit;

      my $count_clean = 0;
      CLEAN_STATS:
      foreach my $stats_key (keys %{$db_stats}) {

        next if $stats_key eq 'total';

        CLEAN_NAME:
        foreach my $name_key (reverse sort { $$db_stats{$stats_key}{$a} <=> $$db_stats{$stats_key}{$b} } keys %{$$db_stats{$stats_key}}) {

          #print Dumper $$db_stats{$stats_key}{$name_key}; exit;

          $count_clean++;
          next CLEAN_STATS if $count_clean > 1_000;
          %{$$db_new{'stats'}{$stats_type}{$name_key}} = %{$$db{'stats'}{$stats_type}{$name_key}};
        }
      }


          if (1){

            DB_STATS:
            foreach my $data_type_key (sort keys %{$db_stats}) {

              next if $data_type_key eq 'lines';

              my $stats_header_print;

              print $fh_stats_txt "\n\n$stats_type $data_type_key. ";
              $stats_header_print .= "\n\n$stats_type. ";

              my $total_print;
              $total_print          = "total bytes: ".formatSize($$db_stats{$data_type_key}{'total'})."\n" if $data_type_key eq 'length';
              $total_print          = "total lines: $$db_stats{$data_type_key}{'total'}\n" if $data_type_key eq 'lines';
              print $fh_stats_txt $total_print;
              $stats_header_print .= $total_print;

              my $count_stats_txt   = 0;
              my $count_stats_print = 0;
              DATA_TYPE:
              foreach my $key (reverse sort { $$db_stats{$data_type_key}{$a} <=> $$db_stats{$data_type_key}{$b} } keys %{$$db_stats{$data_type_key}}) {
                next DATA_TYPE if $key eq 'total';
                last DATA_TYPE if $count_stats_txt++ == 100;

                my $value           = $$db_stats{$data_type_key}{$key};
                my $value_lines     = formatSize($$db_stats{'lines'}{$key});
                $value_lines        = substr $value_lines, 0, -1;
                #my ($value_lines_value, $value_lines_type) = split/ /,$value_lines;
                #$value_hr_value = int $value_hr_value;

                # stop if less than 10 MB
                #last if $value < 10*1024*1024;

                my $value_hr        = $value;
                #$value_hr          = formatSize($value) if $data_type_key eq 'length';
                $value_hr           = formatSize($value);
                my ($value_hr_value, $value_hr_type) = split/ /,$value_hr;
                $value_hr_value     = int $value_hr_value;

                my $extra_info      = "";

                my $regex_ip = '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}';
                foreach my $ip ($key =~ /($regex_ip)/g){
                  my $dns_result    = resolve_ptr($ip);
                  $extra_info       .= "$dns_result. " if $dns_result;
                }

                $extra_info         = get_protocol_name($key)   if $stats_type eq 'port'; 
                $extra_info         = resolve_ptr($key)         if $stats_type =~ /^(?:ip|ip-src|ip-dst)$/; 

                #my $total          = $$db_new{'stats'}{'total'}{'total'}{'total'}{'length'};
                my $total           = $$db_new{'stats'}{$stats_type}{'total'}{'total'}{$data_type_key};

                my $percent         = 0;
                $percent            = int ( ( $value / $total) * 100 ) if $total;
                #my $peak           = formatSize($$db{'stats'}{$stats_type}{$key}{'calc'}{60}{'peak'}{'length'}{'max'}{'value'});
                my $lines_formated  = sprintf "%-10s%6s", $value_lines, "lines";
                my $length_formated = sprintf "%-4s%3s", $value_hr_value, $value_hr_type;

                my $print_line = print_formated($key, $length_formated, "$percent%", "($lines_formated)", $extra_info);

                print $fh_stats_txt $print_line;

                if ($stats_type =~ /^(?:ip|proto|ip-ip|port|ip-src|ip-dst|ip-port)$/){
                  print $stats_header_print if $count_stats_print == 0;
                  print $print_line if $count_stats_print++ < 5;
                }
              }
            }
          }


      next;


      #print "\$stats_type: $stats_type\n";
      if ( 0 and $stats_type eq 'ip'){
        print "lines\n";
        my $count_con = 0;
        foreach my $key (reverse sort { $$db_stats{'lines'}{$a} <=> $$db_stats{'lines'}{$b} } keys %{$$db_stats{'lines'}}) {
          last if $count_con++  == $print_stats_lines;

          my $value             = $$db_stats{'lines'}{$key};
          my $value_formated    = $value;
          #while($value_formated =~ s/(\d+)(\d\d\d)/$1 $2/){};

          my $ip_ptr = resolve_ptr($key) || "";
          #print Dumper $$db{'stats'}{'total'} ; exit;
          my $total = $$db_new{'stats'}{$stats_type}{'total'}{'total'}{'length'};

          my $percent   = 0;
          $percent   = int ( ( $value / $total) * 100 ) if $percent;
          #print "\$key: '$key'. \$value: '$value'. \$total: $total\n";
          print print_formated($key, $value_formated, "$percent%", $ip_ptr);
        }
      }


      if ( $stats_type eq 'ip'){
        print "\n\nip\n";
        print "total: ".formatSize($$db_stats{'length'}{'total'})."\n" if $debug;

        my $count_length = 0;
        foreach my $key (reverse sort { $$db_stats{'length'}{$a} <=> $$db_stats{'length'}{$b} } keys %{$$db_stats{'length'}}) {
          next if $key eq 'total';
          last if $count_length++ == $print_stats_lines;

          #print Dumper $$db_stats{'length'}; exit;
          my $value           = $$db_stats{'length'}{$key};
          my $value_hr        = formatSize($value);

          my $value_lines     = $$db_stats{'lines'}{$key};

          my $ip_ptr    = resolve_ptr($key) || "";
          #my $total    = $$db_new{'stats'}{'total'}{'total'}{'total'}{'length'};
          #print Dumper $$db_new{'stats'}{$stats_type}{'total'}; exit;
          #my $total     = $$db_new{'stats'}{$stats_type}{'total'}{'total'}{'lenght'};
          my $total     = $$db_stats{'length'}{'total'};
          my $percent   = 0;
          $percent      = int ( ( $value / $total) * 100 ) if $total;
          #my $peak      = formatSize($$db{'stats'}{$stats_type}{$key}{'calc'}{60}{'peak'}{'length'}{'max'}{'value'});
          #print "$peak\n";

          #printf "%-20s%-20s%-40s\n",$key,$value_hr,$ip_ptr;
          print print_formated($key, $value_hr, "$percent%", $value_lines, $ip_ptr);
        }
      }

      if ( $stats_type eq 'port'){
        print "\n\nport\n";
        print "total: ".formatSize($$db_stats{'length'}{'total'})."\n" if $debug;

        my $count_length = 0;
        foreach my $key (reverse sort { $$db_stats{'length'}{$a} <=> $$db_stats{'length'}{$b} } keys %{$$db_stats{'length'}}) {
          next if $key eq 'total';
          #last if $count_length++ == $print_stats_lines;
          last if $count_length++ == 5;

          my $value     = $$db_stats{'length'}{$key};
          my $value_hr  = formatSize($value);
          my $port_name = get_protocol_name($key) || "";
          #my $total     = $$db_new{'stats'}{'total'}{'total'}{'total'}{'length'};
          #my $total     = $$db_new{'stats'}{$stats_type}{'total'}{'total'}{'lenght'};
          my $total     = $$db_stats{'length'}{'total'};
          my $percent   = 0;
          $percent   = int ( ( $value / $total) * 100 ) if $percent;
          #my $peak      = formatSize($$db{'stats'}{$stats_type}{$key}{'calc'}{60}{'peak'}{'length'}{'max'}{'value'});

          print print_formated($key, $value_hr, "$percent%", $port_name);
        }
      }

      if ( $stats_type eq 'proto'){
        print "\n\nproto\n";
        print "total: ".formatSize($$db_stats{'length'}{'total'})."\n" if $debug;

        my $count_length = 0;
        foreach my $key (reverse sort { $$db_stats{'length'}{$a} <=> $$db_stats{'length'}{$b} } keys %{$$db_stats{'length'}}) {
          next if $key eq 'total';
          last if $count_length++ == $print_stats_lines;

          my $value     = $$db_stats{'length'}{$key};
          my $value_hr  = formatSize($value);
          my $port_name = get_protocol_name($key) || "";
          #my $total     = $$db_new{'stats'}{'total'}{'total'}{'total'}{'length'};
          my $total     = $$db_stats{'length'}{'total'};
          #my $total     = $$db_new{'stats'}{$stats_type}{'total'}{'total'}{'lenght'};
          my $percent   = 0;
          $percent      = int ( ( $value / $total) * 100 ) if $total;
          #my $peak      = formatSize($$db{'stats'}{$stats_type}{$key}{'calc'}{60}{'peak'}{'length'}{'max'}{'value'});

          print print_formated($key, $value_hr, "$percent%", $port_name);
        }
      }

      if ( $stats_type eq 'ip-src-dst'){
        print "\n\nip-src-dst\n";
        print "total: ".formatSize($$db_stats{'length'}{'total'})."\n" if $debug;

        my $count_length = 0;
        foreach my $key (reverse sort { $$db_stats{'length'}{$a} <=> $$db_stats{'length'}{$b} } keys %{$$db_stats{'length'}}) {
          next if $key eq 'total';
          last if $count_length++ == 5;

          my ($ip_src, $ip_dst) = split/ -> /, $key;
          my $ip_src_domain    = resolve_ptr($ip_src);
          my $ip_dst_domain    = resolve_ptr($ip_dst);

          my $value     = $$db_stats{'length'}{$key};
          my $value_hr  = formatSize($value);
          #my $total     = $$db_new{'stats'}{'total'}{'total'}{'total'}{'length'};
          #my $total     = $$db_new{'stats'}{$stats_type}{'total'}{'total'}{'lenght'};
          my $total     = $$db_stats{'length'}{'total'};
          my $percent   = 0;
          $percent      = int ( ( $value / $total) * 100 ) if $total;
          #my $peak      = formatSize($$db{'stats'}{$stats_type}{$key}{'calc'}{60}{'peak'}{'length'}{'max'}{'value'});

          print print_formated($key, $value_hr, "$percent%", "$ip_src_domain -> $ip_dst_domain");
        }
      }



    }

    # stats files START
    close   $fh_stats_txt;
    rename  $file_stats_home,       $file_stats_home_old  or die "Can't rename $file_stats_home -> $file_stats_home_old"    if -f $file_stats_home;
    rename  $file_stats_home_tmp,   $file_stats_home      or die "Can't rename $file_stats_home_tmp -> $file_stats_home"    if -f $file_stats_home_tmp;

    unlink  $file_stats_local if not -s $file_stats_local;
    symlink $file_stats_home,       $file_stats_local     or die "Can't symlink $file_stats_home -> $file_stats_local: $!"  if -f $file_stats_home and not -s $file_stats_local;
    # stats files END

    undef $$db{'stats'};
    %{$$db{'stats'}} = %{$$db_new{'stats'}};
  #print Dumper %db;
}

sub formatSize {
    my $size = shift // 0;
    my $exp = 0;
    my $units;
    $units = [qw(B KB MB GB TB PB)];
    for (@$units) {
        last if $size < 1024;
        $size /= 1024;
        $exp++;
    }
    return wantarray ? ($size, $units->[$exp]) : sprintf("%.2f %s", $size, $units->[$exp]);
}

sub parse_protocol_name {

  foreach my $port_key (%{$$map{'ports'}}){

    if ($port_key =~ /-/){
      print "\$port_key: $port_key\n" if $debug;
      my ($port_from, $port_to) = split/\s{0,}-\s{0,}/, $port_key;

      foreach my $port ($port_from ... $port_to){
        $$map{'ports'}{$port} = $$map{'ports'}{$port_key};
      }
    }
    


  }

}

sub get_protocol_name {
  my $proto_id = shift;


  return $proto{$proto_id} if defined $proto{$proto_id};
  return $$map{'ports'}{$proto_id} if defined $$map{'ports'}{$proto_id};
  ##return "ARP" if $proto_id > 248 and $proto_id < 256;

  #return "unknown";

}

sub get_db {
  my $input_file = shift // $file_db;

  my $db_ref = {};

  if (-f $input_file) {
    print "Found $input_file. Opening\n" if $debug;
    $db_ref = retrieve $input_file ;
  }
  else {
    print "Could not find $input_file. Returning\n" if $debug;
  }

  return $db_ref;
}


sub save_db {
  my $db_ref  = shift;
  my $input_file = shift || $file_db;

  store $db_ref, $input_file;
}

sub resolve_ptr {
  my $ip = shift;

  return "" if defined $$db{'dns'}{'IN'}{'PTR'}{$ip} and $$db{'dns'}{'IN'}{'PTR'}{$ip} eq 'NXDOMAIN';
  return $$db{'dns'}{'IN'}{'PTR'}{$ip} if defined $$db{'dns'}{'IN'}{'PTR'}{$ip};
  #print "DNS resolve IN PTR $ip\n";

  #print "$ip PTR\n";

  my $packet = $resolver->search( $ip, 'PTR' );
  my $rcode =  $resolver->errorstring();
  
  if (not defined $rcode){
    print "DNS PTR $ip. \$rcode is not defined. Something is wrong" if $debug;
    $$db{'dns'}{'IN'}{'PTR'}{$ip} = "ERROR";
    return $$db{'dns'}{'IN'}{'PTR'}{$ip};
  }


  # timeout 
  if (defined $rcode and $rcode eq 'query timed out'){
    $$db{'dns'}{'queue'}{'IN'}{'PTR'}{$ip}  = "";
    return "";
  }

  # catch all none NOERROR
  if (defined $rcode and $rcode ne 'NOERROR'){
    $$db{'dns'}{'IN'}{'PTR'}{$ip} = $rcode;
    return $$db{'dns'}{'IN'}{'PTR'}{$ip};
  }

  if (defined $rcode and $rcode =~ /NXDOMAIN|REFUSED/){
    $$db{'dns'}{'IN'}{'PTR'}{$ip} = $rcode;
    return $$db{'dns'}{'IN'}{'PTR'}{$ip};
  }

  if (not defined $packet){
    # print "DNS PTR $ip. \$packet is not defined. Something is wrong" if $debug;
    $$db{'dns'}{'IN'}{'PTR'}{$ip} = "NXDOMAIN";
    return $$db{'dns'}{'IN'}{'PTR'}{$ip};
  }


  # add to queue
  # $$db{'dns'}{'queue'}{'IN'}{'PTR'}{$ip}  = "";

  #if (defined $rcode){
  #  $$db{'dns'}{'IN'}{'PTR'}{$ip} = $rcode;
  #  return $rcode;
  #}



  my @answer = $packet->answer;

  # query ok, but not data in answer
  if (not @answer){
    $$db{'dns'}{'IN'}{'PTR'}{$ip} = "NXDOMAIN";
    return $$db{'dns'}{'IN'}{'PTR'}{$ip};
  }

  #144.185.144.10.in-addr.arpa.    174     IN      PTR     SM46104.elev.bergenkom.no.
  my ($arpa, $ttl, $class, $type, $domain) = split/\s{1,}/, $answer[0]->string();

  # return if not defined $domain;
  if (not defined $domain){
    $$db{'dns'}{'IN'}{'PTR'}{$ip} = "NXDOMAIN";
    return $$db{'dns'}{'IN'}{'PTR'}{$ip};
  }

  $domain =~ s/\.$//;
  $domain =~ s/[\(\)]//g;

  $$db{'dns'}{'IN'}{'PTR'}{$ip} = $domain;
  #print "DNS resolve $ip: $domain\n";
  return $domain;
}

sub init_resolver {

  my $resolver = Net::DNS::Resolver->new(
    # nameservers     => [@dns_servers],
    debug           => 0,
    recurse         => 1,           #Get or set the recursion flag. If true, this will direct nameservers to perform a recursive query. The default is true.
    defnames        => 0,           #Get or set the defnames flag. If true, calls to query() will append the default domain to resolve names that are not fully qualified. The default is true.
    dnsrch          => 0,           #Get or set the dnsrch flag. If true, calls to search() will apply the search list to resolve names that are not fully qualified. The default is true.
    persistent_tcp  => 0,           #Get or set the persistent TCP setting. If true, Net::DNS will keep a TCP socket open for each host:port to which it connects.
    persistent_udp  => 0,           #Get or set the persistent UDP setting. If true, a Net::DNS resolver will use the same UDP socket for all queries within each address family.
    retrans         => 3,           #Get or set the retransmission interval The default is 5 seconds.
    #igntc           => 0,           #Get or set the igntc flag. If true, truncated packets will be ignored. If false, the query will be retried using TCP. The default is false.
    retry           => 3,           #Get or set the number of times to try the query. The default is 4.
    #srcaddr        => "10.0.0.1",  #Sets the source address from which queries are sent. Convenient for forcing queries from a specific interface on a multi-homed host. The default is to use any local address.
    #srcport        => "5353",      #Sets the port from which queries are sent. The default is 0, meaning any port.
    tcp_timeout     => 2,         #Get or set the TCP timeout in seconds. The default is 120 seconds (2 minutes).
    udp_timeout     => 2,          #Get or set the bgsend() UDP timeout in seconds. The default is 30 seconds.
    searchlist      => "",
  );

  return $resolver;
}

sub save_db_all {
  my $fork = shift // 0;

  print "save_db_all\n" if $debug;
  fork && return if $fork;
  $$db{'fork'} = 1 if $fork;

  save_db($$db{'dns'}, $file_db_dns);
  #delete $$db{'dns'};
  save_db($db, $file_db);
  exit if $fork;
}


sub resolve_dns {
  my $fork = shift // 0;

  fork && return if $fork;
  $$db{'fork'} = 1 if $fork;
  print "fork: save_db_all\n" if $fork == 0 and $debug;
  print "master: found DNS queue from last run\n" if $debug;

  foreach my $query (keys %{$$db{'dns'}{'queue'}{'IN'}{'PTR'}}){

    next if defined $$db{'dns'}{'IN'}{'PTR'}{$query} and $$db{'dns'}{'IN'}{'PTR'}{$query};

    # print "resolve from dns queue $query\n" if $debug;
    resolve_ptr($query);
  }

  foreach my $query (keys %{$$db{'stats'}{'ip'}}){
    next if defined $$db{'dns'}{'IN'}{'PTR'}{$query} and $$db{'dns'}{'IN'}{'PTR'}{$query};

    # print "resolve from IP list $query\n" if $debug;
    resolve_ptr($query);
  }

  save_db($$db{'dns'}, "$file_db_dns-queue.db");


  exit if $fork;
  delete $$db{'dns'}{'queue'};

}

sub print_formated {

  my $length = 10;
  foreach my $data (@_){
    my $data_length = length $data;
    $length = $data_length if $data_length > $length;
  }

  #print "length $length\n";
  return sprintf "%-40s%-20s%-6s%-20s%-20s\n", @_;

}

sub resolve_clean {

  foreach my $query (keys %{$$db{'dns'}{'IN'}{'PTR'}}){

    my $answer = $$db{'dns'}{'IN'}{'PTR'}{$query};

    ##delete $$db{'dns'}{'IN'}{'PTR'}{$query} if length $answer == 0;
    # delete $$db{'dns'}{'IN'}{'PTR'}{$query} if $answer eq 'NXDOMAIN';
    delete $$db{'dns'}{'IN'}{'PTR'}{$query} if $answer eq 'ERROR';
    delete $$db{'dns'}{'IN'}{'PTR'}{$query} if $answer eq 'SERVFAIL';
  }
  

}

