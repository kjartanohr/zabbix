#!/usr/bin/perl

BEGIN {
  if ($ARGV[0] eq "--zabbix-test-run"){
    print "ZABBIX TEST OK";
    exit;
  }
}

use strict;
use warnings;
use Net::DNS;
use Net::DNS::Nameserver;
use Net::DNS::Packet;
#use Tie::Cache;
#use Tie::Hash;
#
#TOOD
#Add lookup counter in cache for every entry
#Add trim for cache
#stats, min, hour, day, week, total
#
#Dette scriptet klarer 700~ spørringer pr sekund med ca 50-60% CPU bruk. Flaskehalsen tror jeg ligger i neste DNS server
#
#Lage rules i config
#En rule kan f.eks source IP/peer, regex på query, regex på answer
# Inne i en rule
#   config settes som man ønsker
#   f.eks
#     slå av cache for en peer ip
#     endre TTL for en peer ip
#
#     redirecte en spørring til f.eks internt.domene til en annen DNS server
#     redirecte en spørring fra en peer til en annen dns server
#
#     kjøre en substitute/rewrite på question/answer
#
#     lage en eval hvor man kan kjøre ønsket perl kode
#       sende en mail om noen prøver å resolve en adresse
#
#     slå på debug om peer ip
#       perfekt til debug hvis man vil teste å resolve noe som feiler
#
#     endre cache fil til en annen hvis peer ip
#
#     endre cache fil om query er sendt til gitt dns server
#
#     slå på log på gitt query / answer
#
#     sette statisk høyere TTL for query for lokale domener
#
#
#
$SIG{INT} = \&ctrl_c;

#Not implmentet yet
my $config_file             = "$0.config";  #Config file
my $config_file_check_every = 10;           #Minutes. Check config file every N minutes

my $cache_save_to_file      = 1;            #Save cache to file
my $cache_read_from_file    = 1;            #Check cache before resolve
my $cache_min_ttl           = 0;            #Set the min TTL for cached data
my $cache_max_ttl           = 0;            #Set the max TTL for cached data

my $cache_servfail          = 0;            #Cache server failure. This solves the problem with slow DNS servers that time out on SERVFAIL answers.
my $cache_servfail_ttl      = 1*60;         #Minutes. SERVFAIL TTL. Don't set the TTL to high
my $cache_servfail_hit      = 10;           #Cache if same query has failed N times

my $cache_timeout           = 0;            #Cache server timeout. This solves the problem with slow DNS servers that time out on specific queries
my $cache_timeout_ttl       = 1*60;         #Minutes. TTL. Don't set the TTL to high
my $cache_timeout_hit       = 10;           #Cache if same query has failed N times

my $cache_nxdomain          = 1;            #Cache "this domain does not exist". This solves the problem with slow DNS servers that time out on nxdomain answers.
my $cache_nxdomain_ttl      = 1*60;         #Minutes. NXDOMAIN TTL. Try to keep this high if possible

my $cache_refused           = 1;            #cache "I will not answer this query. This solves the problem with slow dns servers that time out on refused answers.
my $cache_refused_ttl       = 1*60;         #minutes. refused ttl. try to keep this high if possible

my $resolve_from_cache_only = 0;            #Don't forward queries to DNS server. Use this you only want to use the cache file as DNS resolver source

my @cache_peer_exclude      = qw( 10.99.0.30 ); #Exclude peer from cache
my @cache_peer_include      = qw();         #Exclude peer from cache

my @cache_exclude           = qw( google.com ); #Exclude IP/domain listet in this array
my @cache_include           = qw();         #Only cache IP/domain listet in this array

my $cache_max_count         = 10_000_000;   #Max cached results in cache. N cached entries
my $cache_max_memory        = 1000;         #Max memory usage for cache in hash. N Megabytes

