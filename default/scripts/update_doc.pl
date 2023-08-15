#!/usr/bin/perl5.32.0
#bin
BEGIN{

  #init global pre checks
  #init_local_begin('version' => 1);

  #Global var
  our %config;

  require "/usr/share/zabbix/repo/files/auto/lib.pm";
  #require "./lib.pm";

  #Zabbix health check
  zabbix_check($ARGV[0]) if defined $ARGV[0] and $ARGV[0] eq "--zabbix-test-run";


  #init global pre checks
  init_global_begin('version' => 1);
}

#TODO

#Changes

#BUGS

#Feature request

use warnings;
no warnings qw(redefine);
use strict;
use JSON;
use File::Copy;
use Digest::MD5 ("md5");

$0 = "perl update doc VER 100";
$|++;
$SIG{CHLD} = "IGNORE";

our $debug            = 3;                                                            #Set to 1 if you want debug data and no fork
our $info             = 0;
our $warning          = 1;
our $error            = 1;
our $fatal            = 1;

my  $dir_tmp        = "/tmp/zabbix/update_doc";
our $file_debug     = "$dir_tmp/debug.log";
my  $fork           = 0;

create_dir($dir_tmp);

my $json_string     = `/usr/share/zabbix/repo/scripts/auto/vsx_discovery.pl`;
debug("JSON string: $json_string", "debug", \[caller(0)] ) if $debug;
my $vsid            = json_to_hash('json_string' => $json_string); 

my %tmp;

#Delete log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);

my $hostname = get_hostname();

my $date = get_date();

my @cmds = (
  #"cp -rfv /home/ $dir_tmp",
  #"cp -rfv /root/ $dir_tmp",
  #"cp -rfv /etc/ $dir_tmp",
  "free -m",
  "df -h",
  "ip route",
  "ifconfig -a",
  "/sbin/ifconfig -a",
  "ip a",
  "uname -a",
  "cat /proc/cpuinfo",
  "find / 2>/dev/null >find.log",
  "tar cfz find.log.tar.gz find.log",
  "ps xauww",
  "top -b -n1",
  "cpview -p",
  'clish -c "show configuration"',
  "cplic print",
  "cplic print -x",
  #"cat \$FWDIR/lib/table.def",
  "enabled_blades",
  'cpinfo -y all',
);

my @files = (
  '\.conf$',
  '\.def$',
  '\.ttm$',
  '\.C$',

  '\.pl$',
  '\.sh$',

  "bashrc",
  "rc.local",
  #"*.elg",
  #"*.log",
  'user.def$',
  'table.def',
  "tabel.def.FW1",
  'crypt.def',
  "fwkern.conf",
  "trac_client_1.ttm",
  "ipassignment.conf",
  "discntd.if",

   #State data
   '\/state\/',
);

my @files_exclude = (
  "\.so",
  '\/tmp\/',
  '\/usr\/share\/zabbix',
  '\/metadata',
);

my @cmds_vs = (
  "ip route",
  "ip a",
  "ip nei",
  "ifconfig -a",
  "/sbin/ifconfig -a",
  "arp -na",
  "enabled_blades",
  "cpview -p",
  #"cp -rfv \$FWDIR/conf/ $dir_tmp/_VSNAME_/",
  #"cp -rfv \$FWDIR/lib/ $dir_tmp/_VSNAME_/",
  "fw ctl pstat",
  'clish -c "show configuration"',
  'cpinfo -y all',
  "cpinfo -i -D -z -o _HOSTNAME_-VSID-_VSID_-VSNAME-_VSNAME_-_DATE_",
);

if (is_mgmt()) {
  print "This is a MGMT host, will run cpinfo for MGMT\n";
  start_cpinfo_mgmt();
}

#if (is_vsx()) {
#  print "This is a VSX host, will run cpinfo for VSX\n";
#  start_cpinfo_gw();
#}

