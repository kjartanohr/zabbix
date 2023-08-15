#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

use warnings;
use strict;

$0 = "perl Check Point debug script VER 100";
$|++;

zabbix_check($ARGV[0]);



my  $vsid           = use_vsid();
my  $dir_tmp        = "/tmp/zabbix/NAME/$vsid/";
our $file_debug     = "$dir_tmp/debug.log";
our $debug          = 1;
my  $dry_run        = 0; 
my  $clear          = `clear`;
my  %debug_list     = (
  clusterxl     => "ClusterXL debug",
  fw_drop       => "fw drop debug",
);

create_dir($dir_tmp);

#Delete log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);

#End of standard header


#Eveything after here is the child

print "Script starting\n";

#START OF MAIN SCRIPT

sub debug_clusterxl {

  ask(
    "This will start ClusterXL debug\n",
    answer  => "Y",
    clear   => 1,
  );

  run(
    "cphaprob state",
    pause         => 1, 
    clear         => 1,
    #stop_if_found => "HA module not started",
    stop_msg      => "No ClusterXL found on this installation",
  );

  run(
    "fw ctl pstat", 
    pause => 1, 
    clear => 1
  );

  run(
    "cpstat fw -f sync", 
    pause => 1, 
    clear => 1
  );

  run(
    "fw ctl debug 0", 
    pause => 1, 
    clear => 1,
    ask => "This will disable all debug"
  );
}

#END OF MAIN SCTIPT

sub run {
  my $cmd                       = shift || die "Did not get any CMD";
  my %input                     = @_;
  my $cmd_out;

  $input{'pause'}             ||= 0;
  $input{'ask'}               ||= 0;
  $input{'timeout'}           ||= 10;
  $input{'stop_if_found'}     ||= "";
  $input{'stop_if_not_found'} ||= "";
  $input{'stop_msg'}          ||= "";
  $input{'print'}             ||= 1;

  print $clear if $input{'clear'};

  if ($input{'ask'}) {
    my $msg = "$input{'ask'}\n";

    ask(
      $msg,
      answer  => "Y",
      print   => 1,
    );
  }


  if ($dry_run == 0) {
    eval {
      local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
      alarm $input{'timeout'};

      $cmd_out = `$cmd`;

      alarm 0;
    };
  }

  if ($input{'print'}) {
    print "Running command: \"$cmd\" with timeout: $input{'timeout'}\n\nCMD START\n$cmd_out\nCMD END\n\n";
  }

  if ($input{'stop_if_found'}) {
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

  pause() if $input{'pause'};
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

  print $clear if $input{'clear'};

  
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

sub use_vsid {

  get_all_vs();

  my $answer = ask(
    "What VSID do you want to run this debug on",
    clear   => 1,
    pause   => 1,
  );


}

