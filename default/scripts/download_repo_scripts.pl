#!/bin/perl
#bin

if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}


#Run the command fw ver to get the installed version
my $fw = `fw ver`;
unless ($fw =~ /software version/){
  print "Could not get FW version from fw ver";
  exit;
} 

#Get the Check Point version from fw ver
my ($ver) = $fw =~ / version (.*?) /;
unless ($ver){
  print "Could not extract FW version from fw ver";
  exit;
} 

#Lowercase the version (the R)
$ver = lc $ver;

#The URL for the repo
my $url = "http://zabbix.kjartanohr.no/zabbix/repo/$ver/scripts/auto/";

#The local repo directory
my $dir_local = "/usr/share/zabbix/repo/scripts/auto/";

#Creato local repo directory if it does not exist
system "mkdir -p $dir_local/ &>/dev/null";

#Curl command to run
my $curl = `curl_cli -k -s $url`;

#for loop for the HTML from curl
foreach (split/\n/, $curl){
  #Skip the line if is does not contain a URL
  next unless /<a href="/;
  #Skip if the URL destination is same og parent dir
  next if /C=D;O=A|PARENTDIR/;

  #URL for a file
  my ($file_remote) = /<a href="(.*?)">/;

  #Modified time for the file
  my ($file_remote_mtime) = /align="right">(.*?) </;

  #Convert remote modified time to unix sec
  chomp($file_remote_mtime = `date "+%s" -d "$file_remote_mtime"`);

  #A complete path for the file
  $file_local = $dir_local.$file_remote;

  #Get the modified time of the local file
  $file_local_mtime = (stat($file_local))[9];

  #Get the remote file size
  my $file_remote_header = `curl_cli -k -I $url$file_remote 2>&1`;
  my ($file_remote_size) = $file_remote_header =~ /Content-Length: (\d{1,})/;

  if (-f $file_local) {
    #Get the size of the local file
    $file_local_size = (stat($file_local))[7];

    my $download_again = 0;
    #Check if file size of local and remote is the same
    unless ($file_remote_size eq $file_local_size) {
    $download_again = 1;
    }

    #If the local and remote modified time is the same, skip this URL/file
    if ( ($file_local_mtime > $file_remote_mtime) and not $download_again){
      next
    };

    #Move the old file from name to name.old
    system "mv -f $file_local $file_local.old &>/dev/null";
  }

  #Download the new file
  #DOWNLOAD: {
  #  #fork && last DOWNLOAD;
  #  close STDOUT;
  #  close STDIN;
  #  close STDERR;

    my $curl_dl = `curl_cli -k -s $url$file_remote -o $file_local &>/dev/null &`;
  #}

  #Check if the local file is downloaded
  #unless (-f $file_local){
  #  print "Could not find the downloaded file $file_local";
  #  exit;
  #} 

  #Print back to zabbix 
  print "$file_remote\n";

  #Make the script executable
  if ($file_local =~ /\.pl$|\.sh$/){
    sleep 1;
    system "chmod +x $file_local";
  }
}
