#!/usr/bin/perl5.32.0
#bin
BEGIN{
 require "/usr/share/zabbix/repo/files/auto/lib.pm";
  #require "./lib.pm"
}

#TODO

#Changes


use warnings;
use strict;

my $process_name_org          = $0;
my $process_name              = "vpn_create_user_cert";
$0                            = "perl $process_name VER 100";

#Print the data immediately. Don't wait for full buffer
$|++;

$SIG{CHLD}                    = "IGNORE";
#$SIG{INT}                     = \&save_and_exit('msg') => 'Signal INIT';

#Zabbix health check
zabbix_check($ARGV[0]);

our $dir_tmp                  = "/tmp/zabbix/$process_name";
our $file_debug               = "$dir_tmp/debug.log";
my  $file_exit                = "$dir_tmp/stop";

our $debug                    = 1;                                                  #This needs to be 0 when running in production
our $info                     = 1;
our $warning                  = 1;
our $error                    = 1;
our $fatal                    = 1;
my  $fork                     = 1;

#Get default config
our %config                   = get_config();

#Init config
$config{'init'}   = {
  'is_cp_gw'                  => 0,
  'is_cp_mgmt'                => 0,
  'cpu_count'                 => 2,
};

$config{'file'}{'vsenv'}      = "/etc/profile.d/vsenv.sh";

#Hash for long time storage. Saved to file
my $db                        = get_json_file_to_hash('file' => $config{'file'}{'database'});

#Hash for short time storage. Not saved to file
my %tmp                       = ();


#Exit if stop file found
#save_and_exit('msg' => "Stop file found $config{'file'}{'stop'}. Exit") if -f $config{'file'}{'stop'};

#Exit if this is not a gw
#save_and_exit('msg' => "is_gw() returned 0. This is not a GW. Exit") if $config{'init'}{'is_cp_gw'} and is_gw();

#Exit if this is not a mgmt
save_and_exit('msg' => "is_mgmt() returned 0. This is not a MGMT. Exit") if $config{'init'}{'is_cp_mgmt'} and is_mgmt();

#Exit if CPU count is low
#save_and_exit('msg' => "CPU count os too low. Exit") if $config{'init'}{'cpu_min_count'} and cpu_count() < $config{'init'}{'cpu_min_count'};

#Create tmp/data directory
create_dir($dir_tmp) unless -d $dir_tmp;

#Trunk log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);

#debug("", "debug", \[caller(0)] ) if $debug;
#debug("", "info", \[caller(0)] )  if $debug;
#debug("", "error", \[caller(0)] ) if $error;
#debug("", "fatal", \[caller(0)] );


#Parse input data
my %argv = parse_command_line(@ARGV);

#Print help if no input is given
#help('msg' => "help started from command line", 'exit'  => 1) if defined $argv{'help'};

#Activate debug if debug found in command line options
$debug = $argv{'debug'} if defined $argv{'debug'};

#init JSON
#my $json = init_json();

my $help = qq#$process_name_org ' --username="test-user" --password="vpn123" --comment="Cert comment" --file="cert.p12" '#;

if (not defined $argv{'username'}){
  my @users = get_users();
  print "Local mgmt users: ".join ", ", @users;

  foreach my $user (@users) {
    my $help_user = $help;
    $help_user =~ s/test-user/$user/g;
    print "$help_user\n";

  }
  print "\n\nMissing username in input.\n\n$help\n";
  exit;
}

#$argv{'username'}    || die "Need a username. $help\n";
$argv{'password'}    ||= "vpn123"                                           unless defined $argv{'password'};
$argv{'comment'}     ||= "Check Point VPN user certificate created by $0"   unless defined $argv{'comment'};
$argv{'file'}        ||= "$argv{'username'}-vpn-user-cert.p12"              unless defined $argv{'file'};
$argv{'type'}        ||= "USER"                                             unless defined $argv{'type'};

#End of standard header

my $path =  get_ou_path();
#print join ", ", get_users();

#my $file_cert = 'test-vpn-user-cert.p12';
my $file_cert = create_vpn_user_cert(
  'username'  => $argv{'username'},
  'password'  => $argv{'password'},
  'file'      => $argv{'file'},
  'comment'   => $argv{'comment'},
  'type'      => $argv{'type'},
  'path'      => $path,
);

validate_cert(
  'username'  => $argv{'username'},
  'password'  => $argv{'password'},
  'file'      => $file_cert,
);

system "ls -lh $file_cert*";

=pod

cpca_client search .