foreach my $vs (@{$$vsid{'data'}}){
  my $vs_id   = $$vs{'{#VSID}'};
  my $vs_name = $$vs{'{#VSNAME}'};
  my $vs_ip   = $$vs{'{#VS_IP}'};

  print "ID $vs_id name $vs_name. IP: $vs_ip\n";

  print "Creating directory $dir_tmp/$vs_name\n";
  mkdir "$dir_tmp/$vs_name";

  foreach my $cmd_org (@cmds_vs){
    next unless $cmd_org;
    my $cmd = $cmd_org;

    if ($cmd =~ /_VSNAME_/){
      print "Found _VSNAME_ in \"$cmd\"\n";
      $cmd =~ s/_VSNAME_/$vs_name/g;
      print "Changed to \"$cmd\"\n";
    }

    if ($cmd =~ /_VSID_/){
      print "Found _VSID_ in \"$cmd\"\n";
      $cmd =~ s/_VSID_/$vs_id/g;
      print "Changed to \"$cmd\"\n";
    }

    if ($cmd =~ /_HOSTNAME_/){
      print "Found _HOSTNAME_ in \"$cmd\"\n";
      $cmd =~ s/_HOSTNAME_/$hostname/g;
      print "Changed to \"$cmd\"\n";
    }

    if ($cmd =~ /_DATE_/){
      print "Found _DATE_ in \"$cmd\"\n";
      $cmd =~ s/_DATE_/$date/g;
      print "Changed to \"$cmd\"\n";
    }

    next unless defined $cmd and $cmd;

    my $out = run_cmd({
      'cmd'             => $cmd, 
      'return-type'     => 's', 
      'refresh-time'    => 24*60*60,
      'timeout'         => 6000,
      'dir-run'         => "$dir_tmp/$vs_name",
      'vsid'            => $vs_id,
    });


    print "$cmd\n";

    my $filename = $cmd;
    $filename =~ s/\W/_/g;
    $filename =~ s/_{2,}//g;

    save_file("$dir_tmp/$vs_name/$filename", $out);
  }

}


create_dir("$dir_tmp/files");


foreach my $file (@files) {
  my $dir = $file;
  $dir =~ s/\W/_/g;
  $dir =~ s/_{2,}//g;
  $dir =~ s/^_{1,}//;

  my $dir_dest = "$dir_tmp/files/$dir";
  create_dir($dir_dest);


  debug('run_cmd(find / 2>/dev/null", "a", 2*60*60)', "debug", \[caller(0)] ) if $debug;
  my @find = run_cmd('find / 2>/dev/null', "a", 2*60*60);
  FIND:
  foreach my $line (sort @find){
    chomp $line;

    #debug("$line =~ m/$file/i;", "debug", \[caller(0)] ) if $debug > 2;
    next unless $line =~ /$file/i;

    #Slip jails
    next FIND if $line =~ /\/jail\//;

    foreach my $file_exclude (@files_exclude) {
      next FIND if $file =~ /$file_exclude/i;
    }

    my ($filename) = $line =~ /.*\/(.*)/;

    my $filename_safe = $line;
    $filename_safe =~ s/\W/_/g;
    $filename_safe =~ s/_{2,}//g;
    #$filename_safe =~ s/^_{1,}//;

    my $filename_dest       = "$filename - $filename_safe";
    my $filename_dest_full  = "$dir_dest/$filename_dest";

    next unless -r $line;

    my $md5 = "";

    eval {
      my $ctx = Digest::MD5->new;
      open my $fh_r, "<", $line or die "Can't open $line: $!";
      $ctx->addfile($fh_r);
      $md5 = $ctx->digest;
    };

    if (defined $md5 and defined $tmp{'md5'}{$md5}){
      print "File md5 checksum is the same as the last file with the same filename: $filename. next FIND\n";

      open my $fh_w, ">", $filename_dest_full or die "Can't write to $filename_dest_full: $!";
      print $fh_w "This is the same as: $tmp{'md5'}{$md5}";
      close $fh_w;

      next FIND;
    }
    $tmp{'md5'}{$md5} = $filename_dest;

    next if defined $tmp{'file'}{$filename_dest};
    $tmp{'file'}{$filename_dest} = 1;

    next if -f $filename_dest_full;

    next if $line =~ /$dir_tmp/;

    #system qq#cp -v "$line" $dir_tmp/$dir#;
    print "$line -> $filename_dest_full\n";
    File::Copy::copy($line, $filename_dest_full);
  }

  system "tar cfzv $dir_dest.tar.gz $dir_dest";
  system "rm -Rfv $dir_dest";
}


