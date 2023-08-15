#!/usr/bin/perl5.32.0
BEGIN{
  require "/usr/share/zabbix/repo/files/auto/lib.pm";
}

#TOOD

use warnings;
use strict;
use Storable;
use Data::Dumper;
use JSON::MaybeXS;

my $old_name      = $0;
my $version       = 102;
my $process_name  = "perl Interface monitor VER";
$0                = "$process_name $version";
$SIG{CHLD}        = "IGNORE";
$SIG{INT}         = \&ctrl_c;                                           #Catch CTRL+C and run sub ctrl_c. print stats, save cache to file and exit
$|++;


zabbix_check($ARGV[0]);

our $debug              = 0;
my  $dir_tmp            = "/tmp/zabbix/interface_monitor";
our $file_debug         = "$dir_tmp/debug.log";
my  $dir_stats          = "$dir_tmp/interface_stats";
my  $file_db            = "$dir_tmp/data.db";
my  $file_db_sessions   = "$dir_tmp/data_sessions.db";
my  $file_dev           = "/proc/net/dev";
my  $file_stats_max_size  = 100;                        #N KB

my %db;

#Delete file if bigger than 10 MB
delete_file_if_bigger_than_mb($file_db,10);
delete_file_if_bigger_than_mb($file_db_sessions,10);

create_dir($dir_tmp);
create_dir($dir_stats);

#Delete log file if it's bigger than 10 MB
trunk_file_if_bigger_than_mb($file_debug,10);





#End of standard header


#Eveything after here is the child

my %options = @ARGV;

$debug = 1 if $options{'debug'};

if ($options{'--kill'}) {
  kill_daemon();

}
elsif ($options{'--daemon'}) {
  #Exit if this program is already running
  #kill it if the version is lower than this
  kill_daemon_if_older_version();

  #Exit if this program is already running
  if (`ps xau|grep "$0"| grep -v $$ | grep -v grep`) {
    debug("Found an already running version of my self. Will exit\n");
    exit;
  }
  else {
    print "Startet\n";

  #Don't fork if $debug is true
  unless ($debug){
    fork && exit;
  }

  #Closing so the parent can exit and the child can live on
  #The parent will live and wait for the child if there is no close
  #Don't close if $debug is true
  unless ($debug) {
    close STDOUT;
    close STDIN;
    close STDERR;
  }

}
  daemon(
    'refresh' => $options{'--refresh'},
    'history' => $options{'--history'},
    'save'    => $options{'--save'},
  );
}
elsif ($options{'--interface'}) {
  my $data_stats = get_stats(
    'interface' => $options{'--interface'},
    'min'       => $options{'--min'},
    'direction' => $options{'--direction'},
    'type'      => $options{'--type'},
    'session'   => $options{'--session'},
  );

  print $data_stats || 0;

}
elsif ($options{'--dumpdb'}) {
  my $db_ref;
  $db_ref          = retrieve($file_db) if -f $file_db;
  %db = %{$db_ref} if $db_ref;
  print Dumper %db;
}
else {
  help();
}


sub get_headers {
  debug(((caller(0))[3])." Start\n");

  my $line        = shift || die "Need data to find headers\n";
  my $split_char  = shift || '\s{1,}';
  my %header;

  debug(((caller(0))[3])." Input \$line $line\n");
  debug(((caller(0))[3])." Input \$spliut_char $split_char\n");

  debug(((caller(0))[3])." foreach split /$split_char/\n");
  my $count = 0;
  foreach (split/$split_char/, $line) {
    $header{"count $count"} = $_;
    $header{"name $_"} = $count;
    $count++;
  }
  return %header;
}

sub ctrl_c {
  debug(((caller(0))[3])." Start\n");

  debug(((caller(0))[3])." Exiting script\n");
  debug(((caller(0))[3])." Saving cache to file\n");
  store \%db, $file_db if $options{'--daemon'};
  #print Dumper %db;


  exit;
}

sub get_date {
  my $time = shift || time;

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime($time);
  return sprintf "%4d.%02d.%02d",$year+1900,$mon+1,$mday;
}