cpca_client lscert
Subject = CN=kfo,OU=users,O=management..ivfvvt
Status = Expired   Kind = IKE   Serial = 99639   DP = 1
Not_Before: Mon Aug  4 21:06:09 2014   Not_After: Thu Aug  4 21:06:09 2016


cpstat ca

Product Name:                     CP Internal CA
Up and Running:                   1
Total Number of certificates:     142
Total Number of users:            50
Total Number of SIC certificates: 80
Total Number of IKE certificates: 12
Last CRL Distribution Point:      11

[Expert@management:0]# cpstat ca -f all

Product Name:                     CP Internal CA
Build Number:                     995000034
Up and Running:                   1
Total Number of certificates:     142
Number of Pending certificates:   0
Number of Valid certificates:     30
Number of Renewed certificates:   0
Number of Revoked certificates:   111
Number of Expired certificates:   1
Total Number of users:            50
Number of Internal users:         45
Number of LDAP users:             5
Total Number of SIC certificates: 80
Total Number of IKE certificates: 12
Last CRL Distribution Point:      11



$FWDIR/conf/users.C
:type (user)
:name (kfo)

[Expert@management:0]# grep ":allowed_suffix_for_internal_users (" objects_5_0.C
        :allowed_suffix_for_internal_users ("OU=users,O=management..ivfvvt")
[Expert@management:0]#


cpca_client -d create_cert -n "CN=test-fra-cpca_client" -f cert-vpn-test.p12 -w test123 -k USER -c "Nytt VPN cert"

=cut

