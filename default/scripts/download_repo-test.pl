#!/bin/perl
#bin

# 2023-04-19 10:30:55
# version 101

if (defined $ARGV[0] and $ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

#Add mirror check
#Download a text file with mirror urls and pick a random url to download from
#Add retry 2*mirror count
#A problem that occurs is missind DNS. Try to ass static IP in mirror file
#my $url   = "http://zabbix.kjartanohr.no/zabbix/repo/__VEe__/files/auto/";
#my $dir_local = "/usr/share/zabbix/repo/files/auto/";

my $run_validate  = 1;
$run_validate     = 0 if grep/no-validate/, @ARGV;

#Download in background if file is bigger than 100k. We don't want a zabbix timeout
my $file_size_big = 1*1024;
my $debug         = parse_input("debug",  @ARGV)     || 0;   #Look for debug flag or default to 0
my $url           = parse_input("^http",  @ARGV)     || die "URL to download from. $0 http://somewhere/download/";
my $dir_local     = parse_input("^/",     @ARGV)     || die "Need a dir to download the files $0 /tmp/download/";
my $dry_run       = 0;
my $dir_local_tmp = "$dir_local/tmp";
create_dir($dir_local_tmp);


my ($curl_cmd, $file_curl, $curl_options)      = init_curl();

my %config;
my $tmp = {};

$config{'sleep'}      = {
  'main-start'    => 5,
  'main-end'      => 60,

  'validate-end'  => 10,

  'download-file-url-check-end' => 5,
  'download-file-remote-size'   => 5,
  'download-file-download-alarm'      => 5,
  'download-file-download-failed'      => 5,
  'download-file-download'      => 5,
};

$config{'log'}{'debug'}       = {
  "enabled"       => 0,     #0/1
  'name'          => 'debug', 
  "level"         => 2,     #1-9
  "print"         => 1,     #Print to STDOUT
  "print-warn"    => 0,     #Print to STDERR
  "log"           => 0,     #Save to log file
  "file-fifo"     => 0,     #Create a fifo file for log
  "file-size"     => 100*1024*1024,    #MB max log file size
  "cmd"           => "",    #Run CMD if log. Variable: _LOG_
  "lines-ps"      => 10,    #Max lines pr second
  "die"           => 0,     #Die/exit if this type of log is triggered

  'mqtt'          => {
    "enabled"       => 1,     #0/1
    "topic"         => 'rtl/log/__NAME__',
  },
};

if ($debug){
  $config{'log'}{'debug'}{'enabled'}  = 1;
  $config{'log'}{'debug'}{'level'}    = 9;
}

$config{'log'}{'info'}       = {
  "enabled"       => 1,     #0/1
  'name'          => 'debug', 
  "level"         => 5,     #1-9
  "print"         => 1,     #Print to STDOUT
  "print-warn"    => 0,     #Print to STDERR
  "log"           => 1,     #Save to log file
  "file-fifo"     => 0,     #Create a fifo file for log
  "file-size"     => 100*1024*1024,    #MB max log file size
  "cmd"           => "",    #Run CMD if log. Variable: _LOG_
  "lines-ps"      => 10,    #Max lines pr second
  "die"           => 0,     #Die/exit if this type of log is triggered

  'mqtt'          => {
    "enabled"       => 1,     #0/1
    "topic"         => 'rtl/log/__NAME__',
  },
};

$config{'log'}{'warning'}       = {
  "enabled"       => 1,     #0/1
  'name'          => 'debug', 
  "level"         => 5,     #1-9
  "print"         => 1,     #Print to STDOUT
  "print-warn"    => 0,     #Print to STDERR
  "log"           => 1,     #Save to log file
  "file-fifo"     => 0,     #Create a fifo file for log
  "file-size"     => 100*1024*1024,    #MB max log file size
  "cmd"           => "",    #Run CMD if log. Variable: _LOG_
  "lines-ps"      => 10,    #Max lines pr second
  "die"           => 0,     #Die/exit if this type of log is triggered

  'mqtt'          => {
    "enabled"       => 1,     #0/1
    "topic"         => 'rtl/log/__NAME__',
  },
};

#debug("", "error", \[caller(0)] ) if $config{'log'}{'error'}{'enabled'};
$config{'log'}{'error'}       = {
  "enabled"       => 1,     #0/1
  'name'          => 'debug', 
  "level"         => 5,     #1-9
  "print"         => 1,     #Print to STDOUT
  "print-warn"    => 0,     #Print to STDERR
  "log"           => 1,     #Save to log file
  "file-fifo"     => 0,     #Create a fifo file for log
  "file-size"     => 100*1024*1024,    #MB max log file size
  "cmd"           => "",    #Run CMD if log. Variable: _LOG_
  "lines-ps"      => 10,    #Max lines pr second
  "die"           => 0,     #Die/exit if this type of log is triggered

  'mqtt'          => {
    "enabled"       => 1,     #0/1
    "topic"         => 'rtl/log/__NAME__',
  },
};

$config{'log'}{'fatal'}       = {
  "enabled"       => 1,     #0/1
  'name'          => 'debug', 
  "level"         => 5,     #1-9
  "print"         => 1,     #Print to STDOUT
  "print-warn"    => 0,     #Print to STDERR
  "log"           => 1,     #Save to log file
  "file-fifo"     => 0,     #Create a fifo file for log
  "file-size"     => 100*1024*1024,    #MB max log file size
  "cmd"           => "",    #Run CMD if log. Variable: _LOG_
  "lines-ps"      => 10,    #Max lines pr second
  "die"           => 0,     #Die/exit if this type of log is triggered

  'mqtt'          => {



    "enabled"       => 1,     #0/1
    "topic"         => 'rtl/log/__NAME__',
  },
};


#Static DNS
my %domain                      = (
  "zabbix.kjartanohr.no"  => "92.220.216.51",
  "github.com"            => "140.82.121.4",
  "www.github.com"        => "140.82.121.4",
);

my %dns_server                  = (
  "92.220.216.51"         => 1,               #Backup DNS server zabbix repo server
  "8.8.8.8"               => 1,               #Google DNS
  "1.1.1.1"               => 1,               #CloudFlare DNS
  "127.0.0.1"             => 1,               #Try the local dns server
);




#Add correct version to the URL
$url = get_url($url);
debug("\$url: $url", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

#Create local repo directory if it does not exist
debug("mkdir $dir_local", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
#run("mkdir -p $dir_local/ &>/dev/null");
create_dir($dir_local);

#Curl command to run
my $curl = run("$curl_cmd $url", 'desc' => "curl get HTML page");

#for loop for the HTML from curl
FILE:
foreach (split/\n/, $curl){

  #Skip the line if is does not contain a URL
  next unless /<a href="/;

  #Skip if the URL destination is same og parent dir
  if (/(C=D;O=A|\[(?:PARENTDIR|DIR)\])/){
    debug("regex exclude matched ($1) for line: $_", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
    next FILE;
  }

  #URL for a file
  # <tr><td valign="top"><img src="/icons/p.gif" alt="[   ]"></td><td><a href="upload_nc.pl">upload_nc.pl</a>           </td><td align="right">2023-04-04 13:13:10:32.264642 *
  my ($file_remote) = /<a href="(.*?)">/;
  #print "\$file_remote: $file_remote\n";
  if (validate_data($file_remote, "url from this line: $_")){
    debug("validate_data(\$file_remote: $file_remote, OK);", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  }
  else {
    debug("validate_data(\$file_remote: $file_remote, FAILED. next FILE);", 'error', \[caller(0)]) if $config{'log'}{'error'}{'enabled'} and $config{'log'}{'error'}{'level'} > 1;
    next FILE;
  }
  debug("\$file_remote: \$file_remote: $file_remote", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;


  #Modified time for the file
  # <tr><td valign="top"><img src="/icons/p.gif" alt="[   ]"></td><td><a href="upload_nc.pl">upload_nc.pl</a>           </td><td align="right">2023-04-04 13:13:10:32.264642 *
  #my ($file_remote_mtime) = /align="right">(.*?) [<\*]/;
  #my ($file_remote_mtime) = /align="right">(.*?) </;
  my ($file_remote_mtime) = /align="right">(.*?) \D/; # 2023.04.04
  if (validate_data($file_remote_mtime, "mtime from this line: $_")){
    debug("validate_data(\$file_remote_mtime: $file_remote_mtime, OK);", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  }
  else {
    debug("validate_data(\$file_remote_mtime: $file_remote_mtime. line: $_, FAILED. next FILE);", 'error', \[caller(0)]) if $config{'log'}{'error'}{'enabled'} and $config{'log'}{'error'}{'level'} > 1;
    next FILE;
  }



  #Convert remote modified time to unix sec
  $file_remote_mtime = run("date '+%s' -d '$file_remote_mtime'", 'desc' => "date. convert timestamp");
  chomp $file_remote_mtime;
  #chomp($file_remote_mtime = `date "+%s" -d "$file_remote_mtime"`);
  
  if (validate_data($file_remote_mtime, "remote file mtime $_")){
    debug("validate_data(\$file_remote_mtime: $file_remote_mtime, OK);", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  }
  else {
    debug("validate_data(\$file_remote_mtime: $file_remote_mtime, FAILED. next FILE);", 'error', \[caller(0)]) if $config{'log'}{'error'}{'enabled'} and $config{'log'}{'error'}{'level'} > 1;
    next FILE;
  }


  #A complete path for the file
  my $file_local      = $dir_local.$file_remote;
  my $file_local_tmp  = "$dir_local_tmp/$file_remote";
  debug("\$file_local: $file_local", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  
  if (validate_data($file_local, "path for local file")){
    debug("validate_data(\$file_local: $file_local, OK);", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  }
  else {
    debug("validate_data(\$file_local: $file_local, FAILED. next FILE);", 'error', \[caller(0)]) if $config{'log'}{'error'}{'enabled'} and $config{'log'}{'error'}{'level'} > 1;
    next FILE;
  }


  #Get the remote file size
  #my $file_remote_header = `curl_cli -k -I $url$file_remote 2>&1`;
  #validate_data($file_remote_header, "curl_cli -k -I $url$file_remote\n$file_remote_header") || next;

  #my ($file_remote_size) = $file_remote_header =~ /Content-Length: (\d{1,})/;
  #validate_data($file_remote_size, "remote file size") || next;


  my $download_again = 0;
  if (-f $file_local) {
    print "Found a matching local file: $file_local\n" if $debug;

    #Get the modified time of the local file
    my $file_local_mtime = (stat($file_local))[9];
    validate_data($file_local_mtime, "local file mtime") || next;

    #Get the size of the local file
    #$file_local_size = (stat($file_local))[7];
    #validate_data($file_local_size, "local file size") || next;

    #Check if file size of local and remote is the same
    #print "Remote size: $file_remote_size. Local size: $file_local_size\n" if $debug;
    #unless ($file_remote_size eq $file_local_size) {
    #  print "File size for remote and local file is different. Will download the file again\n" if $debug;
    #  $download_again = 1;
    #}

    #Check if the file is executable
    if ($file_local =~ /(\.(?:pl|pm|sh))$/ and -x $file_local){
      debug("regex match $1. File is executable. No changes needed", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
    }
    else {
      debug("regex match $1. File is not executable. Will add +x to the file", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
      run("chmod +x '$file_local'", 'desc' => "chmod +x \$file_local");
    }

    #If the local and remote modified time is the same, skip this URL/file
    if ( ($file_local_mtime >= $file_remote_mtime) and not $download_again){
      debug("mtime and file size for remote and local file is the same. Skipping this file. next FILE", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
      next FILE;
    }

    debug("Will download file from repo: $file_remote -> $file_local", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  }


  my $fork = 0;
  if ($file_remote_size > $file_size_big) {
    debug("Download file size $file_remote $file_remote_size is bigger than $file_size_big. will download this file in the background. \$fork = 1", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
    $fork = 1;
  }
  else {
    debug("Download file size $file_remote $file_remote_size is less than $file_size_big. will not download this file in the background", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  }

  my $pid;
  my $child = 0;
  #Download the new file
  DOWNLOAD: {
    debug("DOWNLOAD loop", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

    if ($fork and $debug == 0) {
      $pid = fork && next FILE;
      $child = $fork;

      close STDOUT;
      close STDIN;
      close STDERR;
    }

    my $cmd_curl_dl = "$curl_cmd '$url$file_remote' -o '$file_local'";
    #print "CMD: $cmd_curl_dl\n" if $debug;

    #my $out_curl_dl = run($cmd_curl_dl);



    
    if (download_file("$url$file_remote", 'filename' => $file_local_tmp)){
      debug("download_file status OK", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
    }
    else {
      debug("download_file() status FAILED. next FILE);", 'error', \[caller(0)]) if $config{'log'}{'error'}{'enabled'} and $config{'log'}{'error'}{'level'} > 1;
    }
  }

  debug("File is downloaded", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;



  #Check if the local file is downloaded
  unless (-f $file_local_tmp){
    debug("Need a human here. Could not find the downloaded file $file_local", 'info', \[caller(0)]) if $config{'log'}{'info'}{'enabled'} and $config{'log'}{'info'}{'level'} > 1;
    next FILE if not defined $pid;
  }

  #Make the script executable
  if ($file_local =~ /\.pl$|\.sh$/){
    run("chmod +x '$file_local_tmp'", 'desc' => "chmod +x \$file_local");
  }


  if ($run_validate == 1){
    my ($file_validate_status, $file_validate_message) = file_validate('file' => $file_local_tmp);
    if ($file_validate_status == 0){
      #debug("file_validate(), FAILED. next FILE",  'error', \[caller(0)]) if $config{'log'}{'error'}{'enabled'} and $config{'log'}{'error'}{'level'} > 1;
      debug("validate failed for $file_local_tmp. $file_validate_message",  'error', \[caller(0)]) if $config{'log'}{'error'}{'enabled'} and $config{'log'}{'error'}{'level'} > 1;
      next FILE if $child ==  0;
      exit      if $child <   0;
    }
    debug("file_validate(), OK", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  }

  #Rename old file from name to name.old
  debug("Renameing: $file_local -> $file_local.old", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  if (-f $file_local) {
    my $rename_status = rename $file_local,"$file_local.old";
    if ($rename_status == 1){
      debug("renaming file, OK", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
    }
    else {
      debug("Could not rename file: $!. next FILE",  'error', \[caller(0)]) if $config{'log'}{'error'}{'enabled'} and $config{'log'}{'error'}{'level'} > 1;
      next FILE;
    }
  }


  debug("rename $file_local_tmp, $file_local;", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  rename $file_local_tmp, $file_local;

  if ($file_local =~ /(\.(?:rpm))$/){
    my $install_rpm_status = install_rpm('file' => $file_local);
    if ($install_rpm_status == 0){
      debug("install_rpm(), status: FAILED", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
      debug("rpm install FAILED for $file_local",  'error', \[caller(0)]) if $config{'log'}{'error'}{'enabled'} and $config{'log'}{'error'}{'level'} > 1;
    }
    debug("install_rpm(), status: OK", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  }

  #Print back to zabbix
  print "$file_remote\n";


  debug("\$pid is not defined. This is the parent", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

  next FILE if $child ==  0;
  exit      if $child <   0;

}

sub get_url {
  my $url = shift || die "Need a human here. Need a URL to download from";

  my $ver = "default";

  #Run the command fw ver to get the installed version
  my $fw = run("fw ver");
  unless ($fw =~ /software version/){
    #print "Need a human here. Could not get FW version from fw ver";
    debug("Need a human here. Could not get FW version from fw ver",  'error', \[caller(0)]) if $config{'log'}{'error'}{'enabled'} and $config{'log'}{'error'}{'level'} > 1;
    #exit;
  }

  #Get the Check Point version from fw ver
  my ($fw_ver) = $fw =~ / version (.*?) /;
  if (defined $fw_ver){
    debug("Found version from string: $fw_ver", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
    $ver = $fw_ver;
  }
  else {
    debug("Could not find version in string", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  }

  #Lowercase the version (the R)
  $ver = lc $ver;

  #The URL for the repo
  $url =~ s/__VER__/$ver/g;

  #$url = lc $url;
  return $url;

}

sub parse_input {
  my $search  = shift;
  my @input   = @_;

  foreach (@input) {
    next unless /$search/;
    print "Found $search in input\n" if $debug;
    return $_;
  }
}

sub validate_data {
  my $data  = shift;
  my $msg   = shift || "unknown error";
  my $die   = shift || "";

  if (defined $data) {
    print "Data found: $data\n" if $debug;
    return 1;
  }
  else {
    my $msg_complete = "Missing data for $msg ";

    die "$msg_complete\n" if $die;

    print $msg_complete;

    return 0;
  }
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


sub pause {
  my $msg = shift || "Press ENTER to continue\n";

  ask($msg);
}

sub ask {
  my $msg             = shift || die "Missing question";
  my %input           = @_;

  $input{'answer'}  ||= 0;
  $input{'timeout'} ||= 0;
  $input{'print'}   ||= 0;

  my $answer;

  #print $clear if $input{'clear'};


  if ($input{'answer'}) {
    $msg = "$msg\nCTRL+C to cancel. Press $input{'answer'} to continue: ";
  }
  else {
    $msg = "$msg\nCTRL+C to cancel. Press ENTER to continue";
  }

  print $msg;

  open my $tty, "<", "/dev/tty" or die "Cant open /dev/tty: $!";

  unless ($input{'answer'}) {
    $answer = <$tty>;
    return;
  }

  while (<$tty>){
    chomp;
    next unless $_;
    $answer = $_;
    last;
  };

  if ($input{'answer'}) {
    if ($answer ne $input{'answer'}) {
      print "You answered: \"$answer\". Correct answer was $input{'answer'}. Exiting\n";
      exit;
    }
    else {
      print "You answered: \"$answer\". Continuing\n";
    }
  }

  print "You answered: $answer\n" if $input{'print'};

  return $answer;

}

sub get_file_size_remote {
  my $url = shift || die "Need a URL to check file size\n";

  #Get the remote file size
  my $cmd_curl_remote_header = "$file_curl -I $curl_options $url 2>&1";
  debug("CMD curl: $cmd_curl_remote_header");

  my $out_curl_remote_header = `$cmd_curl_remote_header`;

  my $file_remote_header = $out_curl_remote_header;
  validate_data($file_remote_header, "$cmd_curl_remote_header\n$file_remote_header") || return;

  debug("File remote header: $file_remote_header");

  my ($file_remote_size) = $file_remote_header =~ /Content-Length: (\d{1,})/i;
  validate_data($file_remote_size, "remote file size") || return;

  return $file_remote_size;
}


sub get_file_size_local {
  my $file = shift || die "Need a filename to check file size\n";

  if (not -f $file) {
    debug("Could not find the local $file to check the file size\n");
    return 0;
  }

  debug("Found a matching local file: $file", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  #Get the size of the local file
  my $file_size = (stat($file))[7];
  debug("\$file_size: $file_size", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

  my $status = validate_data($file_size, "stat coult not get local file size");
  if ($status) {
    debug("validate data for \$file_size is OK. File $file size $file_size");
  }
  else {
    debug("validate data for \$file_size FAILED. No data found.");
    return;
  }

  return $file_size;
}

sub validate_data {
  my $data  = shift;
  my $msg   = shift // "unknown error";
  my $die   = shift // 0;

  if (not defined $data){
    debug("validate_data() failed. \$data not defined. return 0", 'warning', \[caller(0)]) if $config{'log'}{'warning'}{'enabled'} and $config{'log'}{'warning'}{'level'} > 1;
    die "validate_data() failed. \$data not defined. return 0. \$die is true. die" if $die;
    return 0;
  }
  if (not defined $data){
    debug("validate_data() failed. \$data not defined. return 0", 'warning', \[caller(0)]) if $config{'log'}{'warning'}{'enabled'} and $config{'log'}{'warning'}{'level'} > 1;
    return 0;
  }



  if ($data) {
    #debug("Data found: $data\n");
    return 1;
  }
  else {
    my $msg_complete = "Missing data for $msg " if $debug;

    die "$msg_complete\n" if $die;

    print $msg_complete;

    return 0;
  }
}

sub download_file {
  my $sub_name = (caller(0))[3];
  debug("start", $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 1;
  debug("input: ".Dumper(@_), $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 3;

  my $url                 = shift || die "Missing URL";
  my %input               = @_;

  $input{'filename'}    || die "Need a filename";
  $input{'retry'}       ||= 100;
  $input{'timeout'}     ||= 120;

  #make $curl_options local. Changes will live inside this sub 
  my $curl_options_local   = $curl_options;

  debug(((caller(0))[3])." Url: $url");
  debug(((caller(0))[3])." Filename: $input{'filename'}");
  debug(((caller(0))[3])." Retry: $input{'retry'}");
  debug(((caller(0))[3])." Timeout: $input{'timeout'}");

  my $filename = $input{'filename'};

  #Validate hostname before running curl START

  #Parse and validate URL
  my ($proto, $domain, $path) = parse_url('url' => $url);

  debug("Resolving hostname from URL\n");
  unless (check_dns_resolve($domain)) {
    warn "Could not resolve hostname $domain. Check your DNS settings";
    warn "Adding static IP-addresses to curl";
    my $curl_dns        = get_curl_static_dns();
    $curl_options_local = "$curl_dns $curl_options";
  }


  #Validate hostname before running curl END

  my $cmd_curl_download   = qq#$file_curl --output "$input{'filename'}" $curl_options_local "$url" #;
  my $cmd_curl_header     = qq#$file_curl --head $curl_options_local "$url"#;
  my $url_check_count_max = 60;


  if ($input{'filename'}) {
    debug(((caller(0))[3])." Found input filename: $filename\n");
    my ($dir) = $filename =~ /(.*)\//;

    if (not -d $dir) {
      my $cmd_mkdir = "mkdir -p $dir";
      debug(((caller(0))[3])." The directory path for the filename does not exist. Will create the directory path: $cmd_mkdir\n");
      run($cmd_mkdir, 'desc' => "create dir $cmd_mkdir");
    }

  }

  #if (not $input{'filename'}) {
  #  debug(((caller(0))[3])." No filename given. Will extract it from URL\n");
  #  $input{'filename'} = get_filename_from_url();

  #  die "Could not extract filename from url: $url" unless $input{'filenmae'};
  #  debug(((caller(0))[3])." Filename is set to $input{'filename'}\n");
  #}

  debug(((caller(0))[3])." Checking if URL is reachable: $url\n");
  my $url_check_count = 0;
  URL_CHECK:
  while ($url_check_count < $url_check_count_max) {
    $url_check_count++;

    if ($url_check_count > $url_check_count_max) {
      debug(((caller(0))[3])." Max retry is reached. Try again when $url is reachable\nYou can check with the command: $cmd_curl_header\n");
      warn "Failed to download $url";
      return;
    }

    debug(((caller(0))[3])." Command: $cmd_curl_header\n");
    my $cmd_curl_header_out = `$cmd_curl_header 2>&1`;

    debug("curl header: $cmd_curl_header_out");

    if ($cmd_curl_header_out =~ /200 OK/) {
      debug(((caller(0))[3])." HTTP 200 OK. This URL is valid\n");
      last URL_CHECK;
    }
    else {
      debug(((caller(0))[3])." Could not find 200 OK in output, retry $url_check_count/$url_check_count_max: $cmd_curl_header_out\n");
      sleep 1;
      next URL_CHECK;
    }
  }

  debug(((caller(0))[3])." Checking remote file size\n");
  my $file_remote_size = get_file_size_remote($url);

  unless ($file_remote_size) {
    debug(((caller(0))[3])." Could not get remote file size\n");
    sleep 1;
    return 0;
  }
  debug(((caller(0))[3])." Got remote file size: $file_remote_size\n");


  debug(((caller(0))[3])." Will try to download $url\n");
  my $cmd_curl_download_out;
  my $url_download_count = 0;
  URL_DOWNLOAD:
  while ($url_download_count < $url_check_count_max) {
    $url_download_count++;

    eval {
      local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required

      debug(((caller(0))[3])." Setting timeout in perl code for $input{'timeout'} seconds\n");
      alarm $input{'timeout'};

      debug(((caller(0))[3])." Running command: $cmd_curl_download\n");
      $cmd_curl_download_out = run("$cmd_curl_download", 'desc' => "$sub_name. curl. download file");
      debug("CMD curl download file: $cmd_curl_download_out");

      debug(((caller(0))[3])." Resetting alarm\n");
      alarm 0;
    };

    if ($@) {
      debug(((caller(0))[3])." Timeout for download reached. sleep 1. next\n");
      sleep 1;
      next URL_DOWNLOAD;
    }

    my $file_local_size;
    if (-f $input{'filename'}) {
      debug(((caller(0))[3])." Checking local file size for file $input{'filename'}. URL $url\n");
      $file_local_size = get_file_size_local($input{'filename'});
      #die "Could not get local file size. Exiting" unless $file_local_size;
      debug(((caller(0))[3])." Got local file size: $file_local_size\n");
      return 1;
    }
    else {
      debug("Local file not found. No need to check file size for $input{'filename'}. Download Failed. next");
      next URL_DOWNLOAD;
    }

    debug(((caller(0))[3])." Checking if remote and local file size is the same: remote: $file_remote_size == local: $file_local_size\n");
    if ($file_remote_size == $file_local_size) {
      debug(((caller(0))[3])." File size is the same. Download OK\n");
      return $input{'filename'};
    }
    else {
      debug(((caller(0))[3])." File size is NOT the same. Retry\n");
      unlink $input{'filename'};
      next URL_DOWNLOAD;
    }
  }
  
  return 1 if -f $input{'filename'};
  return 0 if -f $input{'filename'};
}

sub get_local_id {
  my $sub_name = (caller(0))[3];
  debug("start", $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 1;
  debug("input: ".Dumper(@_), $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 3;

  my $id;

  my @cmd = (
    "hostname",
    "uname -a",
    "fw ver",
    "w",
    "whoami",
  );

  foreach my $cmd (@cmd) {
    debug(((caller(0))[3])." Running command $cmd\n");
    my $cmd_out = run($cmd, 'desc' => "$sub_name. create local id $cmd");
    chomp $cmd_out;
    #debug(((caller(0))[3])." Output from command: $cmd_out\n");

    next if $cmd_out =~ /command not found/;

    $cmd_out =~ s/\n|\r/ /g;
    $cmd_out =~ s/\W/ /g;

    #debug(((caller(0))[3])." Output from command after changes: $cmd_out\n");

    $id .= "$cmd_out ";
  }

  #debug(((caller(0))[3])." Returning $id\n");
  return $id;
}

sub get_filename_from_url {
  debug(((caller(0))[3])." Start\n");
  my $url = shift || die "Need a URL to extract filename from";

  my ($filename) = $url =~ /.*\/(.*)/;

  if ($filename) {
    debug(((caller(0))[3])." Found filename: $filename\n");
    return $filename;
  }
  else {
    debug(((caller(0))[3])." Could not extract filename from $url\n");
    return;
  }
}

sub check_dns_resolve {
  my $sub_name = (caller(0))[3];
  debug("start", $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 1;
  debug("input: ".Dumper(@_), $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 3;

  my $hostname = shift || die "Need a hostname to resolve";
  debug(((caller(0))[3])." Input hostname: $hostname\n");

  my $cmd_dig = "dig +timeout=2 $hostname";
  debug(((caller(0))[3])." Running command: $cmd_dig\n");

  my $cmd_dig_out = run($cmd_dig, 'desc' => "$sub_name. dig resolve $hostname");
  #debug(((caller(0))[3])." Output from command: $cmd_dig_out\n");

  debug(((caller(0))[3])." Looking for: status: NOERROR\n");
  if ($cmd_dig_out =~ /status: NOERROR/) {
    debug(((caller(0))[3])." Resolve OK\nOutput: $cmd_dig_out");
    return 1;
  }
  else {
    debug(((caller(0))[3])." Resolve FAILED. Output: $cmd_dig_out\n");
    return 0;
  }
}

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


    my $out = `whereis $file`;
    chomp $out;

    my ($path) = $out =~ /: (.*)/;
    $path =~ s/ .*//;

    if ($path) {
      debug("Found file $file. $path");
      return $path;

    }
  }

  foreach my $file (@files) {
    debug("Looking for file $file");

    foreach my $find_file (`timeout 60s find / -name $file`) {
      next unless $find_file;
      chomp $find_file;
      debug("Found file $file. $find_file");
      return $find_file;

    }

  }


  return;
}



sub array_to_string {
  my %input = @_;
  my $string;

  foreach my $data (@{$input{'array'}}) {
    $string .= "$data "; 
  }

  return $string;
}

sub get_curl_static_dns {
  my %input = @_;
  my $string;

  foreach my $host (keys %domain) {
    next unless $host;
    my $ip = $domain{$host};

    #"--resolve zabbix.kjartanohr.no:80:92.220.216.51",        #Resolve the host+port to this address
    $string .= "--resolve '$host:80:$ip' "; 
    $string .= "--resolve '$host:443:$ip' "; 
  }

  return $string;
}



sub parse_input {
  my $search  = shift;
  my @input   = @_;

  foreach (@input) {
    next unless /$search/;
    print "Found $search in input\n" if $debug;
    return $_;
  }
}


sub install_rpm {

  

}





#my ($proto, $domain, $path) = parse_url($url);
sub parse_url {

  my %input = @_;

  unless (defined $input{'url'}) {
    die "Missing input data 'url'";
  }

  debug("URL: $input{'url'}", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

  my ($proto, $domain, $path) = $input{'url'} =~ /^(h.*?):\/\/(.*?)(\/.*)/;

  #Validate protocol
  if ($proto) {
    debug("Protocol: $proto", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  }
  else {
    die "Missing protocol from URL: $input{'url'}";
  }

  #Validate domain
  if ($domain) {
    debug("Domain $domain", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  }
  else {
    die "Missing domain from URL: $input{'url'}";
  }

  #Validate path
  if ($path) {
    debug("path: $path", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
  }
  else {
    die "Missing path from URL: $input{'url'}";
  }

  
  return ($proto, $domain, $path);
}


sub create_dir {
  my $sub_name = (caller(0))[3];
  debug("start", $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 1;
  debug("input: ".Dumper(@_), $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 3;

  my $name = shift || die "Need a directory name to create\n";
  debug("Input directory name: $name", "debug", \[caller(0)] ) if $debug > 2;

  my $out;

  if (-d $name){
    debug("$name directory exists. No need to create", "debug", \[caller(0)] ) if $debug > 2;
    return 1;
  }
  else {
    my $cmd = "mkdir -p $name";
    my $out = run($cmd, 'desc' => "$sub_name. mkdir -p $name");
    debug("$name directory missing. Creating. Out: $out", "debug", \[caller(0)] ) if $debug > 2;
  }

  unless (-d $name) {
    debug("Could not create $name: $out", "fatal", \[caller(0)] );
  }
}


sub init_curl {

  my $file_curl                   = whereis('curl', 'curl_cli');
  #my $useragent                   = get_local_id();
  my $useragent                   = "";
  my $hostname                    = `hostname`;
  chomp $hostname;
  #my $curl_options               = " -v -k --trace-time --create-dirs --location --user-agent '$useragent' ";

  # debug: main::download_file Could not find 200 OK in output, retry 3/60: curl: option --verbose-extended: is unknown

  my @curl_options                = (
    "-vvv",                                     #Extra verbose
    #"--verbose-extended",                      #Show HTTP header and body (Checkpoint option). Denne virker ikke etter R81.X
    #"--dns-servers",                           #<addresses> DNS server addrs to use
    "--insecure",                               #Allow insecure server connections when using SSL
    "--ipv4",                                   #Resolve names to IPv4 addresses
    "--keepalive-time 60",                      #<seconds> Interval time for keepalive probes
    #"--limit-rate 10000",                      #Limit transfer speed to RATE",
    #"--local-port 30000-30100",                #Force use of RANGE for local port numbers
    "--location",                               #Follow redirects
    "--max-redirs 10",                          #Maximum number of redirects allowed
    "--max-time 600",                           #Maximum time allowed for the transfer
    "--progress-bar",                           #Display transfer progress as a bar
    "--referer '$0'",    #Referrer URL
    "--remote-time",                            #Set the remote file's time on the local output
    #"--resolve zabbix.kjartanohr.no:80:92.220.216.51",        #Resolve the host+port to this address
    "--retry 10",                               #Retry request if transient problems occur
    #"--stderr",                                #Where to redirect stderr
    "--trace-time",                             #Add time stamps to trace/verbose output
    "--create-dirs",
    "--location",
    "--user-agent '$useragent'",
    "--speed-limit 10000",                      #Stop transfers slower than this
    "--speed-time 10",                          #Trigger 'speed-limit' abort after this time
    #"--header 'Host: zabbix.kjartanohr.no'",   #Pass custom header(s) to server
    "--url",                                    #URL to work with

    #Not supported
    #"--retry-connrefused 1",                   #Retry on connection refused (use with --retry)
    #"--fail-early",                            #NOT SUPPORTED. Fail on first transfer error, do not continue
    #"--false-start",                           #NOT SUPPORTED. Enable TLS False Start
    #"--styled-output",                         #Enable styled output for HTTP headers
    #"--tcp-fastopen",                          #NOT SUPPORTED. Use TCP Fast Open
  );

  my $curl_options                = array_to_string('array' => \@curl_options);
 
  return ("$file_curl $curl_options", $file_curl, $curl_options);

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


sub file_validate {
  my $sub_name = (caller(0))[3];
  debug("start", $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 1;
  debug("input: ".Dumper(@_), $sub_name, \[caller(0)]) if $config{'log'}{$sub_name}{'enabled'} and $config{'log'}{$sub_name}{'level'} > 3;

  #sub header start
  my %input   = @_;
  debug("$sub_name. $input{'desc'}", $sub_name, \[caller(0)]) if $config{'log'}{'desc'}{'enabled'} and $config{'log'}{'desc'}{'level'} > 0 and defined $input{'desc'};

  my $return = 1;

  #default values
  $input{'exit-if-fatal'}         //= 0;
  $input{'return-if-fatal'}       //= 1;
  $input{'validate-return-data'}  //= 1;
  #$input{'xxx'} = "yyy" unless defined $input{'xxx'};

  #validate input data start
  if ($config{"val"}{'sub'}{'in'}){
    my @input_type = qw( file );
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

  #my $file_validate = {
  #  '\.pl$'   => {
  #    ''
  #  }
  #};

  #Check if the file is executable
  if ($input{'file'} =~ /(\.(?:pl|pm|sh))$/i){
    debug("regex match $1. validating file", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

    chomp $input{'file'};

    if (not -x $input{'file'}){
      debug("$input{'file'} is not executable. chmod +x", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
      run("chmod +x $input{'file'}");
    }
    #my $cmd_validate      = "perl $input{'file'} --zabbix-test-run";
    my $cmd_validate      = "$input{'file'} --zabbix-test-run";
    my $cmd_validate_out  = run($cmd_validate, 'desc' => "$sub_name. validating file");
    debug("\$cmd_validate_out: $cmd_validate_out", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

    if ($cmd_validate_out =~ /ZABBIX TEST OK/){
      debug("Found ZABBIX TEST OK in output. Status: OK", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
      $return = 1;
    }
    else {
      debug("Did NOT find ZABBIX TEST OK in output. Status: FAILED", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
      $return = 0;
    }
  }
  elsif ($input{'file'} =~ /(\.(?:rpm))$/){
    #[Expert@gw-cp-kfo:0]# rpm --checksig fping-2.4-1.b2.3.el5.rf.i386.rpm
    #fping-2.4-1.b2.3.el5.rf.i386.rpm: (SHA1) DSA sha1 md5 (GPG) NOT OK (MISSING KEYS: GPG#6b8d79e6)
    #[Expert@gw-cp-kfo:0]# >test.rpm
    #[Expert@gw-cp-kfo:0]# rpm --checksig test.rpm
    #error: test.rpm: not an rpm package
    #[Expert@gw-cp-kfo:0]#

    debug("regex match $1. validating file", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

    my $cmd_validate      = "rpm --checksig '$input{'file'}'";
    my $cmd_validate_out  = run($cmd_validate, 'desc' => "$sub_name. validating file");
    debug("\$cmd_validate_out: $cmd_validate_out", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

    if ($cmd_validate_out =~ /(^error:|not an rpm package)/){
      debug("validate failed. Matched on regex $1. Status: FAILED", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
      $return = 0;
    }
    else {
      debug("Did not match on failed regex. Status: OK", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
      $return = 1;
    }
  }
  elsif ($input{'file'} =~ /(\.(?:gz))$/){
    # [root@zabbix-dmz files]# gzip --list snmp/mibs_all.tar.gz
    #         compressed        uncompressed  ratio uncompressed_name
    #          287618774          1686763520  82.9% snmp/mibs_all.tar
    # [root@zabbix-dmz files]#
     
    debug("regex match $1. validating file", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

    my $cmd_validate      = "gzip --list '$input{'file'}'";
    my $cmd_validate_out  = run($cmd_validate, 'desc' => "$sub_name. validating file");
    debug("\$cmd_validate_out: $cmd_validate_out", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

    if ($cmd_validate_out =~ /(compressed)/){
      debug("Found $1 in output. Status: OK", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
      $return = 1;
    }
    else {
      debug("Did NOT match on regex from output. Status: FAILED", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
      $return = 0;
    }


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
  return ($return, $cmd_validate_out);

  #sub end section END

}
#sub template END



sub install_rpm {
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
  #$input{'xxx'} = "yyy" unless defined $input{'xxx'};

  #validate input data start
  if ($config{"val"}{'sub'}{'in'}){
    my @input_type = qw( file );
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

  my ($file_validate_status, $file_validate_message) = file_validate('file' => $input{'file'});
  if ($file_validate_status == 0){
    #debug("file_validate(), FAILED. next FILE",  'error', \[caller(0)]) if $config{'log'}{'error'}{'enabled'} and $config{'log'}{'error'}{'level'} > 1;
    debug("validate failed for $input{'file'}. $file_validate_message",  'error', \[caller(0)]) if $config{'log'}{'error'}{'enabled'} and $config{'log'}{'error'}{'level'} > 1;
    return 0;
  }
  debug("file_validate(), OK", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;


  #my $rpm_cmd = "rpm -Uhvv --force --nodeps $input{'file'}";
  my $rpm_cmd = "rpm -Uhv --force --nodeps $input{'file'}";
  my $rpm_cmd_out = run($rpm_cmd);
  debug("\$rpm_cmd_out: $rpm_cmd_out", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

  if ($rpm_cmd_out =~ /#{50}/){
    debug("rpm install status: OK", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
    $return = 1;
  }
  else {
    debug("rpm install status: FAILED", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;
    $return = 0;
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





