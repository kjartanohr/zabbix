#!/bin/perl
#bin

if (defined $ARGV[0] and $ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

#Add mirror check
#Download a text file with mirror urls and pick a random url to download from
#Add retry 2*mirror count
#A problem that occurs is missind DNS. Try to ass static IP in mirror file
#my $url   = "http://zabbix.kjartanohr.no/zabbix/repo/__VER__/files/auto/";
#my $dir_local = "/usr/share/zabbix/repo/files/auto/";


#Download in background if file is bigger than 100k. We don't want a zabbix timeout
my $file_size_big = 100*1024;
my $debug         = parse_input("debug",  @ARGV)     || 0;   #Look for debug flag or default to 0
my $url           = parse_input("^http",  @ARGV)     || die "URL to download from. $0 http://somewhere/download/";
my $dir_local     = parse_input("^/",     @ARGV)     || die "Need a dir to download the files $0 /tmp/download/";


#Add correct version to the URL
$url = get_url($url);

#Create local repo directory if it does not exist
system "mkdir -p $dir_local/ &>/dev/null";

#Curl command to run
my $curl = `curl_cli -k -s $url`;

#for loop for the HTML from curl
FILE:
foreach (split/\n/, $curl){

  #Skip the line if is does not contain a URL
  next unless /<a href="/;

  #Skip if the URL destination is same og parent dir
  next if /C=D;O=A|PARENTDIR/;

  #URL for a file
  my ($file_remote) = /<a href="(.*?)">/;

  validate_data($file_remote, "url from this line: $_") || next;

  #Modified time for the file
  my ($file_remote_mtime) = /align="right">(.*?) </;
  validate_data($file_remote_mtime, "mtime from this line: $_") || next;

  #Convert remote modified time to unix sec
  chomp($file_remote_mtime = `date "+%s" -d "$file_remote_mtime"`);
  validate_data($file_remote_mtime, "remote file mtime $_") || next;

  #A complete path for the file
  my $file_local = $dir_local.$file_remote;
  validate_data($file_local, "path for local file") || next;

  #Get the remote file size
  my $file_remote_header = `curl_cli -k -I $url$file_remote 2>&1`;
  validate_data($file_remote_header, "curl_cli -k -I $url$file_remote\n$file_remote_header") || next;

  my ($file_remote_size) = $file_remote_header =~ /Content-Length: (\d{1,})/;
  validate_data($file_remote_size, "remote file size") || next;


  my $download_again = 0;
  if (-f $file_local) {
    print "Found a matching local file: $file_local\n" if $debug;

    #Get the modified time of the local file
    my $file_local_mtime = (stat($file_local))[9];
    validate_data($file_local_mtime, "local file mtime") || next;

    #Get the size of the local file
    $file_local_size = (stat($file_local))[7];
    validate_data($file_local_size, "local file size") || next;

    #Check if file size of local and remote is the same
    print "Remote size: $file_remote_size. Local size: $file_local_size\n" if $debug;
    unless ($file_remote_size eq $file_local_size) {
      print "File size for remote and local file is different. Will download the file again\n" if $debug;
      $download_again = 1;
    }

    #Check if the file is executable
    if ($file_local =~ /\.pl$|\.sh$/ and -x $file_local){
      print "File is executable. No changes needed\n" if $debug;
    }
    else {
      print "File is not executable. Will add +x to the file\n" if $debug;
      system qq#chmod +x $file_local#;
    }

    #If the local and remote modified time is the same, skip this URL/file
    if ( ($file_local_mtime > $file_remote_mtime) and not $download_again){
      print "mtime and file size for remote and local file is the same. Skipping this file\n" if $debug;
      next;
    }

    print "Will download file from repo: $file_remote -> file_local\n" if $debug;

    #Rename old file from name to name.old
    print "Renameing: $file_local -> $file_local.old\n" if $debug;
    rename $file_local,"$file_local.old";
  }


  my $fork = 0;
  if ($file_remote_size > $file_size_big) {
    print "Download file size $file_remote is bigger than $file_size_big. will download this file in the background\n" if $debug;
    $fork = 1;
  }
  else {
    print "Download file size $file_remote is less than $file_size_big. will not download this file in the background\n" if $debug;
  }

  my $pid;
  #Download the new file
  DOWNLOAD: {

    if ($fork and $debug == 0) {
      $pid = fork && next FILE;
      close STDOUT;
      close STDIN;
      close STDERR;
    }

    my $cmd_curl_dl = qq#curl_cli -k "$url$file_remote" -o "$file_local" 2>&1#;
    print "CMD: $cmd_curl_dl\n" if $debug;

    my $out_curl_dl = `$cmd_curl_dl`;
    validate_data($out_curl_dl, "curl file download") || next;
  }

  if ($fork and $pid)  {
    print "\$fork is true and $pid is true. Next\n" if $debug;
    next FILE;
  }

  if ($fork and not $pid) {
    print "\$fork is true and $pid is true. Next\n" if $debug;
    exit;

  }

  print "File is downloaded\n" if $debug;

  #Check if the local file is downloaded
  unless (-f $file_local){
    print "Need a human here. Could not find the downloaded file $file_local";
    next;
  }

  #Print back to zabbix
  print "$file_remote\n";

  #Make the script executable
  if ($file_local =~ /\.pl$|\.sh$/){
    system "chmod +x $file_local";
  }
}

sub get_url {
  my $url = shift || die "Need a human here. Need a URL to download from";

  #Run the command fw ver to get the installed version
  my $fw = `fw ver`;
  unless ($fw =~ /software version/){
    print "Need a human here. Could not get FW version from fw ver";
    exit;
  }

  #Get the Check Point version from fw ver
  my ($ver) = $fw =~ / version (.*?) /;
  unless ($ver){
    print "Need a human here. Could not extract FW version from fw ver";
    exit;
  }

  #Lowercase the version (the R)
  $ver = lc $ver;

  #The URL for the repo
  $url =~ s/__VER__/$ver/g;

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