sub daemon {
  debug(((caller(0))[3])." Start\n");

  eval {
    my $db_ref;
    $db_ref          = retrieve($file_db) if -f $file_db;
    %db = %{$db_ref} if $db_ref;
  };

  if ($@) {
    debug(((caller(0))[3])." Something went wrong when opening database file: $@\nWill delete database file and exit");
    unlink $file_db;
  }

  $db{'internal'}{'save_time'} = time;

  my %input = @_;
  $input{'refresh'} ||= 2;
  $input{'history'} ||= 60;
  $input{'save'}    ||= 1;

  #Default is VS
  my @vrf = (0);

  if (is_vsx()) {
    #@vrf = run_cmd("vrf list vrfs","a");
    @vrf = get_all_vs_id();
  }


  while (1) {
    my $time = time;

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

    #open my $fh_r, "<", $file_dev or die "Can't open $file_dev: $!";
    #my @dev = <$fh_r>;
    #close $fh_r;

    my @dev;

    foreach my $vrf (@vrf) {
      chomp $vrf;

      my $cmd_cat_dev;

      if ($vrf == 0) {
        $cmd_cat_dev = "cat /proc/net/dev";
      }
      else {
        $cmd_cat_dev = "source /etc/profile.d/vsenv.sh; vsenv $vrf &>/dev/null ; cat /proc/net/dev";
      }


      foreach (`$cmd_cat_dev`) {
        push @dev, $_;
      }
    }

    foreach my $line (@dev) {
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
    sleep $input{'refresh'};
  }

}

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

  debug(((caller(0))[3])." Input. interface: $input{'interface'}, direction: $input{'direction'}, type: $input{'type'}, data: $input{'data'}, min: $input{'min'}, sessions: $input{'session'}\n");

  #die "Wrong input: $input{'interface'}"  unless exists $db{$input{'interface'}};
  die "Wrong input: $input{'direction'}"  unless validate_input($input{'direction'},"receive","transmit");
  die "Wrong input: $input{'type'}"       unless validate_input($input{'type'},"min","max");
  die "Wrong input: $input{'min'}"        unless validate_input($input{'min'},1..60);

  my %db_sessions;
  eval {
    my $db_sessions_ref;
    $db_sessions_ref  = retrieve($file_db_sessions) if -f $file_db_sessions;
    %db_sessions = %{$db_sessions_ref}      if $db_sessions_ref;
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
      my $session_time_human = get_date($session_time);

      debug(((caller(0))[3])." Found session in hash. Last timestamp is $session_time $session_time_human \n");
      my $seconds_sine_last_check = ($time - $session_time);

      ${$sess_time_ref} = $time;

      debug(((caller(0))[3])." it's $seconds_sine_last_check seconds since last check with this session\n");

      if ($seconds_sine_last_check < 60) {
        debug(((caller(0))[3])." This is less than 60 seconds. Setting input min to 2\n");
        $input{'min'} = 2;
      }
      else {
        debug(((caller(0))[3])." This is more than 60 seconds. setting min to time/60\n");
        $input{'min'} = int ($seconds_sine_last_check / 60);
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

  unless ($file_int_stats) {
    debug(((caller(0))[3])."Unknown interface. Could not find stats for this interface: $input{'interface'}\n");
    print 9999;
    exit;
  }

  my $file_int_stats_full = "$dir_stats/$file_int_stats";

  debug(((caller(0))[3])." Opening file $file_int_stats_full\n");
  open my $fh_r, "<", $file_int_stats_full or die "Can't read $file_int_stats_full: $!";

  while (<$fh_r>) {

    chomp;
    #1611971250,,,bond1,,,max,,,bytes,,,248574837
    my ($f_time, $f_int, $f_direction, $f_type, $f_bytes, $f_count) = split /,,,/;

    next unless $input{'type'}        eq $f_type;
    next unless $input{'data'}        eq $f_bytes;
    next unless $input{'direction'}   eq $f_direction;

    unless ($return) {
      $return = $f_count ;
      next;
    }

    next unless ( ($time - $f_time) < ($input{'min'}*60) );

    $data_count++;

    $return = $f_count if $f_count < $return and $input{'type'} eq "min";

    $return = $f_count if $f_count > $return and $input{'type'} eq "max";

    #push @values, $f_count if $input{'type'} eq "avg";
  }

  close $fh_r;

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

  unless ($return) {
    debug(((caller(0))[3])." \$return is empty. Setting 0\n");
    $return = 0;

  }

  debug("Returning value: $return\n");

  #$db_sessions{'sessions'}{$input{'session'}}{$input{'interface'}}{$input{'direction'}}{$input{'type'}}{$input{'data'}}{'last_data'} = $return;

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

sub delete_file_if_bigger_than_mb {
  debug(((caller(0))[3])." Start\n");

  my $file    = shift || die "Need a filename to check file size for";
  my $size    = shift || 10;

  debug(((caller(0))[3])." Input. file: $file, size: $size MB\n");

  unless (-f $file) {
    debug(((caller(0))[3])." Could not find $file. Returning\n");
    return;
  }

  my $size_mb = ($size*1024*1024);

  debug(((caller(0))[3])." $file is $size_mb MB\n");

  print "Checking if $file is bigger than size_mb MB\n" if $debug;

  if (-s $file > ($size*1024*1024) ) {
    debug(((caller(0))[3])." $file is bigger than $size. Deleting\n");
    unlink $file;
  }
}