my $cache_stale_use         = 1;            #Serve stale cache data if server gives error message where there is better data in cache
my $cache_stale_nxdomain    = 1;            #Serve stale cache data if server gives NXDOMAIN on a domain where cache has a result
my $cache_stale_servfail    = 1;            #Serve stale cache data if server gives SERVFAIL on a domain where cache has a result
my $cache_stale_refused     = 1;            #Serve stale cache data if server gives REFUSED on a domain where cache has a result
my $cache_stale_timeout     = 1;            #Serve stale cache data if server gives time out on a domain where cache has a result

my $cache_owrite_nxdomain   = 0;            #Overwrite valid cache data with NXDOMAIN
my $cache_owrite_servfail   = 0;            #Overwrite valid cache data with SERVFAIL
my $cache_owrite_refused    = 0;            #Overwrite valid cache data with REFUSED
my $cache_owrite_timeout    = 0;            #Overwrite valid cache data with time out

my $cache_n_owrite_nxdomain = 0;            #Overwrite none valid cache data with NXDOMAIN
my $cache_n_owrite_servfail = 0;            #Overwrite none valid cache data with SERVFAIL
my $cache_n_owrite_refused  = 0;            #Overwrite none valid cache data with REFUSED
my $cache_n_owrite_timeout  = 0;            #Overwrite none valid cache data with time out

my $file_cache              = "$0.cache";
my $file_cache_max_size     = 1024;         #File size in MB. Not implementet yet
my $file_cache_save_every   = 120;            #Minute
my $file_cache_saved_last   = time;
my $file_cache_del_full     = 7;            #Delete data from cache if the data has not been used for 7 days

my $cache_updater_start     = 1;            #This will start a background task that updates, removes and check the cache data
my $cache_u_start_ttl       = 1;            #Update the cache for data where the TTL is outdated
my $cache_u_ttl_every       = 60;           #Minutes. How often to check the date in cache
my $cache_u_ttl_del         = 0;            #Remove old TTL

my $cache_u_start_error     = 1;            #Update the cache for data where the result is an error. NXDOMAIN, REFUSED, SERVFAIL, Time out,
my $cache_u_thread          = 10;            #How many updater threads will run in paralell
my $cache_u_error_every     = 1;            #Hours. How often to check the data in cache
my $cache_u_error_del       = 1;            #Remove old error data
my $cache_u_error_del_days  = 7;            #Days. Remove data older than N days

my $cache_u_del_added_days  = 30;           #Days. Remove if data added in cahce is older than N days
my $cache_u_del_read_days   = 30;           #Days. Remove if data last read in cahce is older than N days

my $debug                   = 0;            #Enable debug to default STDOUT
my $warning                 = 1;            #Enable warnings/error
my $debug_to_log_file       = 0;            #Send debug data to log

my $log_servfail            = 0;            #Log error message SERVFAIL
my $log_servfail_file       = "$0.log.servfail.log";
my $log_servfail_max_size   = 10;           #MB. Log file max size

my $log_refused             = 0;            #Log error message REFUSED
my $log_refused_file        = "$0.log.refused.log";
my $log_refused_max_size    = 10;           #MB. Log file max size

my $log_timeout             = 0;            #Log error message timeout
my $log_timeout_file        = "$0.log.timeout.log";
my $log_timeout_max_size    = 10;           #MB. Log file max size

my $log_all_error           = 0;            #Log error messages. Includes Warning
my $log_all_error_file      = "$0.log.errors.log";
my $log_all_error_max_size  = 10;           #MB. Log file max size

my $file_debug              = "$0.log";     #Log file for debug

my $server_listen_ip        = "10.0.3.183"; #Listen to 0.0.0.0 or local IP
my $server_listen_port      = "1053";         #TCP and UDP listen port
my $server_counter          = 0;
my @dns_servers             = qw( 8.8.8.8 8.8.4.4 1.1.1.1 );  #DNS servers to query

