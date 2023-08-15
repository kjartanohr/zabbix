#!/usr/bin/perl

# 2023-04-30 07:52:38

BEGIN {
  if ($ARGV[0] eq "--zabbix-test-run"){
    print "ZABBIX TEST OK";
    exit;
  }
}

# curl zabbix.kjartanohr.no/zabbix/repo/default/scripts/install_perl_modules.pl | perl

use warnings;
use strict;

# Install cpm if missing
run("cpanm App::cpm");
run("cpan App::cpm");

my $os          = get_os();
my $timeout     = 10*60;
my $modules     = get_modules();
my %perl_bin    = get_perl_path();
my @modules_install;
my ($file_cpm, $file_cpanm, $file_cpan) = get_cpan_path();
my $cpm_opts    = "--local-lib-contained=\$HOME/perl5 --verbose --man-pages --retry --show-progress --with-all";
my $dir_tmp     = "$ENV{'HOME'}/.tmp/pl-cpan-installer"; system "mkdir -p $dir_tmp" unless -d $dir_tmp;
my $debug       = 1;
my $dry_run     = 0;
my %config;
my $tmp         = {};
my $shell_env   = 'PERL_LOCAL_LIB_ROOT="$HOME/perl5" ; PERL_MM_OPT="INSTALL_BASE=$HOME/perl5"';
my $cmd_timeout   = "timeout 10m ";

($file_cpm)      = `whereis -b cpm` =~ /: (.*)/   if not $file_cpm;
($file_cpanm)    = `whereis -b cpanm` =~ /: (.*)/ if not $file_cpanm;
($file_cpan)     = `whereis -b cpan` =~ /: (.*)/  if not $file_cpan;

# temp greier
if (not $file_cpm){
  foreach my $dir ("$ENV{'HOME'}/perl5/bin"){
    my $file = "$dir/cpm";
    next if not -f $file;
    $file_cpm = $file;
  }
}
if (not $file_cpanm){
  foreach my $dir ("$ENV{'HOME'}/perl5/bin"){
    my $file = "$dir/cpanm";
    next if not -f $file;
    $file_cpanm = $file;
  }
}

print join(", ", %perl_bin)."\n";
print "file_cpm: $file_cpm\n" if $debug;
print "file_cpan: $file_cpan\n" if $debug;

# if debian/buntu
# check for the command make. If not apt-get -y install make

push @modules_install, split/\n/, $$modules{'cpan'}{'base-1'};
#push @modules_install, split/\n/, $$modules{'cpan'}{'all};
#push @modules_install, split/\n/, $$modules{'apt-get'}{'base-1'};

foreach my $module (@modules_install){

    my $file_perl = "perl";
    chomp $module;
    next unless $module;
    next if $module =~ /^#/;
    $module =~ s/#.*//;

    print "$file_perl $module\n" if $debug;
    if (is_module_installed($module, $file_perl)){print "Module is installed $module\n"; next};

    # CPM
    if ($file_cpm){
      install_cpm($module, $file_perl);
      if (is_module_installed($module, $file_perl)){print "Module is installed $module\n"; next};
    }

    # cpanm
    if ($file_cpanm){
      install_cpanm($module, $file_perl);
      if (is_module_installed($module, $file_perl)){print "Module is installed $module\n"; next};
    }

    # cpan
    if ($file_cpan){
      install_cpan($module, $file_perl);
      if (is_module_installed($module, $file_perl)){print "Module is installed $module\n"; next};
    }
}