create_dir("$dir_tmp/host");

foreach my $cmd (@cmds){
  next unless $cmd;

  my $filename = $cmd;
  $filename =~ s/\W/_/g;
  $filename =~ s/_{2,}//g;
  $filename =~ s/^_{1,}//;

  if ($cmd =~ /_FILE_/){
    print "Found _FILE_ in \"$cmd\"\n";
    $cmd =~ s/_FILE_/$filename/g;
    print "Changed to \"$cmd\"\n";
  }


  print $cmd."\n";
  
  debug("run_cmd(): '$cmd'", "debug", \[caller(0)] ) if $debug;
  my $out = run_cmd({
    'cmd'             => $cmd, 
    'return-type'     => 's', 
    'refresh-time'    => 24*60*60,
    'timeout'         => 6000,
    'dir-run'         => "$dir_tmp/host",
  });


  save_file("$dir_tmp/$filename", $out);
}
system "tar vcfz ./update-doc.tar.gz $dir_tmp";
system "rm -Rfv $dir_tmp";

#system "tar vcfz /var/log/backup.tar.gz $dir_tmp";
#system "tar -c $dir_tmp | gzip --best >/var/log/backup.tar.gz";

#rename "/var/log/backup.tar.gz", "/var/log/backup-$hostname-$date.tar.gz";

#print "/var/log/backup-$hostname-$date.tar.gz\n";

#system "rm -Rf $dir_tmp";

sub save_file {
  my $file = shift;
  my $data = shift;

  return unless defined $data and $data;

  open my $fh_w,">", $file or warn "Can't write to $file: $!";
  print $fh_w $data;
  close $fh_w;

}


sub get_all_vs_v0 {
  my %return;

  my $hostname = get_hostname();
  $return{0} = $hostname;

  foreach (run_cmd('vsx stat -v', 'a', 24*60*60)){
    s/^\s*`?//;
    next unless /^\d/;
    my @split = split/\s{1,}/;

    next unless $split[2] eq "S";

    my ($vsname) = run_cmd("source /etc/profile.d/vsenv.sh; vsenv $split[0]", 's', 600) =~ /_(.*?) /;

    $return{$split[0]} = $vsname;
  }

  return %return;
}


sub is_mgmt {

  my $cmd_fwm = "fwm ver";
  my $out_fwm = run_cmd($cmd_fwm);

  return 1 if $out_fwm =~ /This is Check Point Security Management Server/;
  return 0;
  
}

sub get_date {
  chomp (my $date = `date +"%Y-%m-%d"`);
  return $date;
}

sub get_date_time {
  chomp (my $date = `date +"%Y-%m-%d_%H:%M:%S"`);
  return $date;
}



sub start_cpinfo_gw {

my $run_cpinfo = 1;

eval {
  local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
  alarm 5;
  print "Will now run a cpinfo on alle VS. Will wait 5 sec for the answer. To skip this type N and ENTER: \n";
  chomp (my $answer = <>);
  alarm 0;

  if ($answer eq "N") {
      $run_cpinfo = 0;
      print "Will not run cpinfo\n";
    }
  };
  
  
  if ($run_cpinfo) {
    foreach my $vsid (keys %{$vsid}){
      my $cmd = "";
      #my $cmd = "cd $dir_tmp/ ; source /etc/profile.d/vsenv.sh; vsenv $vsid&>/dev/null && cpinfo -i -D -z -o $hostname-VSID-$vsid-VSNAME-$$vsid{$vsid}-$date\n";
      run_cmd($cmd);
    }
  }
}

sub start_cpinfo_mgmt {

  my $out = run_cmd({
  'cmd'             => "cpinfo -i -d -D -z", 
  'return-type'     => 's', 
  'refresh-time'    => 6000,
  'timeout'         => 6000,
  'dir-run'         => $dir_tmp,
});



}
