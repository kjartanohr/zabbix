#!/usr/bin/perl5.32.0
#bin
BEGIN{
 require "/usr/share/zabbix/repo/files/auto/lib.pm";
  #require "./lib.pm"
}

#TODO

#Changes
if (defined $ARGV[0] and $ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}


use warnings;
use strict;

my $process_name_org          = $0;
my $process_name              = "nextcloud-uploader";
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

our $debug                    = 0;                                                  #This needs to be 0 when running in production
our $info                     = 1;
our $warning                  = 1;
our $error                    = 1;
our $fatal                    = 1;
my  $fork                     = 1;

#Get default config
our %config                   = get_config();

#Init config
$config{'init'}   = {
};

my %shares = (

  #lukket. Upload only
  'hcp'   => {
    'id'      => 'C8erFmzmcprJMCX',
    'url'     => '',
    'comment' => 'This is a closed share. Use this for sensitive data',
  },

  #Ikke lagre viktige ting her. Alle med URL kan lese
  'tmp'   => {
    'id'      => '8irpfNWTjJ3tDLq',
    'url'     => 'https://nextcloud.kjartanohr.no/index.php/s/8irpfNWTjJ3tDLq',
    'comment' => 'This is a public share. Dont upload anything sensitive',
  },
);

my $nc_share_name = "tmp";
my $nc_share_id   = $shares{$nc_share_name}{'id'};
my $nc_url        = "https://nextcloud.kjartanohr.no/public.php/webdav";

# check if first ARGV is a file og share id
if (not -e $ARGV[0]){
  print "using the first argument as a share id\n" if $debug;
  $nc_share_id = shift @ARGV;
}

print "Using share: $nc_share_id\n";
#print "$shares{$nc_share_name}{'comment'}\n";

#Hash for long time storage. Saved to file
my $db                        = get_json_file_to_hash('file' => $config{'file'}{'database'});

#Hash for short time storage. Not saved to file
my %tmp                       = ();


#Create tmp/data directory
create_dir($dir_tmp) unless -d $dir_tmp;

#Trunk log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);



#Parse input data
#my %argv = parse_command_line(@ARGV);

#Print help if no input is given
#help('msg' => "help started from command line", 'exit'  => 1) if defined $argv{'help'};

#Activate debug if debug found in command line options
#$debug = $argv{'debug'} if defined $argv{'debug'};

#init JSON
#my $json = init_json();




#End of standard header

unless (@ARGV) {
  print "\n\nNo filename given\n";
  print "$process_name_org /var/log/file-name.txt\n\n";

}

my $hostname    = get_hostname();
my $date_time   = get_date_time();


foreach my $file_input (@ARGV) {

  my ($file_name) = $file_input =~ /.*\/(.*)/;
  $file_name      = $file_input unless defined $file_name;

  $file_name = "$hostname-$date_time-$file_name";
  $file_name =~ s/:|\s/_/g;
  print "File name: $file_name\n";

  unless (-e -f -r $file_input) {
    die "Could not read file: '$file_input'";
  }

  my $cmd_curl_upload = qq#curl_cli -vv -k -u "$nc_share_id:" -H "X-Requested-With: XMLHttpRequest" -T "$file_input" --url "$nc_url/$file_name" 2>&1#;
  print "$cmd_curl_upload\n" if $debug;
  my $cmd_curl_upload_out = `$cmd_curl_upload`;
  print $cmd_curl_upload_out if $debug;

  if ($cmd_curl_upload_out =~ /We are completely uploaded and fine/) {
    print "File upload was a success: $file_name\n";
  }
  else {
    print "File upload failed\n";
  }
  print "\n\nfetch your files here: https://nextcloud.kjartanohr.no/index.php/s/$nc_share_id\n\n";

}