foreach my $file_perl (keys %perl_bin){
  chomp $file_perl;
  foreach my $module (@modules_install){
    chomp $module;
    next unless $module;
    next if $module =~ /^#/;
    $module =~ s/#.*//;

    print "$file_perl $module\n" if $debug;
    if (is_module_installed($module, $file_perl)){print "Module is installed $module\n"; next};

    # CPM
    if ($file_cpm){
      install_cpm($module, $file_perl);
      if (is_module_installed($module, $file_perl)){print "Module is installed $module\n"; next};
    }

    # cpanm
    if ($file_cpanm){
      install_cpanm($module, $file_perl);
      if (is_module_installed($module, $file_perl)){print "Module is installed $module\n"; next};
    }

    # cpan
    if ($file_cpan){
      install_cpan($module, $file_perl);
      if (is_module_installed($module, $file_perl)){print "Module is installed $module\n"; next};
    }
  }
}


sub install_cpm {
  my $name    = shift // die "Missing input data 'name'";
  my $perl    = shift // die "Missing input data 'perl'";

  my $cmd = "$shell_env; $cmd_timeout $perl $file_cpm install $cpm_opts $name";
  my $id  = $cmd;
  $id =~ s/\//-/g;
  $id =~ s/-{2,}/-/g;

  return 1 if installed($id, 'get');

  #$cmd = "timeout $timeout $cmd";
  print "$cmd\n";
  #system $cmd unless $dry_run;
  print run($cmd);

  return 1;

}


sub install_cpanm {
  my $name    = shift // die "Missing input data 'name'";
  my $perl    = shift // die "Missing input data 'perl'";

  my $cmd = "$shell_env; $cmd_timeout $perl $file_cpanm --local-lib=~/perl5 $name";
  my $id  = $cmd;
  $id =~ s/\//-/g;
  $id =~ s/-{2,}/-/g;

  return 1 if installed($id, 'get');

  #$cmd = "timeout $timeout $cmd";
  print "$cmd\n";
  #system $cmd unless $dry_run;
  print run($cmd);

  return 1;

}


sub install_cpan {
  my $name    = shift // die "Missing input data 'name'";
  my $perl    = shift // die "Missing input data 'perl'";

  #my $cmd  = "yes | $perl $file_cpan $name";
  my $cmd     = "$shell_env; $cmd_timeout $perl $file_cpan $name";
  my $cmd_2   = "$shell_env; $cmd_timeout $perl -MCPAN -Mlocal::lib -e 'CPAN::install($name)'";
  my $id  = $cmd;
  $id =~ s/\//-/g;
  $id =~ s/-{2,}/-/g;

  return 1 if installed($id, 'get');

  #$cmd = "timeout $timeout $cmd";
  print "$cmd\n";
  print run($cmd);

  print "$cmd_2\n";
  print run($cmd_2);

  return 1;

}


sub get_cpan_path {

  #chomp(my $file_cpm   	= (split/ /, `whereis cpm`)[1]);
  my $file_cpm   	  = whereis("cpm");
  my $file_cpanm   	= whereis("cpanm");
  my $file_cpan   	= whereis("cpan");

  print "\$file_cpm: $file_cpm\n" if $debug;

  return ($file_cpm, $file_cpanm, $file_cpan);
}


sub get_perl_path {

  my %perl_bin;
  $perl_bin{'perl'} = '';
  #$perl_bin{'/usr/bin/perl'} = '';
  #$perl_bin{'env perl'} = '';

  #foreach my $file (`find /usr/ -name "perl.exe" -type f 2>&1 | perl -ne 'chomp; next unless -B $_; print "$_\n"'`){
  #  next unless $_;
  #  $perl_bin{$file} = '';
  #}
  
  #foreach my $file (`find /usr/ -name "perl" -type f 2>&1 | perl -ne 'chomp; next unless -B $_; print "$_\n"'`){
  #  next unless $_;
  #  $perl_bin{$file} = '';
  #}

  foreach my $file (glob("/usr/bin/perl*")) {
    next unless $file =~ /perl(?:\d|$)/;
    $perl_bin{$file} = '';
  }

  foreach (split/\s{1,}/, `whereis -b perl`){
    chomp;
    next unless `$_ -v 2>&1` =~ /Larry/;
    $perl_bin{$_} = '';
  }

  foreach (keys %perl_bin){
    delete $perl_bin{$_} if not `perl -e 'use warnings; print 123'` =~ /^123/;
  }

  return %perl_bin;

}