my $resolver_recurse          = 1;            #Get or set the recursion flag. If true, this will direct nameservers to perform a recursive query. The default is true.
my $resolver_defnames         = 1;            #Get or set the defnames flag. If true, calls to query() will append the default domain to resolve names that are not fully qualified. The default is true.
my $resolver_dnsrch           = 1;            #Get or set the dnsrch flag. If true, calls to search() will apply the search list to resolve names that are not fully qualified. The default is true.
my $resolver_persistent_tcp   = "";           #Get or set the persistent TCP setting. If true, Net::DNS will keep a TCP socket open for each host:port to which it conn^^ect^^s.
my $resolver_persistent_udp   = 1;            #Get or set the persistent UDP setting. If true, a Net::DNS resolver will use the same UDP socket ^^for al^^l queries within each address family.
my $resolver_retrans          = 1;            #Get or set the retransmission interval The default is 5 seconds.
my $resolver_igntc            = 1;            #Get or set the igntc flag. If true, truncated packets will be ignored. If false, the query will be retried using TCP. The default is false.
my $resolver_retry            = 2;            #Get or set the number of times to try the query. The default is 4.
my $resolver_srcaddr          = "10.0.0.1";   #Sets the source address from which queries are sent. Convenient for forcing queries from a specific interface on a multi-homed host. The default is to use any local address.
my $resolver_srcport          = "5353";       #Sets the port from which queries are sent. The default is 0, meaning any port.
my $resolver_tcp_timeout      = 120;          #Get or set the TCP timeout in seconds. The default is 120 seconds (2 minutes).
my $resolver_udp_timeout      = 2;            #Get or set the bgsend() UDP timeout in seconds. The default is 30 seconds.

my $stats_print_every       = 10;   #Seconds
my $stats_print_peer        = 1;
my $file_stats              = "$0.stats";

my %stats;
$stats{'_time'}             = time;
$stats{'_time_query_count'} = time;
$stats{'_query_count'}      = 0;
get_stats();


my $resolver = Net::DNS::Resolver->new(
  nameservers     => [@dns_servers],
  debug           => $debug,
  recurse         => 1,           #Get or set the recursion flag. If true, this will direct nameservers to perform a recursive query. The default is true.
  #defnames        => 0,           #Get or set the defnames flag. If true, calls to query() will append the default domain to resolve names that are not fully qualified. The default is true.
  #dnsrch          => 0,           #Get or set the dnsrch flag. If true, calls to search() will apply the search list to resolve names that are not fully qualified. The default is true.
  #persistent_tcp  => 1,           #Get or set the persistent TCP setting. If true, Net::DNS will keep a TCP socket open for each host:port to which it connects.
  #persistent_udp => 1,           #Get or set the persistent UDP setting. If true, a Net::DNS resolver will use the same UDP socket for all queries within each address family.
  retrans         => 1,           #Get or set the retransmission interval The default is 5 seconds.
  igntc           => 1,           #Get or set the igntc flag. If true, truncated packets will be ignored. If false, the query will be retried using TCP. The default is false.
  retry           => 2,           #Get or set the number of times to try the query. The default is 4.
  #srcaddr        => "10.0.0.1",  #Sets the source address from which queries are sent. Convenient for forcing queries from a specific interface on a multi-homed host. The default is to use any local address.
  #srcport        => "5353",      #Sets the port from which queries are sent. The default is 0, meaning any port.
  #tcp_timeout     => 120,           #Get or set the TCP timeout in seconds. The default is 120 seconds (2 minutes).
  udp_timeout     => 2,           #Get or set the bgsend() UDP timeout in seconds. The default is 30 seconds.
);

#Redirect output to log
if ($debug_to_log_file) {
  open STDOUT, ">>", $file_debug or die "Can't write to $file_debug: $!\n";
  open STDERR, ">>", $file_debug or die "Can't write to $file_debug: $!\n";
}

#package My::Cache;
#my @ISA = qw(Tie::Cache);
my %cache;

#tie %cache, 'My::Cache', {
#  Debug    => $debug,
#  MaxCount => $cache_max_count,
#  MaxBytes => $cache_max_memory,
#};

read_cache_from_file();

my $ns = Net::DNS::Nameserver->new(
    LocalPort    => $server_listen_port,
    ReplyHandler => \&reply_handler,
    Verbose      => $debug,
    LocalAddr    => $server_listen_ip,
    ) || die "couldn't create nameserver object\n";


$ns->main_loop;


