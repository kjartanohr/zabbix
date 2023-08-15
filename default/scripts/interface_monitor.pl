#!/usr/bin/perl5.32.0
BEGIN {
  #require "./lib.pm";  #For local lib dev testing
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

#TOOD

#Change log
#2022.02.15
# Cleanup




use warnings;
use strict;
use Storable;
use Data::Dumper;
use JSON::MaybeXS;
use Data::Dumper;

my $old_name              = $0;
my $version               = 103;
my $process_name          = "perl Interface monitor VER";
$0                        = "$process_name $version";
$SIG{CHLD}                = "IGNORE";
$SIG{INT}                 = \&ctrl_c;                                           #Catch CTRL+C and run sub ctrl_c. print stats, save cache to file and exit
$|++;


#Rename debug subrutine
#no strict 'refs';
#*{__PACKAGE__. "::debug"} = \&{'debug_v2'} ;

#Debug data
our $debug                = 0;                                                  #This needs to be 0 when running in production
our $info                 = 0;
our $warning              = 9;
our $error                = 9;
our $fatal                = 9;

my  $dir_tmp              = "/tmp/zabbix/interface_monitor";
our $file_debug           = "$dir_tmp/debug.log";
my  $dir_stats            = "$dir_tmp/interface_stats";
my  $file_db              = "$dir_tmp/data.db";
my  $file_db_sessions     = "$dir_tmp/data_sessions.db";
my  $file_dev             = "/proc/net/dev";
my  $file_stats_max_size  = 100;                        #N KB

our %config                = get_config();

$config{'dir'}{'home'}    = $dir_tmp;

my %db;

#Zabbix health check
zabbix_check($ARGV[0]);

$config{'log'}{'default'}       = {
  "enabled"       => 0,     #0/1
  'name'          => 'default', 
  "level"         => 9,     #1-9
  "print"         => 1,     #Print to STDOUT
  "print-warn"    => 0,     #Print to STDERR
  "log"           => 0,     #Save to log file
  "file"          => "$config{'dir'}{'log'}/default.log", #Log file
  "file-fifo"     => 0,     #Create a fifo file for log
  "file-size"     => 10,    #MB max log file size
  "cmd"           => "",    #Run CMD if log. Variable: _LOG_
  "lines-ps"      => 10,    #Max lines pr second
  "die"           => 0,     #Die/exit if this type of log is triggered

  'mqtt'          => {
    "enabled"       => 0,     #0/1
    "level"         => 9,     #1-9
    "topic"         => 'rtl/log/default',
  },
};

$config{'log'}{'debug'}       = {
  "enabled"       => 0,     #0/1
  'name'          => 'debug', 
  "level"         => 9,     #1-9
  "print"         => 1,     #Print to STDOUT
  "print-warn"    => 0,     #Print to STDERR
  "log"           => 0,     #Save to log file
  "file"          => "$config{'dir'}{'log'}/debug.log", #Log file
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

$config{'log'}{'info'}       = {
  "enabled"       => 1,     #0/1
  'name'          => 'debug', 
  "level"         => 5,     #1-9
  "print"         => 1,     #Print to STDOUT
  "print-warn"    => 0,     #Print to STDERR
  "log"           => 1,     #Save to log file
  "file"          => "$config{'dir'}{'log'}/info.log", #Log file
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
  "file"          => "$config{'dir'}{'log'}/warning.log", #Log file
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
  "file"          => "$config{'dir'}{'log'}/error.log", #Log file
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
  "file"          => "$config{'dir'}{'log'}/fatal.log", #Log file
  "file-fifo"     => 0,     #Create a fifo file for log
  "file-size"     => 100*1024*1024,    #MB max log file size
  "cmd"           => "",    #Run CMD if log. Variable: _LOG_
  "lines-ps"      => 10,    #Max lines pr second
  "die"           => 1,     #Die/exit if this type of log is triggered

  'mqtt'          => {
    "enabled"       => 1,     #0/1
    "topic"         => 'rtl/log/__NAME__',
  },
};



#Delete file if bigger than 10 MB
delete_file_if_bigger_than_mb($file_db,10);
delete_file_if_bigger_than_mb($file_db_sessions,10);

create_dir($dir_tmp);
create_dir($dir_stats);

#Delete log file if it's bigger than 10 MB
debug("trunk_file_if_bigger_than_mb()", "debug", \[caller(0)] ) if $debug > 2;
trunk_file_if_bigger_than_mb($file_debug,10);





#End of standard header


#Eveything after here is the child

my %options = @ARGV;

if (defined $options{'--debug'}) {
  debug("if \$options{'--debug}", "debug", \[caller(0)] ) if $debug > 2;
  $debug = $options{'--debug'};
  debug("\$debug = $options{'--debug'}", "debug", \[caller(0)] ) if $debug > 1;
}

#Kill the daemon process
if ($options{'--kill'}) {
  debug("if \$options{'--kill}", "debug", \[caller(0)] ) if $debug > 2;

  debug("kill_daemon()", "debug", \[caller(0)] ) if $debug > 2;
  kill_daemon();
  exit;

}

#Start the daemon process
if ($options{'--daemon'}) {
  debug("if \$options{'--daemon'}", "debug", \[caller(0)] ) if $debug > 2;
  debug("run_daemon()", "debug", \[caller(0)] ) if $debug > 2;
  run_daemon();
  exit;
}

#Get interface stats
if ($options{'--interface'}) {
  debug("if \$options{'--interface'}", "debug", \[caller(0)] ) if $debug > 2;

  debug("get_stats()", "debug", \[caller(0)] ) if $debug > 2;
  my $data_stats = get_stats(
    'interface' => $options{'--interface'},
    'min'       => $options{'--min'},
    'direction' => $options{'--direction'},
    'type'      => $options{'--type'},
    'session'   => $options{'--session'},
  );

  #Validate output data
  if (defined $data_stats) {
    debug("Data returned from get_stats(): $data_stats", "debug", \[caller(0)] ) if $debug > 1;
    print $data_stats || 0;
  }
  else {
    debug("No data returned from get_stats(). Something is wrong", "error", \[caller(0)] ) if $error;
    print 0;
  }

  exit;

}

#Dump the stats database
if ($options{'--dumpdb'}) {
  my $db_ref;
  $db_ref          = retrieve($file_db) if -f $file_db;
  %db = %{$db_ref} if defined $db_ref and $db_ref;

  #print the database to STDOUT
  print Dumper %db;

  exit;
}

#Missing or invalid input data
help();
exit;


sub get_headers {
  debug("start", "debug", \[caller(0)] ) if $debug > 2;

  my $line        = shift;
  my $split_char  = shift || '\s{1,}';
  my %header;

  #Validate input
  unless (defined $line and $line) {
    debug("Missing input data 'line'. exit", "fatal", \[caller(0)] ) if $fatal;
    exit;
  }

  debug(((caller(0))[3])." Input \$line $line\n");
  debug(((caller(0))[3])." Input \$spliut_char $split_char\n");

  debug(((caller(0))[3])." foreach split /$split_char/\n");
  my $count = 0;

  foreach (split/$split_char/, $line) {

    $header{"count $count"}   = $_;
    $header{"name $_"}        = $count;

    $count++;
  }

  #Validate output
  unless (%header) {
    debug("Missing data from %header. exit", "fatal", \[caller(0)] ) if $fatal;
    exit;
  }


  debug("end", "debug", \[caller(0)] ) if $debug > 2;
  return %header;
}

#Catch CTRL+C and run sub ctrl_c. print stats, save cache to file and exit
sub ctrl_c {
  debug(((caller(0))[3])." Start\n");

  debug(((caller(0))[3])." Exiting script\n");

  if (defined $options{'--daemon'}) {
    debug(((caller(0))[3])." Saving cache to file\n");
    store \%db, $file_db 
  }

  exit;
}

#Code the daemon script
sub daemon {
  debug(((caller(0))[3])." Start\n");

  #Try to fetch the data from file
  eval {
    my $db_ref;
    $db_ref          = retrieve($file_db) if -f $file_db;
    %db = %{$db_ref} if defined $db_ref;
  };

  #Check for eval error
  if ($@) {
    debug(((caller(0))[3])." Something went wrong when opening database file: $@\nWill delete database file and exit");
    unlink $file_db;
  }

  $db{'internal'}{'save_time'} = time;

  my %input = @_;
  $input{'refresh'} ||= 2;
  $input{'history'} ||= 60;
  $input{'save'}    ||= 1;

  #Default is VS 0
  my @vrf = (0);

  if (is_vsx()) {
    #@vrf = run_cmd("vrf list vrfs","a");
    @vrf = get_all_vs_id();
  }


  #Main loop for the daemon code START
  while (1) {
    my $time = time;

    #Save data START
    if ( ($time - $db{'internal'}{'save_time'}) > $input{'save'}*60) {
      debug(((caller(0))[3])." It's time to save to file\n");
      $db{'internal'}{'save_time'} = time;
      save_to_file();

      foreach my $int (keys %db) {

        my $stats;
        my $filename = "$dir_stats/$int.txt";

        if (-f $filename and -s $filename > ($file_stats_max_size*1024)) {
          debug(((caller(0))[3])." $filename is bigger than $file_stats_max_size KB\n");
          $stats = `tail -n10 $filename`;
          open my $fh_w_stats, ">", $filename or die "Can't write to $filename: $!";
          print $fh_w_stats $stats;
          close $fh_w_stats;
        }
        #print Dumper %db;

        open my $fh_w_stats, ">>", $filename or die "Can't write to $filename: $!";

        foreach my $direction (qw(receive transmit)) {

          foreach my $stat_type (qw(min max)) {

            foreach my $type (qw(bytes packets errors drops)) {

              #print "$int $direction stats $type $stat_type\n";
              #next unless exists $db{$int}{$direction}{'stats'}{$stat_type}{$type};
              #next unless $db{$int}{$direction}{'stats'}{$stat_type}{$type};
              print $fh_w_stats time.",,,$int,,,$direction,,,$stat_type,,,$type,,,".$db{$int}{$direction}{'stats'}{$stat_type}{$type}."\n";
              #
              #Reset old stats
              #debug(((caller(0))[3])." Resetting stats\n");
              $db{$int}{$direction}{'stats'}{$stat_type}{$type} = undef;
            }
          }
        }
        close $fh_w_stats;
      }

    }
    #Save data END

    #open my $fh_r, "<", $file_dev or die "Can't open $file_dev: $!";
    #my @dev = <$fh_r>;
    #close $fh_r;

    my $file_dev_out;

    #Foreach VRF START
    foreach my $vrf (@vrf) {
      chomp $vrf;
      debug("foreach \@vrf: $vrf", "debug", \[caller(0)] ) if $debug > 2;


      if ($vrf == 0) {
        $file_dev_out = readfile($file_dev);
        #$cmd_cat_dev = "cat /proc/net/dev";
      }
      else {
        my $vrf_name_number = sprintf("%05d", $vrf);
        my $vrf_name        = "CTX".$vrf_name_number;

        my $cmd_ip          = "ip netns exec $vrf_name cat $file_dev";
        debug("\$cmd_ip: '$cmd_ip'", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

        my $cmd_ip_out       = `$cmd_ip`;
        $file_dev_out       .= $cmd_ip_out."\n";
        debug("\$cmd_ip_out: '$cmd_ip_out'", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

        #$file_dev_out = "source /etc/profile.d/vsenv.sh; vsenv $vrf &>/dev/null ; cat $file_dev";
      }
    }
    #Foreach VRF END


    #foreach network stats START
    foreach my $line (split/\n/, $file_dev_out) {
      debug("\$line: '$line'", 'debug', \[caller(0)]) if $config{'log'}{'debug'}{'enabled'} and $config{'log'}{'debug'}{'level'} > 1;

      $line =~ s/^\s{1,}//;
      $line =~ s/\|//g;
      $line =~ s/:/ /;

      #my @headers;
      #if ($line =~ /^face/) {
      #  #face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
      #  @headers = split/\s{1,}/, $line;
      #  next;
      #}

      next if $line =~ /^Inter/;
      next if $line =~ /^face/;

      #$line =~ s/^.*?://;
      $line =~ s/^\s{1,}//;

      my @data = split/\s{1,}/, $line;

      my $zero = 1;
      foreach (@data) {
        next unless /^\d*$/;
        $zero = 0 if $_ > 0;
      }
      if ($zero) {
        #debug("Skipping this line. All values are zero: $line\n");
        next;
      }

      my $int       = $data[0];

      #Move old now to last
      foreach my $direction (qw(receive transmit)) {
        $db{$int}{$direction}{'last'}{'time'} = $db{$int}{$direction}{'now'}{'time'};

        foreach my $type (qw(bytes-tot packets-tot errors-tot drops-tot)) {
          $db{$int}{$direction}{'last'}{$type} = $db{$int}{$direction}{'now'}{$type} || 0;
        }
        #delete $db{$int}{$direction}{'now'};
      }

      $db{$int}{'receive'}{'now'}{'bytes-tot'}   = $data[1];
      $db{$int}{'receive'}{'now'}{'packets-tot'} = $data[2];
      $db{$int}{'receive'}{'now'}{'errors-tot'}  = $data[3];
      $db{$int}{'receive'}{'now'}{'drops-tot'}   = $data[4];
      $db{$int}{'receive'}{'now'}{'time'}        = $time;

      $db{$int}{'transmit'}{'now'}{'bytes-tot'}   = $data[9];
      $db{$int}{'transmit'}{'now'}{'packets-tot'} = $data[10];
      $db{$int}{'transmit'}{'now'}{'errors-tot'}  = $data[11];
      $db{$int}{'transmit'}{'now'}{'drops-tot'}   = $data[12];
      $db{$int}{'transmit'}{'now'}{'time'}        = $time;

      unless ($db{$int}{'transmit'}{'last'}{'time'}) {
        debug(((caller(0))[3])." Could not find time in last. Skipping\n");
        next;
      }


      #Calculate diff from last and now
      foreach my $direction (qw(receive transmit)) {

        foreach my $type (qw(bytes packets errors drops)) {

          $db{$int}{$direction}{'last'}{"$type-tot"} = $db{$int}{$direction}{'now'}{"$type-tot"} unless $db{$int}{$direction}{'last'}{"$type-tot"};

          die "Could not find time in $int $direction $type" unless $db{$int}{$direction}{'last'}{'time'};


          my $diff_data   = ($db{$int}{$direction}{'now'}{"$type-tot"} - $db{$int}{$direction}{'last'}{"$type-tot"} );
          my $diff_time   = (time - $db{$int}{$direction}{'last'}{'time'});

          $diff_time = 1 unless $diff_time;

          print "Diff data $diff_data\n" if $debug;
          print "Diff time $diff_time\n" if $debug;

          $db{$int}{$direction}{'now'}{$type} = int($diff_data / $diff_time);
          debug("$int $direction $type ".$db{$int}{$direction}{'now'}{$type}."\n");
        }
      }



      #Stats
      foreach my $direction (qw(receive transmit)) {

        foreach my $stat_type (qw(min max)) {

          foreach my $type (qw(bytes packets errors drops)) {

            unless (defined $db{$int}{$direction}{'stats'}{$stat_type}{$type}) {
              debug("No value found for $stat_type. Setting value to current value\n");
              $db{$int}{$direction}{'stats'}{$stat_type}{$type} = $db{$int}{$direction}{'now'}{$type};
              next;
            }

            if ($stat_type eq "max" and $db{$int}{$direction}{'now'}{$type} > $db{$int}{$direction}{'stats'}{$stat_type}{$type}) {
              debug("New $stat_type value found for $int $direction $type. $db{$int}{$direction}{'now'}{$type} > $db{$int}{$direction}{'stats'}{$stat_type}{$type}\n");
              $db{$int}{$direction}{'stats'}{$stat_type}{$type} = $db{$int}{$direction}{'now'}{$type};
              $db{$int}{$direction}{'stats'}{$stat_type."_time"}{$type} = $time;
            }

            if ($stat_type eq "min" and $db{$int}{$direction}{'now'}{$type} < $db{$int}{$direction}{'stats'}{$stat_type}{$type}) {
              debug("New $stat_type value found for $int $direction $type. $db{$int}{$direction}{'now'}{$type} < $db{$int}{$direction}{'stats'}{$stat_type}{$type}\n");
              $db{$int}{$direction}{'stats'}{$stat_type}{$type} = $db{$int}{$direction}{'now'}{$type};
              $db{$int}{$direction}{'stats'}{$stat_type."_time"}{$type} = $time;
            }

            #$db{$int}{$direction}{'history'}{$time}{$type} = $db{$int}{$direction}{'now'}{$type} if $db{$int}{$direction}{'now'}{$type} > 0;
          }
        }
      }



      #foreach my $direction ("receive", "transmit") {
      #  foreach my $key (keys %{$db{$int}{$direction}{'history'}}) {
      #    if ( ($time - $key) > ($input{'history'}* 60) ) {
      #      debug("Found history older than $input{'history'} min. Deleting from hash\n");
      #
      #      delete $db{$int}{$direction}{'history'}{$key};
      #    }
      #  }
      #}

    }
    #foreach network stats END
    
    debug("sleep $input{'refresh'}", "debug", \[caller(0)] ) if $debug > 2;
    sleep $input{'refresh'};
  }
  #Main loop for the daemon code END

}

#Save hash to file
sub save_to_file {
  debug(((caller(0))[3])." Start\n");
  store \%db, $file_db;
}

sub get_stats {
  debug(((caller(0))[3])." Start\n");
  my $time = time;

  my %input = @_;

  $input{'interface'} || die "Need a interface to check\n";
  $input{'direction'} ||= "receive";
  $input{'type'}      ||= "max";
  $input{'data'}      ||= "bytes";
  $input{'min'}       ||= 10;
  $input{'session'}   ||= "";

  debug(((caller(0))[3])." Input. interface: $input{'interface'}, direction: $input{'direction'}, type: $input{'type'}, data: $input{'data'}, minutes: $input{'min'}, session: $input{'session'}\n");

  #die "Wrong input: $input{'interface'}"  unless exists $db{$input{'interface'}};
  die "Wrong input: $input{'direction'}"  unless validate_input($input{'direction'},"receive","transmit");
  die "Wrong input: $input{'type'}"       unless validate_input($input{'type'},"min","max");
  die "Wrong input: $input{'min'}"        unless validate_input($input{'min'},1..60);

  my %db_sessions;
  eval {
    my $db_sessions_ref;
    $db_sessions_ref  = retrieve($file_db_sessions) if -f $file_db_sessions;
    %db_sessions = %{$db_sessions_ref}              if defined $db_sessions_ref;
  };
  if ($@) {
    debug(((caller(0))[3])." Something went wrong when opening database file: $@\nWill delete database file and exit");
    unlink $file_db_sessions;
  }



  if ($input{'session'}) {
    debug(((caller(0))[3])." Found session in input: $input{'session'}\n");

    my $sess_time_ref = \$db_sessions{'sessions'}{$input{'session'}}{$input{'interface'}}{$input{'direction'}}{$input{'type'}}{$input{'data'}}{'time_last_check'};

    if (${$sess_time_ref}) {
      my $session_time        = ${$sess_time_ref};
      my $session_time_human = get_date('time' => $session_time);

      debug(((caller(0))[3])." Found session in hash. Last timestamp is $session_time $session_time_human \n");
      my $seconds_sine_last_check = ($time - $session_time);

      ${$sess_time_ref} = $time;

      debug(((caller(0))[3])." it's $seconds_sine_last_check seconds since last check with this session\n");

      if ($seconds_sine_last_check < 60) {
        debug(((caller(0))[3])." This is less than 60 seconds. Setting input minutes to 2 min\n");
        $input{'min'} = 2;
      }
      else {
        $input{'min'} = int ($seconds_sine_last_check / 60);
        debug(((caller(0))[3])." This is more than 60 seconds. setting min to time/60: $input{'min'}\n");
      }

    }
    else {
      debug(((caller(0))[3])." This is a new session. Setting last check timestamp to $time\n");
      ${$sess_time_ref} = $time;
    }

  }

  my $return;
  my @values;
  my $data_count = 0;
  my $last_count;

  debug(((caller(0))[3])." Opening directory $dir_stats\n");
  opendir my $dh_r, $dir_stats or die "Can't open $dir_stats: $!";

  my $file_int_stats;
  foreach (readdir $dh_r) {
    next if /^\.$/;
    next if /^\.\.$/;

    next unless $_ eq "$input{'interface'}.txt";

    $file_int_stats = $_;
    debug(((caller(0))[3])." Found file $file_int_stats\n");
    last;
  }
  closedir $dh_r;

  #Validate the interface START
  unless (defined $file_int_stats and $file_int_stats) {
    debug("Unknown interface. Could not find stats for this interface: '$input{'interface'}'. print $config{'default-output'}{'error'} back to zabbix agent", "fatal", \[caller(0)] ) if $fatal;
    print $config{'error-code'}{'default-output'} if defined $config{'error-code'}{'default-output'};
    exit;
  }
  #Validate the interface END

  my $file_int_stats_full = "$dir_stats/$file_int_stats";

  debug(((caller(0))[3])." Opening file $file_int_stats_full\n");
  #open my $fh_r, "<", $file_int_stats_full or die "Can't read $file_int_stats_full: $!";
  my $stats_data = readfile($file_int_stats_full);
  debug("Data returned from readfile(): $stats_data", "debug", \[caller(0)] ) if $debug > 3;


  STATS:
  foreach (split/\n/, $stats_data) {
    #Remove \n
    chomp;

    #Validate input
    unless (defined $_ and $_) {
      debug("Empty line in \$stats_data. next STATS", "error", \[caller(0)] ) if $error;
      next STATS;
    }

    debug("foreach \$stats_data: $stats_data", "debug", \[caller(0)] ) if $debug > 3;

    #1611971250,,,bond1,,,max,,,bytes,,,248574837
    my ($f_time, $f_int, $f_direction, $f_type, $f_bytes, $f_count) = split /,,,/;

    debug("\$f_time: '$f_time', \$f_int: '$f_int', \$f_direction: '$f_direction', \$f_type: '$f_type', \$f_bytes: '$f_bytes', \$f_count: '$f_count'", "debug", \[caller(0)] ) if $debug > 3;

    next unless $input{'type'}        eq $f_type;
    next unless $input{'data'}        eq $f_bytes;
    next unless $input{'direction'}   eq $f_direction;

    #Set return data if no data is set
    unless (defined $return and defined $f_count and $f_count =~ /^\d{1,}$/) {
      $return = $f_count ;
      next;
    }

    #next line if this is old data
    next unless ( ($time - $f_time) < ($input{'min'}*60) );

    $data_count++;

    if (defined $f_count and $f_count =~ /^\d{1,}$/){
      $return = $f_count if $f_count < $return and $input{'type'} eq "min";
    }

    if (defined $f_count and $f_count =~ /^\d{1,}$/){
      $return = $f_count if $f_count > $return and $input{'type'} eq "max";
    }

    #push @values, $f_count if $input{'type'} eq "avg";
  }

  #  foreach my $key (keys %{ $db{ $input{'interface'} } { $input{'direction'} } {'history'} }) {
  #  if ( $key > $time - ($input{'min'}*60) ) {
  #    $data_count++;
  #
  #    my $value = $db{$input{'interface'}}{$input{'direction'}}{'history'}{$key}{$input{'data'}};
  #    #debug(((caller(0))[3])." This is within the time fram: $key $value\n");
  #
  #    $return = $value unless $return;
  #
  #    $return = $value if $value < $return and $input{'type'} eq "min";
  #
  #    $return = $value if $value > $return and $input{'type'} eq "max";
  #
  #    push @values, $value if $input{'type'} eq "avg";
  #  }
  #}

  my $total;
  #if ($input{'type'} eq "avg") {
  #  $total += $_ foreach @values;
  #  my $value_count = scalar @values;
  #
  #  $return = int($total/$value_count);
  #}
  #debug("All values found: \n".join "\n", @values,"\n");
  debug(((caller(0))[3])." Found $data_count logs for the last $input{'min'} minutes\n");

  #if ($data_count == 0) {
  #  debug(((caller(0))[3])." Could not find any data within this timeframe. Sending back last value from hash: \n");
  #  $return = $db_sessions{'sessions'}{$input{'session'}}{$input{'interface'}}{$input{'direction'}}{$input{'type'}}{$input{'data'}}{'last_data'};
  #}

  #If no result/data in $return. Set the default value
  unless (defined $return) {
    debug("\$return is empty. Setting 0", "info", \[caller(0)] ) if $info;
    $return = $config{'default-output'}{'no-result'};
  }

  debug("Returning value: $return\n");

  #$db_sessions{'sessions'}{$input{'session'}}{$input{'interface'}}{$input{'direction'}}{$input{'type'}}{$input{'data'}}{'last_data'} = $return;

  debug("save hash to file", "debug", \[caller(0)] ) if $debug > 2;
  store \%db_sessions, $file_db_sessions;

  return $return;
}

sub validate_input {
  my $input       = shift || die "Need data to validate\n";
  my @whitelist   = @_;

  foreach (@whitelist) {
    return 1 if $input eq $_;
  }
  return 0;
}

sub help {
  print <<"EOF";

$old_name --daemon

$old_name --daemon --save 1 --history 60 --refresh 1

defaults
--save    1   Save hash to file every N min
--history 60  Keep the last NN minutes of history in memory
--refresh 1   Refresh interface counters every N second

$old_name --interface bond1 --direction receive --data bytes --type max --min 10 --session test

$old_name --interface bond1 --direction receive/transmit --data bytes/packets/errors/drops --type min/max --min 10 --session session_name

$old_name --interface bond1 --direction receive --data bytes --type max --min 10

$old_name --interface bond1 --direction receive --data bytes --type max --min 10 --session monitor_system_name

$old_name --interface bond1

$old_name --interface bond1 --debug 1

$old_name --dumpdb 1

$old_name --dumpdb 1 >filename.log

defaults
--direction receive
--data      bytes
--type      max
--min       10

EOF
}


sub kill_daemon_if_older_version {
  debug(((caller(0))[3])." Start\n");

  my $out = `ps xau|grep "$process_name"| grep -v $$ | grep -v grep`;

  unless ($out) {
    debug(((caller(0))[3])." Could not find any daemon running\n");
    return;
  }

  foreach (split/\n/, $out) {
    s/^\s{1,}//;
    my @s = split/\s{1,}/;
    next unless $s[1];

    debug(((caller(0))[3])." Checking if this is an older version\n");
    my ($version_running) = $out =~ /VER (\d{1,})/;
    debug(((caller(0))[3])." Version found: $version_running\n");

    if ($version_running and $version > $version_running) {
      debug(((caller(0))[3])." The version running is lower than this version. Running: $version_running < $version\n");

      kill 9, $s[1];
    }
  }
}



sub kill_daemon {

  debug(((caller(0))[3])." Start\n");

  my $out = `ps xau|grep "$process_name"| grep -v $$ | grep -v grep`;

  if ($out) {
    foreach (split/\n/, $out) {
      my @s = split/\s{1,}/;
      next unless $s[1];

      kill 9, $s[1];
      debug("Found a daemon of this script running. Killing it. $out\n");
    }
    print "Killed daemon: $out\n";
    exit;
  }

}



sub run_daemon {

  #Exit if this program is already running
  #kill it if the version is lower than this
  debug("kill_daemon_id_older_version()", "debug", \[caller(0)] ) if $debug > 2;
  kill_daemon_if_older_version();

  #Exit if this program is already running
  debug("Checking if this process is running in the background", "debug", \[caller(0)] ) if $debug > 2;
  if (`ps xau|grep "$0"| grep -v $$ | grep -v grep`) {
    debug("This process is already running in the background. exit", "debug", \[caller(0)] ) if $debug > 1;
    exit;
  }
  debug("Tis process is not running in the background", "debug", \[caller(0)] ) if $debug > 1;

  #Don't fork if $debug is true
  unless ($debug){
    debug("fork a child process and exit the main process", "debug", \[caller(0)] ) if $debug > 2;

    my $pid = fork && exit;
    debug("Child process: $pid", "debug", \[caller(0)] ) if $debug > 1;

    #Closing so the parent can exit and the child can live on
    #The parent will live and wait for the child if there is no close
    close STDOUT;
    close STDIN;
    close STDERR;
  }

  debug("daemin()", "debug", \[caller(0)] ) if $debug > 2;
  daemon(
    'refresh' => $options{'--refresh'},
    'history' => $options{'--history'},
    'save'    => $options{'--save'},
  );

}