sub is_module_installed {
  my $name    = shift // die "Missing input data 'name'";
  my $perl    = shift // die "Missing input data 'perl'";
  my $return  = 1;

  my $cmd_perl_use      = "$perl -e 'use $name;'";
  my $id  = $cmd_perl_use;
  $id =~ s/\//-/g;
  $id =~ s/-{2,}/-/g;

  return 1 if installed("installed-$id", 'get');

  my $cmd_perl_use_out  = `$cmd_perl_use 2>&1`; 

  if ($cmd_perl_use_out =~ /failed--compilation/){
    $return = 0;
  }

  installed("installed-$id", 'set') if $return == 1;

  return $return;
}


sub installed {
  my $name = shift;
  $name =~ s/\W/_/g;
  my $type = shift // die "Missing input data type";

  my $filename = "$dir_tmp/cpan-$name";

  if ($type eq 'get'){
    return 1 if     -f $filename;
    return 0 if not -f $filename;
  }
  elsif ($type eq 'set'){
    open my $fh_w, ">", $filename or die "Can't write to $filename: $!";
    print $fh_w time;
    close $fh_w;

    return 1;
  }
}

sub search_for_use {
  #foreach (readline $fh_r){chomp; ($_) = /^use (.*)/; next unless $_; s/ .*//; s/;$//; print "$_\n"; eval{import $_}; next if $@; foreach my $file_perl (glob("/usr/bin/perl*")){next unless $file_perl =~ /perl(?:\d|$)/; my $cmd = "$file_perl $file_cpanm $_"; print "$cmd\n"; system $cmd; system "yes | $file_perl $file_cpan $_";}}
}