sub reply_handler {
  my ( $qname, $qclass, $qtype, $peerhost, $query, $conn ) = @_;
  my ( $rcode, @ans_r, @ans_c, @auth, @add );

  $stats{"query type $qtype"} +=1;

  $stats{"peer $peerhost"} +=1;


  $server_counter++;

  #print stats
  if (time - $stats{'_time'} > $stats_print_every) {
    $stats{'_time'} = time;
    print_stats();
  }

  #Calculate query pr min
  if (time - $stats{'_time_query_count'} > 60) {
    $stats{'query pr min'}      = $stats{'_query_count'};

    $stats{'_time_query_count'} = time;
    $stats{'_query_count'}      = 0;
    print_stats();
  }
  $stats{'_query_count'} +=1;


  my $cache_hit = 0;
  my $cache_old = 0;

  my $resolve_hit = 0;
  my @resolve_answer;

  my @cache_result;
  my @resolve_result;

  print "$server_counter. Received query from $peerhost to " . $conn->{sockhost} . "\n" if $debug;
  $query->print if $debug;

  print "$server_counter From DNS client $qname, $qtype, $qclass\n" if $debug;

  #Check cache
  print "$server_counter Will check local cache\n" if $debug;
  foreach (get_cache($qname, $qtype, $qclass)) {

    if (/NXDOMAIN|REFUSED|SERVFAIL/) {
      my ($c_error,$c_time) = split/\s{0,},\s{0,}/;

      my $headermask = {};
      my $optionmask = {};
      $stats{'cache hit'} +=1;
      print "$c_error found in cache $qname, $qtype, $qclass\n" if $debug;
      return ($c_error, \@ans_r, \@auth, \@add, $headermask, $optionmask );
    }

    my ($c_qname, $c_ttl, $c_qclass, $c_qtype, $c_rdata,$timestamp) = split/\s{0,},\s{0,}/;
    push @cache_result, "$qname, $qtype, $qclass, $c_qname, $c_ttl, $c_qclass, $c_qtype, $c_rdata, $timestamp\n" if $debug or $warning;

    my $rr = Net::DNS::RR->new("$c_qname $c_ttl $c_qclass $c_qtype $c_rdata");

    if ((time - $timestamp) > $c_ttl) {
      print "$server_counter Cache is older than TTL\n" if $debug;
      $stats{'cache old TTL'} +=1;
      $cache_old = 1;
    }
    else {
      print "$server_counter Cache is still valid: $_\n" if $debug;
      $cache_old = 0 unless $cache_old;
    }

    $cache_hit = 1;
    $stats{'cache hit'} +=1;

    push @ans_c, $rr;
    $rcode = "NOERROR";
  }


  if ($cache_hit == 0 or $cache_old == 1) {
    print "$server_counter Resolving domain name\n" if $debug;

    #Not found in cache, will ask DNS server
    foreach (resolve($qname, $qtype, $qclass)) {
      my ($r_qname, $r_ttl, $r_qclass, $r_qtype, $r_rdata) = split/\s{0,},\s{0,}/;
      my $time = time;

      push @resolve_answer, "$qname, $qtype, $qclass, $r_qname, $r_ttl, $r_qclass, $r_qtype, $r_rdata, $time";

      my $data = "qname $qname, qtype $qtype, qclass $qclass, r_qname $r_qname, r_ttl $r_ttl, r_qclass $r_qclass, r_qtype $r_qtype, r_rdata $r_rdata, time $time";
      #push @resolve_answer, $data;
      print "$server_counter data: $data\n" if $debug;

      my $rr = Net::DNS::RR->new("$r_qname $r_ttl $r_qclass $r_qtype $r_rdata");
      $resolve_hit = 1;
      $stats{'cache miss'} +=1;

      push @ans_r, $rr;
      $rcode = "NOERROR";
    }
  }

  # mark the answer as authoritative (by setting the 'aa' flag)
  #my $headermask = {};
  my $headermask = {aa => 1, ra => 1};

  # specify EDNS options  { option => value }
  my $optionmask = {};

  unless ($cache_hit or $resolve_hit) {
    #warn "$server_counter Could not resolve $qname, $qtype, $qclass\n" if $warning;
    #print "$server_counter Could not resolve $qname, $qtype, $qclass\n" if $debug;
    $rcode = "SERVFAIL";
    $stats{'resolve failed'} +=1;
    return ( $rcode, \@ans_r, \@auth, \@add, $headermask, $optionmask );
  }

  $stats{'resolve ok'} +=1;

  if ($resolve_hit) {
    add_cache(@resolve_answer);

    print "$server_counter Using answer from resolve\n" if $debug;
    return ( $rcode, \@ans_r, \@auth, \@add, $headermask, $optionmask );
  }
  elsif ($cache_hit && $cache_old == 0) {
    print "$server_counter Using answer from cache\n" if $debug;
    return ( $rcode, \@ans_c, \@auth, \@add, $headermask, $optionmask );
  }
  elsif ($cache_hit && $cache_old == 1) {
    $stats{'cache stale data returned'} +=1;
    print "$server_counter Using stale answer from cache: \n@cache_result\n" if $debug;
    warn "$server_counter Using stale answer from cache: \n@cache_result\n" if $warning;
    return ( $rcode, \@ans_c, \@auth, \@add, $headermask, $optionmask );
  }

}


