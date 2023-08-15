#!/usr/bin/perl5.32.0
#bin
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";

  #Zabbix health check
  zabbix_check($ARGV[0]) if defined $ARGV[0] and $ARGV[0] eq "--zabbix-test-run";
}

use warnings;
no warnings qw(redefine);
use strict;
use File::Copy;

my $dir_backup     = "/var/log/backup_script/";
my $dir_tmp        = "/tmp/zabbix/backup_script";
our $file_debug    = "$dir_tmp/debug.log";
our $debug         = 1;

if (-d $dir_backup){
  die "backup folder found. Delete it first: $dir_backup\n";
}

my %vs = get_all_vs_v0();

create_dir($dir_tmp);
create_dir($dir_backup);

#Delete log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);


my $date = get_date();

my $hostname = get_hostname();

my @cmds = (
  "cp -rfv /home/ $dir_backup",
  "cp -rfv /root/ $dir_backup",
  "cp -rfv /etc/ $dir_backup",
  "free -m",
  "df -h",
  "ip route",
  "ifconfig -a",
  "ip a",
  "uname -a",
  "cat /proc/cpuinfo",
  "find / 2>/dev/null",
  "ps xauww",
  "top -b -n1",
  "cpview -p",
  "clish -c \"show configuration\"",
  "cplic print",
   "cat \$FWDIR/lib/table.def",
  "enabled_blades",
);

my @files = (
  "*.conf",
  "bashrc",
  "rc.local",
  "*.elg",
  "*.def",
  "user.def",
  "table.def",
  "tabel.def.FW1",
  "crypt.def",
  "fwkern.conf",
  "trac_client_1.ttm",
  "ipassignment.conf",
   "discntd.if",
);

my @cmds_vs = (
  "ip route",
  "ip a",
  "ifconfig",
  "arp -na",
  "enabled_blades",
  "cpview -p",
  "cp -rfv \$FWDIR/conf/ $dir_backup/_VSNAME_/",
);

if (is_mgmt()) {
  print "This is a MGMT host, will run cpinfo for MGMT\n";
  start_cpinfo_mgmt();
}

if (is_vsx()) {
  print "This is a VSX host, will run cpinfo for VSX\n";
  start_cpinfo_gw();
}

foreach my $vsid (keys %vs){
  my $vsname = $vs{$vsid};

  print "ID $vsid name $vsname\n";

  print "Creating directory $dir_backup/$vsname\n";
  mkdir "$dir_backup/$vsname";

  foreach my $cmd_org (@cmds_vs){
    next unless $cmd_org;
    my $cmd = $cmd_org;

    if ($cmd =~ /_VSID_/){
      print "Found _VSNAME_ in \"$cmd\"\n";
      $cmd =~ s/_VSNAME_/$vsname/g;
      print "Changed to \"$cmd\"\n";
    }

    my $out = `cd $dir_backup ; source /etc/profile.d/vsenv.sh; vsenv $vsid &>/dev/null ; $cmd`;
    print "$cmd\n";

    my $filename = $cmd;
    $filename =~ s/\W/_/g;
    $filename =~ s/_{2,}//g;

    save_file("$dir_backup/$vsname/$filename", $out);
  }

}




foreach my $file (@files) {
  my $dir = $file;
  $dir =~ s/\W/_/g;
  $dir =~ s/_{2,}//g;
  $dir =~ s/^_{1,}//;
  mkdir "$dir_backup/$dir";

  foreach my $line (`find / -iname "$file" 2>/dev/null`){
    chomp $line;

    #Slip jails
    next if $line =~ /\/jail\//;

    my ($filename) = $line =~ /.*\/(.*)/;

    my $filename_safe = $line;
    $filename_safe =~ s/\W/_/g;
    $filename_safe =~ s/_{2,}//g;
    #$filename_safe =~ s/^_{1,}//;

    next if $line =~ /$dir_backup/;

    #system qq#cp -v "$line" $dir_backup/$dir#;
    print "$line -> $dir_backup/$dir/$filename_safe-$filename\n";
    copy("$line", "$dir_backup/$dir/$filename_safe-$filename");
  }
}

foreach my $cmd (@cmds){
  next unless $cmd;

  print $cmd."\n";
  my $out = `cd $dir_backup ; $cmd`;

  my $filename = $cmd;
  $filename =~ s/\W/_/g;
  $filename =~ s/_{2,}//g;
  $filename =~ s/^_{1,}//;

  save_file("$dir_backup/$filename", $out);
}

#system "tar vcfz /var/log/backup.tar.gz $dir_backup";
system "tar -c $dir_backup | gzip --best >/var/log/backup.tar.gz";

rename "/var/log/backup.tar.gz", "/var/log/backup-$hostname-$date.tar.gz";

print "/var/log/backup-$hostname-$date.tar.gz\n";

system "rm -Rf $dir_backup";

sub save_file {
  my $file = shift;
  my $data = shift;

  open my $fh_w,">", $file or warn "Can't write to $file: $!";
  print $fh_w $data;
  close $fh_w;

}


sub get_all_vs_v0 {
  my %return;

  my $hostname = get_hostname();
  $return{0} = $hostname;

  foreach (run_cmd('vsx stat -v', 'a', 600)){
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
    foreach my $vsid (keys %vs){
      my $cmd = "cd $dir_backup/ ; source /etc/profile.d/vsenv.sh; vsenv $vsid&>/dev/null && cpinfo -i -D -z -o $hostname-VSID-$vsid-VSNAME-$vs{$vsid}-$date\n";
      run_cmd($cmd);
    }
  }
}

sub start_cpinfo_mgmt {

  run_cmd("cd $dir_backup/ ; cpinfo -i -d -D -z");

}

