#!/bin/perl
#bin

if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}


my $user;
my $ssh_key;

print "Please answer all the questions\n\n";

if (is_checkpoint()) {
  $user = "admin";
  print "This is a Check Point installation, will use the user admin\n";
}

unless ($user) {
  $login_user = get_login_user();
  $user = ask("What user to you wish to run ssh from on this computer?: ($login_user) ",$login_user);
}


unless (user_exists($user)){
  print "Could not find the user $user in /etc/passwd. Abort\n";
  system "cat /etc/passwd";
  exit; 
}

my $home = get_user_directory($user);
unless ($home){
  $home = ask("Could not get home directory from /etc/passwd. Please type in directory: ");
}

unless (-d $home) {
  $home = ask("Could not find the home directory for user $user: $home. Please type in directory: ");
}


my $remote_server = ask("What server do you wish to auto-login to? (Add ssh keys from this computer to the remote): ");
my $remote_user = ask("What user to do wish to login with on the remote server: ");

print "Local user: $user\nRemote user $remote_user\nRemote host $remote_server\n\n";
$continue = ask("Do you wish to continue? (Y/n)","y");
exit unless $continue =~ /y/i;

my $answer_keygen = ask("Do you wish to run ssh-keygen? If you are not sure, run it (Y/n) ","y");
if ($answer_keygen =~ /y/i){
  print "Running ssh-keygen\n";
  $ssh_key = ssh_keygen($user,$home);

}
else {
  if (-f "$home/.ssh/id_rsa.pub") {
    chomp($ssh_key =`cat $home/.ssh/id_rsa.pub`); 
  }
  else {
    print "Could not get id_rsa.pub. Aborting\n";
    exit;
  }
}

ssh_remote_server($remote_user,$remote_server,"mkdir .ssh; echo -n \"\n$ssh_key\" >>.ssh/authorized_keys; chmod -Rf 600 .ssh");


sub is_checkpoint {
  return 1 if `fw ver` =~ /This is Check Point/;
}

sub user_exists {
  my $input = shift || die "Need a username to check";
  foreach (`cat /etc/passwd`){
    @s = split/:/;
    return 1 if $s[0] eq $input;
  }

  return 0;
}

sub get_user_directory {
  my $input_user = shift || die "Need a username to check";

  foreach (`cat /etc/passwd`){
    @s = split/:/;
    return $s[5] if $s[0] eq $input_user;
  }

  return 0;
   
}

sub ask {
  my $question  = shift || die "Need a question to ask";
  my $default   = shift || 0;
  my $no_check  = shift || 0;

  my $max_tries = 3;

  foreach (1 .. $max_tries) {
    print "$question";
    chomp (my $answer = <>);

    if ($answer =~ /^$/ and $default){
      return $default;
    }

    return $answer if $no_check;
    
    if ($answer) {
      print qq#You answered "$answer". Is this correct? (Y/n): #;
      chomp (my $answer_correct = <>);
      
      return $answer if $answer_correct =~ /^y$/i;
      return $answer if $answer_correct =~ /^$/;

      print "Will ask the same question again\n";
      next;

    }
    else {
      print "You did not answer correctly. This is try $_/$max_tries\n";
      next;
    
    }
  }

  print "Giving up. Exiting\n";
  exit;
  
}

sub ssh_keygen {
  my $input_user = shift || die "Need a user to create ssh keys";
  my $input_home = shift || die "Need a home directory to create ssh keys";
  my $cmd;
  my $key;

  
  if (-d "$input_home/.ssh_old") {
    ask("Found $input_home/.ssh_old. Do you wish to delete the old .ssh directory? Press CTRL+C to stop (Y/n): ","y");
    $cmd = qq#rm -Rf $input_home/.ssh_old"#;
    print "$cmd\n";
    system $cmd;
  }

  if (-d "$input_home/.ssh/") {
    ask("Found $input_home/.ssh. Do you wish to move the .ssh directory to .ssh_old? Press CTRL+C to stop. (Y/n): ","y");
    $cmd = qq#mv -f $input_home/.ssh/ $input_home/.ssh_old#;
    print "$cmd\n";
    system $cmd;
  }

  unless (-d "$input_home/.ssh/") {
    print "Could not find the directory $input_home/.ssh/. Will create it\n";
    $cmd = qq#mkdir "$input_home/.ssh/"#;
    print "$cmd\n";
    system $cmd;
  }

  my $cmd = qq#ssh-keygen -f $input_home/.ssh/id_rsa -P ""#;
  print "$cmd\n";
  system $cmd;

  $cmd = "chmod -Rf 600 $input_home/.ssh/";
  print "$cmd\n";
  system $cmd;

  if (-f "$input_home/.ssh/id_rsa.pub") {
    print "Found the ssh public key\n";
    $key = `cat $input_home/.ssh/id_rsa.pub`;
  }
  else {
    print "Could not find the ssh public key. Something is wrong. Abort\n";
    exit;
  }

  return $key;
}


sub ssh_remote_server {
  my $input_user = shift || die "Need a username to ssh";
  my $input_host = shift || die "Need a host to ssh";
  my $input_cmd  = shift || die "Need a CMD to ssh";

  ask("We will now SSH to the remote server. Are you ready? (Y/n) ","y");

  my $cmd = qq#ssh $input_user\@$input_host '$input_cmd'#;
  print "$cmd\n";
  system $cmd;
    
}

sub get_login_user {
  return $ENV{'USER'};
}