sub get_users {
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  my %input   = @_;
  my %users;
  my $name;

  my $file_users = `source $config{'file'}{'vsenv'} &>/dev/null ; echo \$FWDIR/conf/users.C`;
  chomp $file_users;

  open my $fh_r, "<", $file_users or die "Can't read $file_users: $!";

  my $name_search = 0;
  foreach my $line (readline $fh_r) {

    #:name (kfo)
    if ($name_search and $line =~ /:name \(/){
      debug("Found user name: $line", "debug", \[caller(0)]) if $debug > 1;
      ($name) =      $line =~ /:name \((.*?)\)/;
      $users{$name} = 1;
      $name_search  = 0;
    }

    #:type (user)
    if ($line =~ /:type \(user\)/){
      debug("Found type user: $line", "debug", \[caller(0)]) if $debug > 1;
      $name_search = 1;
    }


  }

  return keys %users;

}

#[Expert@management:0]# grep ":allowed_suffix_for_internal_users (" objects_5_0.C
#        :allowed_suffix_for_internal_users ("OU=users,O=management..ivfvvt")
#[Expert@management:0]#
sub get_ou_path {
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  my %input   = @_;
  my $path;

  my $file = `source $config{'file'}{'vsenv'} &>/dev/null ; echo \$FWDIR/conf/objects_5_0.C`;

  unless (defined $file) {
    debug("Missing file objects_5_0.C", "fatal", \[caller(0)] );
    exit;
  }

  my $out = `cat $file`;
  debug("objects_5_0.C: $out", "debug", \[caller(0)]) if $debug > 4;

  #:allowed_suffix_for_internal_users ("OU=users,O=management..ivfvvt")
  ($path) = $out =~ /:allowed_suffix_for_internal_users \("(.*?)"\)/;

  unless (defined $path) {
    debug("Could not find allowed_suffix_for_internal_users in objects_5_0.C", "fatal", \[caller(0)] );
    exit;
  }
  debug("OU path: $path", "debug", \[caller(0)]) if $debug > 1;


  return $path;

}

#cpca_client -d create_cert -n "CN=test-fra-cpca_client" -f cert-vpn-test.p12 -w test123 -k USER -c "Nytt VPN cert"

#create_vpn_user_cert(
#  'username' => 'test',
#);
sub create_vpn_user_cert {
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  my %input   = @_;

  unless (defined $input{'username'}) {
    debug("Missing input data 'username'", "fatal", \[caller(0)] );
    exit;
  }

  unless (defined $input{'path'}) {
    debug("Missing input data 'path'", "fatal", \[caller(0)] );
    exit;
  }

  $input{'comment'}     = "Check Point VPN user certificate created by $0"  unless defined $input{'comment'};
  $input{'password'}    = "vpn123"                                          unless defined $input{'password'};
  $input{'file'}        = "$input{'username'}-vpn-user-cert.p12"            unless defined $input{'file'};
  $input{'type'}        = "USER"                                            unless defined $input{'type'};

  $input{'path'} =~ s/CN=//;

  #cpca_client -d create_cert -n "CN=test-fra-cpca_client" -f cert-vpn-test.p12 -w test123 -k USER -c "Nytt VPN cert"
  my $cmd = qq#cpca_client -d create_cert -n "CN=$input{'username'},$input{'path'}" -f "$input{'file'}" -w "$input{'password'}" -k "$input{'type'}" -c "$input{'comment'}"#;
  debug("CMD: $cmd", "debug", \[caller(0)]) if $debug > 1;

  my $out = `$cmd 2>&1`;
  debug("Out: $out", "debug", \[caller(0)]) if $debug > 1;

  #Certificate was created successfully
  if ($out =~ /Certificate was created successfully/){
    debug("Certificate was created successfully: $input{'file'}", "info", \[caller(0)]) if $info;
    return $input{'file'};
  }
  else {
    debug("Creating certificate failed", "fatal", \[caller(0)] );
    exit;
  }

  return $input{'file'};
}



sub validate_cert {
  debug("start", "debug", \[caller(0)]) if $debug > 1;
  debug("Input: ".Dumper(@_), "debug", \[caller(0)]) if $debug > 3;

  my %input   = @_;

  unless (defined $input{'username'}) {
    debug("Missing input data 'username'", "fatal", \[caller(0)] );
    exit;
  }

  unless (defined $input{'password'}) {
    debug("Missing input data 'password'", "fatal", \[caller(0)] );
    exit;
  }

  unless (defined $input{'file'}) {
    debug("Missing input data 'file'", "fatal", \[caller(0)] );
    exit;
  }

  unless (-f $input{'file'}) {
    debug("Missing cert file: $input{'file'}", "fatal", \[caller(0)]);
    exit;
  }

  my $file_cpopenssl        = '$CPDIR/bin/cpopenssl';
  my $file_cpoenssl_full   = `source $config{'file'}{'vsenv'} &>/dev/null ; echo $file_cpopenssl`;
  chomp $file_cpoenssl_full;
  debug("cpopenssl: $file_cpoenssl_full", "debug", \[caller(0)]) if $debug > 1;

  unless (defined $file_cpoenssl_full) {
    debug("Missing file $file_cpoenssl_full", "fatal", \[caller(0)] );
    exit;
  }

  unless (-f $file_cpoenssl_full) {
    debug("Could not find cpopenssl: $file_cpoenssl_full", "debug", \[caller(0)]) if $debug > 1;
    exit;
  }

  #Validate cpopenssl
  my $cmd_help = "$file_cpoenssl_full help";
  debug("CMD: $cmd_help", "debug", \[caller(0)]) if $debug > 1;

  my $cmd_help_out = `$cmd_help 2>&1`;
  debug("OUT: $cmd_help_out", "debug", \[caller(0)]) if $debug > 4;

  if ($cmd_help_out =~ /Standard commands/){
    debug("cpopenssl looks OK", "info", \[caller(0)]) if $info;
  }
  else {
    debug("cpopenssl does not look ok. Failed. Out: $cmd_help_out", "fatal", \[caller(0)] );
    exit;
  }

  my $username  = $input{'username'};
  my $password  = $input{'password'};
  my $file_cert = $input{'file'};

  my %openssl_cmd = (

    'validate-p12' => {
      'cmd'             => "'$file_cpoenssl_full' pkcs12 -info -passin 'pass:$password' -passout 'pass:$password' -in '$file_cert'",
      'ok_string'       => 'BEGIN CERTIFICATE',
      'ok_msg_success'  => 'P12 validation was a success',
      'ok_msg_failed'   => 'P12 validation failed. Something is wrong with the certificate file',
    },

    'convert-p12-pem' => {
      #openssl pkcs12 -in keyStore.pfx -out keyStore.pem -nodes
      'cmd'             => "'$file_cpoenssl_full' pkcs12 -passin 'pass:$password' -passout 'pass:$password' -in '$file_cert' -out '$file_cert-private-public.pem' -nodes",
      'ok_msg_success'  => 'P12 to PEM converting was a success',
      'ok_msg_failed'   => 'P12 to PEM converting failed',
      'ok_eval'         => "return -f '$file_cert-private-public.pem'",
    },

    'validate-pem' => {
      #openssl x509 -in acs.cdroutertest.com.pem -text
      'cmd'             => "'$file_cpoenssl_full' x509 -text -in '$file_cert-private-public.pem'",
      'ok_string'       => 'BEGIN CERTIFICATE',
      'ok_msg_success'  => 'PEM validation was a success',
      'ok_msg_failed'   => 'PEM validation failed. Something is wrong with the certificate file',
    },

    #Private keys
    'convert-p12-private' => {
      #openssl pkcs12 -in keyStore.pfx -out keyStore.pem -nodes
      'cmd'             => "'$file_cpoenssl_full' pkcs12 -passin 'pass:$password' -passout 'pass:$password' -in '$file_cert' -out '$file_cert-private.pem' -nocerts",
      'ok_msg_success'  => 'P12 to PEM private converting was a success',
      'ok_msg_failed'   => 'P12 to PEM private converting failed',
      'ok_eval'         => "return -f '$file_cert-private.pem'",
    },

    #Public keys. Not private keys
    'convert-p12-public' => {
      #openssl pkcs12 -in keyStore.pfx -out keyStore.pem -nodes
      'cmd'             => "'$file_cpoenssl_full' pkcs12 -passin 'pass:$password' -passout 'pass:$password' -in '$file_cert' -out '$file_cert-public.pem' -nokeys",
      'ok_msg_success'  => 'P12 to PEM public converting was a success',
      'ok_msg_failed'   => 'P12 to PEM public converting failed',
      'ok_eval'         => "return -f '$file_cert-public.pem'",
    },

  );

  my @openssl_type = qw( validate-p12 convert-p12-pem validate-pem convert-p12-private convert-p12-public );
  OPENSSL_TYPE:
  foreach my $openssl_type (@openssl_type) {

    unless (defined $openssl_cmd{$openssl_type}) {
      debug("Unknown openssl cmd. Could not find $openssl_type in %openssl_cmd. next", "error", \[caller(0)] );
      next OPENSSL_TYPE;
    }


    my $cmd             = $openssl_cmd{$openssl_type}{'cmd'};
    my $ok_string       = $openssl_cmd{$openssl_type}{'ok_string'};
    my $ok_msg_success  = $openssl_cmd{$openssl_type}{'ok_msg_success'}   || "Success";
    my $ok_msg_failed   = $openssl_cmd{$openssl_type}{'ok_msg_failed'}    || "Failed";
    my $ok_eval         = $openssl_cmd{$openssl_type}{'ok_eval'};
    my $string_failed   = $openssl_cmd{$openssl_type}{'failed'}           || "Failed";

    #debug("CMD: '$cmd'. String ok: '$string_ok'. String failed: '$string_failed'", "debug", \[caller(0)]) if $debug > 1;

    debug("CMD: $cmd", "debug", \[caller(0)]) if $debug > 1;

    my $cmd_out = `$cmd 2>&1`;
    debug("OUT: $cmd_out\n", "debug", \[caller(0)]) if $debug > 4;

    if (defined $ok_string) {
      if ($cmd_out =~ /$ok_string/){
        debug("$ok_msg_success", "info", \[caller(0)]) if $info;
      }
      else {
        debug("$ok_msg_failed CMD: '$cmd'.\nOut: '$cmd_out'", "fatal", \[caller(0)] );
        exit;
      }
    }

    if (defined $ok_eval){
      debug("ok eval: '$ok_eval'", "debug", \[caller(0)]) if $debug > 1;

      if (eval $ok_eval) {
        debug("$ok_msg_success", "info", \[caller(0)]) if $info;
      }
      else {
        debug("$ok_msg_failed CMD: '$cmd'.\nOut: '$cmd_out'", "fatal", \[caller(0)] );
        exit;
      }
    }
  }


=pod

Generate a new private key and Certificate Signing Request
openssl req -out CSR.csr -new -newkey rsa:2048 -nodes -keyout privateKey.key

Generate a certificate signing request (CSR) for an existing private key
openssl req -out CSR.csr -key privateKey.key -new

Generate a self-signed certificate
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout privateKey.key -out certificate.crt

Generate a certificate signing request based on an existing certificate
openssl x509 -x509toreq -in certificate.crt -out CSR.csr -signkey privateKey.key

Remove a passphrase from a private key
openssl rsa -in privateKey.pem -out newPrivateKey.pem

Check a Certificate Signing Request (CSR)
openssl req -text -noout -verify -in CSR.csr

You can display the contents of a PEM formatted certificate under Linux, using openssl:
openssl x509 -in acs.cdroutertest.com.pem -text

Likewise, you can display the contents of a DER formatted certificate using this command:
openssl x509 -in MYCERT.der -inform der -text

Check a private key
openssl rsa -in privateKey.key -check

Check a certificate
openssl x509 -in certificate.crt -text -noout

Check a PKCS#12 file (.pfx or .p12)
openssl pkcs12 -info -in keyStore.p12

Check an SSL connection. All the certificates (including Intermediates) should be displayed
openssl s_client -connect www.paypal.com:443

Converting Using OpenSSL
These commands allow you to convert certificates and keys to different formats to make them compatible with specific types of servers or software. For example, you can convert a normal PEM file that would work with Apache to a PFX (PKCS#12) file and use it with Tomcat or IIS. Use our SSL Converter to convert certificates without messing with OpenSSL.

Convert a DER file (.crt .cer .der) to PEM
openssl x509 -inform der -in certificate.cer -out certificate.pem

Convert a PEM file to DER
openssl x509 -outform der -in certificate.pem -out certificate.der

Convert a PKCS#12 file (.pfx .p12) containing a private key and certificates to PEM
openssl pkcs12 -in keyStore.pfx -out keyStore.pem -nodes
You can add -nocerts to only output the private key or add -nokeys to only output the certificates.

Convert a PEM certificate file and a private key to PKCS#12 (.pfx .p12)
openssl pkcs12 -export -out certificate.pfx -inkey privateKey.key -in certificate.crt -certfile CACert.crt


PEM Format
The PEM format is the most common format that Certificate Authorities issue certificates in. PEM certificates usually have extensions such as .pem, .crt, .cer, and .key. They are Base64 encoded ASCII files and contain "-----BEGIN CERTIFICATE-----" and "-----END CERTIFICATE-----" statements. Server certificates, intermediate certificates, and private keys can all be put into the PEM format.

Apache and other similar servers use PEM format certificates. Several PEM certificates, and even the private key, can be included in one file, one below the other, but most platforms, such as Apache, expect the certificates and private key to be in separate files.

DER Format
The DER format is simply a binary form of a certificate instead of the ASCII PEM format. It sometimes has a file extension of .der but it often has a file extension of .cer so the only way to tell the difference between a DER .cer file and a PEM .cer file is to open it in a text editor and look for the BEGIN/END statements. All types of certificates and private keys can be encoded in DER format. DER is typically used with Java platforms. The SSL Converter can only convert certificates to DER format. If you need to convert a private key to DER, please use the OpenSSL commands on this page.

PKCS#7/P7B Format
The PKCS#7 or P7B format is usually stored in Base64 ASCII format and has a file extension of .p7b or .p7c. P7B certificates contain "-----BEGIN PKCS7-----" and "-----END PKCS7-----" statements. A P7B file only contains certificates and chain certificates, not the private key. Several platforms support P7B files including Microsoft Windows and Java Tomcat.

PKCS#12/PFX Format
The PKCS#12 or PFX format is a binary format for storing the server certificate, any intermediate certificates, and the private key in one encryptable file. PFX files usually have extensions such as .pfx and .p12. PFX files are typically used on Windows machines to import and export certificates and private keys.

When converting a PFX file to PEM format, OpenSSL will put all the certificates and the private key into a single file. You will need to open the file in a text editor and copy each certificate and private key (including the BEGIN/END statements) to its own individual text file and save them as certificate.cer, CACert.cer, and privateKey.key respectively.

OpenSSL Commands to Convert SSL Certificates on Your Machine
It is highly recommended that you convert to and from .pfx files on your own machine using OpenSSL so you can keep the private key there. Use the following OpenSSL commands to convert SSL certificate to different formats on your own machine:

OpenSSL Convert PEM
Convert PEM to DER

openssl x509 -outform der -in certificate.pem -out certificate.der

Convert PEM to P7B
openssl crl2pkcs7 -nocrl -certfile certificate.cer -out certificate.p7b -certfile CACert.cer

Convert PEM to PFX
openssl pkcs12 -export -out certificate.pfx -inkey privateKey.key -in certificate.crt -certfile CACert.crt

Convert DER to PEM
openssl x509 -inform der -in certificate.cer -out certificate.pem

Convert P7B to PEM
openssl pkcs7 -print_certs -in certificate.p7b -out certificate.cer

Convert P7B to PFX
openssl pkcs7 -print_certs -in certificate.p7b -out certificate.cer
openssl pkcs12 -export -in certificate.cer -inkey privateKey.key -out certificate.pfx -certfile CACert.cer

Convert PFX to PEM
openssl pkcs12 -in certificate.pfx -out certificate.cer -nodes

=cut




  return ();

}