sub resolve {
  my $qname  = shift;
  my $qtype  = shift;
  my $qclass = shift;
  my @return;

  my $packet = $resolver->send($qname, $qtype, $qclass);
  my $error = $resolver->errorstring;
  $stats{"error $error"} +=1;

  if ($error eq "query timed out") {
    warn "$server_counter query timed out $qname, $qtype, $qclass\n" if $warning;
    return;
  }

  #if ($error eq "SERVFAIL") {
  #  warn "$server_counter query failed $error $qname, $qtype, $qclass\n" if $warning;
  #  return;
  #}

  if ($error !~ /NOERROR/) {
    warn "$server_counter query error: $error. $qname, $qtype, $qclass\n" if $warning;
    #print "$server_counter query failed: $error. $qname, $qtype, $qclass\n" if $debug;
  }

  if ($error eq "NXDOMAIN" or $error eq "REFUSED" or $error eq "SERVFAIL") {
    my $time = time;
    print "resolve got $error as answer. add_cache($qname, $qtype, $qclass, $error, $time);\n" if $debug;
    $stats{"cache add $error"} +=1;
    add_cache("$qname, $qtype, $qclass, $error, $time","cache_errormsg");
  }



  print "$server_counter Resolved from ".$resolver->replyfrom."\n" if $debug;

  print "$server_counter reply data: $packet->string\n" if $debug;

  foreach my $answer ($packet->answer) {
    #kfo.com.        2714    IN      A       184.168.131.241
    my ($r_qname, $r_ttl, $r_qclass, $r_qtype, @r_rdata) = split /\s{1}/, $answer->string;

    print "$server_counter DNS resolve answer: qname: $r_qname\nttl: $r_ttl\nqclass: $r_qclass\nqtype: $r_qtype\nrdata: @r_rdata\n" if $debug;

    my $r_rdata = join " ", @r_rdata;
    my $result = "$r_qname, $r_ttl, $r_qclass, $r_qtype, $r_rdata";
    push @return, $result;
  }

  return @return;
}

sub read {
   my($self, $key) = @_;
   print "cache miss for $key, read() data\n";
   rand() * $key;
}

sub write {
   my($self, $key, $value) = @_;
   print "flushing [$key, $value] from cache, write() data\n";
}

sub get_cache {
  my $qname  = shift || return;
  my $qtype  = shift || return;
  my $qclass = shift || return;
  my @return;

  my $query = "$qname,$qtype,$qclass";

  print "$server_counter Check local cache for query; $query\n" if $debug;

  my $cache = $cache{$query};
  return unless $cache;

  print "$server_counter Local cache found: $cache\n" if $debug;

  #my ($r_qname, $r_ttl, $r_qclass, $r_qtype, $r_rdata) = split/,/, $cache;
  foreach my $answer (split/;;;/, $cache) {
    push @return, $answer;
  }
  return @return;
}