sub run {
  my $sub_name = (caller(0))[3];
  debug("start", $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 1;
  debug("input: ".Dumper(@_), $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 3;

  my $cmd                       = shift || die "Did not get any CMD";
  my %input                     = @_;
  #my $cmd_out = "Output from command: $cmd\n";
  my $cmd_out;

  $input{'pause'}             ||= 0;
  $input{'ask'}               ||= 0;
  $input{'timeout'}           ||= 60;
  $input{'stop_if_found'}     ||= "";
  $input{'stop_if_not_found'} ||= "";
  $input{'stop_msg'}          ||= "";
  #$input{'print'}             ||= $debug;
  $input{'print'}             //= 0;
  $input{'retry'}             ||= 3;
  $input{'dry_run'}           ||= 0;
  $input{'desc'}              //= "unknown description";
  $input{'cache'}             //= 0;


  #print $clear if $input{'clear'};

  if ($input{'ask'}) {
    debug("$sub_name. \$input{'ask'} is true", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
    my $msg = "$input{'ask'}\n";

    ask(
      $msg,
      answer  => "Y",
      print   => 1,
    );
  }


  if ($input{'dry_run'} == 0) {
    debug("$sub_name. $input{'desc'}. \$input{'dry_run'} is false", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

    my $cmd_cache = cache(
      'type'  => 'get',
      'name'  => $cmd,
    );
    if (defined $cmd_cache){
      debug("\$cmd_cache is defined: $cmd_cache", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
      return $cmd_cache;
    }



    eval {
      local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
      alarm $input{'timeout'};

      debug("$sub_name. $input{'desc'}. Running command: $cmd", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
      open my $cmd_fh, "-|", "$cmd 2>&1" or die "Can't run $cmd: $!";
      while (<$cmd_fh>) {
        print if $input{'print'};
        $cmd_out .= $_;
      }
      #$cmd_out = `$cmd 2>&1`;

      alarm 0;
    };
  }

  if ($input{'print'}) {
    debug(((caller(0))[3])." \$input{'print'} is true\n");
    debug("$sub_name. $input{'desc'}. Running command: $cmd", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  }

  if ($input{'stop_if_found'}) {
    debug(((caller(0))[3])." \$input{'stop_if_found'} is true\n");
    if ($cmd_out =~ /$input{'stop_if_found'}/) {
      my $msg;

      if ($input{'stop_msg'}) {
        print "Stop trigger word found in output: \"$input{'stop_if_found'}\"\n$input{'stop_msg'}\n";
      }
      else {
        print "Found $input{'stop_if_found'} in command output. Exiting\n";
      }
      exit;
    }
  }

  # Add to cache
  cache(
    'type'  => 'set',
    'name'  => $cmd,
    'value' => "$cmd_out",
  );


  pause() if $input{'pause'};

  debug($cmd_out);



  return $cmd_out;
}

=pod

my $cmd_cache = cache(
  'type'  => 'get',
  'name'  => "$cmd",
);

cache(
  'type'  => 'set',
  'name'  => "$cmd",
  'value' => "$cmd_out",
);

=cut
sub cache {
  my $sub_name = (caller(0))[3];
  debug("start", $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 1;
  debug("input: ".Dumper(@_), $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 3;

  #sub header start
  my %input   = @_;
  debug("$sub_name. $input{'desc'}", $sub_name, \[caller(0)]) if $config{'log'}{'desc'}{'enabled'} and $config{'log'}{'desc'}{'level'} > 0 and defined $input{'desc'};

  my $return;

  #default values
  $input{'exit-if-fatal'}         //= 0;
  $input{'return-if-fatal'}       //= 1;
  $input{'validate-return-data'}  //= 1;
  $input{'type'}                  //= 'get';
  $input{'value'}                 //= '';
  #$input{'xxx'} = "yyy" unless defined $input{'xxx'};

  #validate input data start
  if ($config{"val"}{'sub'}{'in'}){
    my @input_type = qw( name );
    foreach my $input_type (@input_type) {

      unless (defined $input{$input_type} and length $input{$input_type} > 0) {
        debug("missing input data for '$input_type'", "fatal", \[caller(0)] ) if $config{'log'}{'fatal'}{'enabled'} and $config{'log'}{'fatal'}{'level'} > 3;
        return 0;
      }
    }
  }
  #validate input data start

  #sub header end

  #sub main code start

  if ($input{'type'} eq 'get'){

    $return  = $$tmp{'cache'}{$input{'name'}};
    if (defined $return){
      debug("Found data in cache: '$return'", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
    }
    else {
      debug("data NOT found in cache", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
      return;
    }

  }
  elsif ($input{'type'} eq 'set'){

    $$tmp{'cache'}{$input{'name'}} = $input{'value'};
    debug("New data set in cache:\n$$tmp{'cache'}{$input{'name'}}", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

  }

  #sub main code END

  #sub end section START

  #Validate return data
  if ($config{"val"}{'sub'}{'out'}){

    if ($input{'validate-return-data'} and defined $return and length $return == 0) {
      debug("Return data is not defined. Input data: ".Dumper(%input), "fatal", \[caller(0)] )  if $config{'log'}{'fatal'}{'enabled'} and $config{'log'}{'fatal'}{'level'} > 3;
      run_exit() if $input{'exit-if-fatal'};
      return;
    }

  }


  debug("end",  $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 1;
  return $return;

  #sub end section END

}
#sub template END

sub debug {
  #return unless $debug;
  @_ = "No error message given" unless @_;
  $_[1] //= 'debug';

  if ($config{'log'}{$_[1]}{'enabled'}){
    print join ", ", @_;
    print "\n";
  }

  #print "debug: ".join ", ", @_;
  #print "\n";
}

sub whereis {
  my @files =  @_ or die "Need a file for whereis";

  foreach my $file (@files) {
    debug("Looking for file $file");

    # D:\MobaXterm\MobaXterm_Pro_Portable_21.4\home\bin>whereis cpanm
    # cpanm: /usr/local/bin/cpanm /drives/d/perl/Strawberry/perl/bin/cpanm /drives/d/perl/Strawberry/perl/bin/cpanm.bat

    # kfo@Lenovo-P53:~$ whereis cpanm
    # cpanm: /usr/bin/cpanm /mnt/d/perl/Strawberry/perl/bin/cpanm /mnt/d/perl/Strawberry/perl/bin/cpanm.bat /usr/share/man/man1/cpanm.1p.gz
    # kfo@Lenovo-P53:~$
  

    my $out = run("whereis $file");
    chomp $out;

    my ($path) = $out =~ /: (.*)/;

    if (defined $path) {
      debug("Found file $file. $path");

      if (-f $path) {
        debug("path exists $file. $path");
        return $path;
      }
      else {
        debug("path does not exist. $file. $path");
      }
    }
  }

  return if $os eq "win";

  foreach my $file (@files) {
    debug("Looking for file $file");

    foreach my $find_file (`find /usr -name $file`) {
      next unless $find_file;
      chomp $find_file;
      debug("Found file $file. $find_file");
      return $find_file;

    }

  }


  return;
}

sub get_os {

  my $return = "unknown";
  $return = "win"     if defined $ENV{'OS'}     and $ENV{'OS'} eq "Windows_NT";
  $return = "linux"   if defined $ENV{'OSTYPE'} and $ENV{'OSTYPE'} =~ /linux/i;

  return $return;
}



sub get_modules {

my $modules = {};


### CPAN base 1 START ###
$$modules{'cpan'}{'base-1'} = <<'EEE';

# CPAN install
App::cpm
App::cpanminus

# cpan libs
Text::Levenshtein
Text::Levenshtein::XS
Text::Levenshtein::Damerau::XS
Text::Levenshtein::Damerau::PP

# Shell
Shell::GetEnv

# Config/INI files
Config::IniFiles

# Warning: Cannot install async, don't know what it is.
# async
Mojo::IOLoop::Server

# JSON
JSON
JSON::XS
JSON::PP
Mojo::JSON

# encoding
Text::Unidecode

# forks / threads
forks
Forks::Queue
forks::shared

# div moduler i bruk
Time::HiRes

# Lagring / databaser
CHI
Mojo::SQLite

# cache
Mojo::Cache

# Dato 
Date::Parse

# perl 
diagnostics

# HTTP
Mojo::UserAgent

# checksum
Digest::SHA1

# MIME::Base64
# https://perldoc.perl.org/MIME::Base64
MIME::Base64
Crypt::Digest::SHA256

# scripting

# Expect
# https://metacpan.org/release/RGIERSIG/Expect-1.15/view/Expect.pod
Expect

# pl-nc-talk
Mojo::UserAgent
Mojo::JSON
Data::Dumper
Crypt::Digest::SHA256

# MQTT
Beekeeper::MQTT

CHI

Data::Dump
Data::Dumper
Data::Validate::Domain
Data::Validate::IP
Date::Parse
diagnostics
Digest::MD5
EV
Fcntl
File::Tail
Filesys::Df
forks
Forks::Queue
forks::shared
forks
Hash::Diff
IO::Select
IO::Socket::Socks
IO::Socket::SSL
JSON
JSON::Tiny
JSON::XS
List::Util
Log::Log4perl
Math::Round
Mojo
Mojo::Base
Mojo::Date
Mojo::IOLoop::Tail
Mojo::JSON
Mojo::JSON::MaybeXS
Mojo::Log
Mojo::Server::Daemon
Mojo::Server::Hypnotoad
Mojo::UserAgent
Mojo::Util
Mojolicious::Lite
Net::DNS
Net::DNS::Nameserver
Net::DNS::Native
Net::DNS::Packet
Net::IP
Parallel::ForkManager
Perl::LanguageServer
Redis
Storable
String::Similarity
Time::HiRes
Forks::Queue
threads::shared
threads

# date
Date::Manip
Date::Manip::Lang::norwegian
Time::ParseDate
EEE

$$modules{'cpan'}{'critic'} = <<'EEE';
Perl::Critic
Perl::Critic::More
Perl::Critic::Bangs
Perl::Critic::Lax
Perl::Critic::StricterSubs
Perl::Critic::Swift
Perl::Critic::Tics

EEE

$$modules{'cpan'}{'base-2'} = <<'EEE';
Beekeeper::MQTT;
CHI
Crypt::Digest::SHA256
Data::Dump
Data::Dumper
Data::Validate::Domain
Data::Validate::IP
Date::Parse
diagnostics
Digest::MD5
EV
Fcntl
File::Tail
Filesys::Df
forks
Forks::Queue
forks::shared
forks
Hash::Diff
IO::Select;
IO::Socket::Socks
IO::Socket::SSL
JSON
JSON::Tiny
JSON::XS
List::Util
Log::Log4perl
Math::Round
Mojo
Mojo::Base
Mojo::Date
Mojo::IOLoop::Tail
Mojo::JSON
Mojo::JSON::MaybeXS
Mojo::Log
Mojo::Server::Daemon
Mojo::Server::Hypnotoad
Mojo::UserAgent
Mojo::Util
Mojolicious::Lite
Net::DNS
Net::DNS::Nameserver
Net::DNS::Native
Net::DNS::Packet
Net::IP
Parallel::ForkManager
Perl::LanguageServer
Redis
Storable
String::Similarity
Time::HiRes
Forks::Queue
threads::shared
threads

EEE

### CPAN base 1 END ###
$$modules{'apt-get'}{'base-1'} = <<'EEE';

### ubuntu base 1 START ###
# JSON

libjson-any-perl
libjson-maybexs-perl
libjson-multivalueordered-perl
libjson-perl
libjson-pp-perl
libjson-rpc-perl
libjson-xs-perl
libtest-cpan-meta-json-perl
libtest-deep-json-perl
libtest-json-perl

# cache/storage

libchi-perl
libchi-driver-memcached-perl
libchi-driver-redis-perl
libchi-memoize-perl
Redis

# MOJO

libio-async-loop-mojo-perl
libminion-perl
libmojo-ioloop-readwriteprocess-perl
libmojo-jwt-perl
libmojo-pg-perl
libmojo-rabbitmq-client-perl
libmojo-server-fastcgi-perl
libmojo-sqlite-perl
libmojolicious-perl
libmojolicious-plugin-*

# redis

libanyevent-redis-perl
libchi-driver-redis-perl
libredis-fast-perl
libredis-perl

# dns

libdns-zoneparse-perl
libnet-bonjour-perl
libnet-dns-async-perl
libnet-dns-cloudflare-ddns-perl
libnet-dns-lite-perl
libnet-dns-perl
libnet-dns-sec-perl
libnet-ldns-perl
libnet-nslookup-perl
libzonemaster-perl
libnet-dns-fingerprint-perl

# exptect

libexpect-perl
libexpect-simple-perl
libnet-scp-expect-perl
libtest-expect-perl

EEE
### ubuntu base 1 END ###

# div fra random script
$$modules{'cpan'}{'all'} = <<'EEE';
CGI
CGI::Simple
CHI::Stats
Carp
Compress::Zlib
Config
Config::Any
Config::IniFiles
Crypt::GPG
Cwd
DBI
DB_File
Data::Dumper
Data::YAML::Writer
Date::Manip
Date::Parse
DateTime
Digest::SHA1
Email::MIME
Email::Simple
Email::Valid
Encode
Errno
Expect
ExtUtils::MakeMaker
Fcntl
File::Copy
File::Copy
File::Find
File::HomeDir
File::Slurp
File::Spec
File::Tail
File::Type
File::stat
Filesys::Df
FindBin
Forks::Queue
Getopt::Long
Glib::Object::Subclass
Gtk2
Gtk2::SimpleList
HTML::Entities
HTML::Parser
HTTP::Cookies
HTTP::Daemon::SSL
HTTP::Proxy
HTTP::Request
HTTP::Status
IO::File
IO::Handle
IO::Pty
IO::Select
IO::Socket
IO::Socket::INET
IPC::Open3
IPC::SysV
Image::ExifTool
Image::Magick
JSON
JSON::MaybeXS
JSON::XS
KFO::lib
LWP::Parallel::UserAgent
LWP::Simple
LWP::UserAgent
Lib
MIME::Base64
MIME::Lite
MP3::Info
MP3::Tag
MP3::Tag::ID3v2
MP4::Info
Mail::IMAPTalk
Mail::Sendmail
Math::Complex
Math::Round("nearest")
Memoize
Mojo::Cache
Mojo::Date
Mojo::Headers
Mojo::IOLoop
Mojo::IOLoop::Server
Mojo::JSON::MaybeXS
Mojo::SQLite
Mojo::Server::Hypnotoad
Mojo::UserAgent
Mojolicious::Lite
NDBM_File
Net::DNS
Net::DNS::Nameserver
Net::DNS::Packet
Net::DNS::Resolver
Net::DNS::ZoneFile
Net::EasyTCP
Net::IMAP::Simple
Net::IMAP::Simple::SSL
Net::IP
Net::LDAP
Net::MQTT::Simple
Net::Ping
Net::SMTP
Net::SMTP::Server
Net::SMTP::Server::Client
Net::SMTP::Server::Relay
Net::Syslogd
Net::Twitter
OD::Prometheus::Metric
OmniDisco::Prometheus
P1
P2
P3
POSIX
Parallel::ForkManager
Path::Tiny
Perl::Critic
Plack::App::Directory
Pod::Functions
Pod::Usage
Redis
Sniffer::HTTP
Socket
Socket
SomeMod
Spreadsheet::Read
Statistics::Descriptive
Storable
Sys::Hostname
Term::ANSIColor
Test2::V0
Test::More
Text::Aspell
Text::Wrap
Text::vCard
Thread::Queue
Tie::Hash::LRU
Tie::IxHash
Time::HiRes
Time::Piece
Time::Stopwatch
Tk
Tk::Clipboard
Tk::CursorControl
Tk::DropSite
URI::Escape
User::pwent
WWW::Mechanize
WWW::Spyder
Wx
XML::RSS
XML::RSS::Parser
XML::RSS::Parser::Lite
XML::Simple
constant
diagnostics
eval:
forks
forks::shared
integer
locale
sigtrap
strict
strict
them.
threads
threads::shared
utf8


# critic
Config::Tiny
PPI::Token::Whitespace
Module::Pluggable
PPI::Document::File
List::SomeUtils
File::Which
PPI::Document
Perl::Tidy
String::Format
Pod::Spell
PPI
IO::String
Exception::Class
Pod::Plain
Text
Readonly
Pod::Parser
PPIx::Utilities::Statement
B::Keywords
PPIx::Regexp::Util
PPIx::Regexp
PPIx::Utilities::Node
PPI::Node
PPIx::QuoteLike
PPI::Token::Quote::Single
Pod::Select

Perl::Critic

# perl tidy
Perl::Tidy
App::perlimports

Log::Syslog::Fast 
Parallel::ForkManager
Net::Syslogd
Net::DNS::Resolver
Number::Bytes::Human
Perl::LanguageServer

# TV 2 - LDAP - IA
Logfile::Rotate;
IO::Socket::SSL
WWW::Mechanize
XML::Simple #Cisco ISE bruker XML
Net::LDAP #LDAP lookup/resolve for SAM account name




EEE

  return $modules;
}