sub add_cache {
  my @data = @_;
  my $query;
  my $answer;

  print "$server_counter Adding to local cache @_\n" if $debug;

  if (defined $data[1] and $data[1] eq "cache_errormsg") {
    print "Found $data[2] in answer\n" if $debug;
    my ($qname, $qtype, $qclass, $error, $time) = split /\s{0,},\s{0,}/, $data[0];
    $query   = "$qname,$qtype,$qclass";
    $answer  = "$error,$time";

    @data = ();
  }

  foreach (@data) {
    print "$server_counter add to cache foreach loop. Adding answer $_\n" if $debug;

    @_ = split /\s{0,},\s{0,}/;

    my $qname     = shift || return;
    my $qtype     = shift || return;
    my $qclass    = shift || return;

    my $c_qname   = shift || return;
    my $c_ttl     = shift || return;
    my $c_qclass  = shift || return;
    my $c_qtype   = shift || return;
    my $c_rdata   = shift || return;
    my $c_time    = shift || return;


    $query   = "$qname,$qtype,$qclass" unless $query;
    $answer  .= "$c_qname,$c_ttl,$c_qclass,$c_qtype,$c_rdata,$c_time;;;";
 }

  print "$server_counter Adding to local cache for all answers: query: \"$query\". Answer \"$answer\"\n" if $debug;

  $stats{"cache add total"} +=1;
  $cache{$query} = $answer;
  save_cache_to_file();
}

sub save_cache_to_file {
  print "$server_counter Checking how long since last cache save\n" if $debug;

  if ((time - $file_cache_saved_last < ($file_cache_save_every*60) ) ){
    return;
  }
  $file_cache_saved_last = time;

  print "$server_counter It's time for saving cache to file\n" if $debug;
  #fork && return;

  if (-f $file_cache) {
    rename $file_cache,"$file_cache.old" or die "Can't rename $file_cache to $file_cache.old";
  }

  open my $fh_w_cache, ">", $file_cache or die "Can't write to $file_cache: $!";

  foreach my $query (keys %cache) {
    my $answer = $cache{$query};
    print $fh_w_cache "$query;;;;;$answer\n";

  }
  close $fh_w_cache;
}

sub read_cache_from_file {
  unless (-f $file_cache) {
    print "$server_counter Could not find cache file\n" if $debug;
    return;
  }

  open my $fh_r_cache, "<", $file_cache or die "Can't write to $file_cache: $!";

  while (<$fh_r_cache>) {
    chomp;
    my ($query,$answer) = split/;;;;;/;

    $cache{$query} = $answer;

  }
  close $fh_r_cache;
}

sub print_stats {

  open my $fh_w_stats, ">", $file_stats or die "Can't write to $file_stats: $!\n";

  print "Stats\n\n";

  #Peer
  if ($stats_print_peer) {
    foreach (sort keys %stats) {
      my $name = $_;
      my $count = $stats{$_};

      next unless /^peer/;

      printf "%-30s : %s", $name, $count;
      print "\n";
    }
    print "\n\n";
  }

  foreach (sort keys %stats) {
    my $name = $_;
    my $count = $stats{$_};
    next if $name =~ /^_/;

    print $fh_w_stats "$name,$count\n";

    next if /^peer/;

    print sprintf "%-30s : %s", $name, $count;
    print "\n";

  }
  print "\n\nStats END\n\n";
  close $fh_w_stats;

}


sub get_stats {

  unless (-f $file_stats) {
    print "Could not find $file_stats file\n" if $debug;
    return;
  }

  open my $fh_r_stats, "<", $file_stats or die "Can't read $file_stats: $!\n";

  foreach (<$fh_r_stats>) {
    chomp;
    my ($name,$count) = split/,/;
    $stats{$name} = $count;
  }
  close $fh_r_stats;

}


sub ctrl_c {

  print "Exiting\n";
  print_stats();
  save_cache_to_file();
  exit;


}

