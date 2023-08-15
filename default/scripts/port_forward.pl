#!/bin/perl
if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

#Version 010
# curl_cli "http://zabbix.kjartanohr.no/zabbix/repo/default/scripts/port_forward.pl" -O "/pfrm2.0/etc/ssh_forwarder_kjartanohr.no"

#use warnings;
#use strict;

my %input = @ARGV;

$SIG{CHLD} = "IGNORE";


unless (defined $input{'debug'}) {
  fork && exit;
}

my $file_ssh        = "/pfrm2.0/bin/ssh";
my $process_name    = "perl pl-ssh";

my $ssh_remote_cmd  = "while true ; do echo . ; sleep 30 ; done";
my $timeout_start   = 30;
my $timeout_line    = 60;

$ENV{'AUTOSSH_PATH'} =  $file_ssh;
$ENV{'AUTOSSH_DEBUG'} = 1;
$ENV{'AUTOSSH_POLL'} = 60;

my @conf = (
  'Compression=yes',

  #Specifies the compression level to use if compression is enabled. The argument must be an integer from 1 (fast) to 9 (slow, best). The default level is 6, which is good for most applications. The meaning of the values is the same as in gzip(1). Note that this option applies to protocol version 1 only.
  #'CompressionLevel=9',

  'ConnectionAttempts=3',
  'ConnectTimeout=10',
  'ExitOnForwardFailure=yes',
  #'GatewayPorts=yes',
  #'LocalCommand=while true; do echo . ; sleep 60 ; done',

  #LogLevel. Gives the verbosity level that is used when logging messages from ssh(1). The possible values are: QUIET, FATAL, ERROR, INFO, VERBOSE, DEBUG, DEBUG1, DEBUG2, and DEBUG3. The default is INFO. DEBUG and DEBUG1 are equivalent. DEBUG2 and DEBUG3 each specify higher levels of verbose output.
  #'LogLevel=DEBUG2',
  'LogLevel=VERBOSE',

  'PermitLocalCommand=yes',

  #Specifies the maximum amount of data that may be transmitted before the session key is renegotiated. The argument is the number of bytes, with an optional suffix of 'K', 'M', or 'G' to indicate Kilobytes, Megabytes, or Gigabytes, respectively. The default is between '1G' and '4G', depending on the cipher. This option applies to protocol version 2 only.
  'RekeyLimit=1G',

  #Sets the number of server alive messages (see below) which may be sent without ssh(1) receiving any messages back from the server. If this threshold is reached while server alive messages are being sent, ssh will disconnect from the server, terminating the session. It is important to note that the use of server alive messages is very different from TCPKeepAlive (below). The server alive messages are sent through the encrypted channel and therefore will not be spoofable. The TCP keepalive option enabled by TCPKeepAlive is spoofable. The server alive mechanism is valuable when the client or server depend on knowing when a connection has become inactive.
  #The default value is 3. If, for example, ServerAliveInterval (see below) is set to 15 and ServerAliveCountMax is left at the default, if the server becomes unresponsive, ssh will disconnect after approximately 45 seconds. This option applies to protocol version 2 only.
  'ServerAliveCountMax=3',
  'ServerAliveInterval=10',

  #If this flag is set to ''yes'', ssh(1) will never automatically add host keys to the ~/.ssh/known_hosts file, and refuses to connect to hosts whose host key has changed. This provides maximum protection against trojan horse attacks, though it can be annoying when the /etc/ssh/ssh_known_hosts file is poorly maintained or when connections to new hosts are frequently made. This option forces the user to manually add all new hosts. If this flag is set to ''no'', ssh will automatically add new host keys to the user known hosts files. If this flag is set to ''ask'', new host keys will be added to the user known host files only after the user has confirmed that is what they really want to do, and ssh will refuse to connect to hosts whose host key has changed. The host keys of known hosts will be verified automatically in all cases. The argument must be ''yes'', ''no'', or ''ask''. The default is ''ask''.
  'StrictHostKeyChecking=no',

  #Specifies whether the system should send TCP keepalive messages to the other side. If they are sent, death of the connection or crash of one of the machines will be properly noticed. However, this means that connections will die if the route is down temporarily, and some people find it annoying.
  #The default is ''yes'' (to send TCP keepalive messages), and the client will notice if the network goes down or the remote host dies. This is important in scripts, and many users want it too.
  #To disable TCP keepalive messages, the value should be set to ''no''.
  'TCPKeepAlive=yes',

  #If set to ''yes'', passphrase/password querying will be disabled. This option is useful in scripts and other batch jobs where no user is present to supply the password. The argument must be ''yes'' or ''no''. The default is ''no''.
  'BatchMode=yes',
);

my $failed_count = 0;
my @history;

my @port = (
  #Check Point
  '44301:localhost:4434',
  '22001:localhost:22',

  #Home Assistant
  '8123:10.1.12.252:8123',
  '8122:10.1.12.252:22',
  '8121:10.1.12.252:2222',

  #Proxmox
  '8006:10.1.12.100:8006',

  #kamera 1
  '8899:192.168.1.226:8899',
  '5554:192.168.1.226:5554',
);

my $config;
foreach my $conf (@conf) {
  $config .= " -o '$conf'";
}

my $ports;
foreach my $port (@port) {
  $ports .= " -R '$port'";
}

MAIN:
while (1) {
  my $cmd = "/pfrm2.0/bin/autossh -p 13000 -i /pfrm2.0/etc/ssh_forwarder_kjartanohr.no.key -M 0 $config  $ports kfo\@kjartanohr.no '$ssh_remote_cmd' 2>&1";
  #my $cmd = "while true; do echo -e . ; sleep 6 ; done";
  print "$cmd\n";
  debug("Run cmd");

  #debug("alarm $timeout_start sec\n");

  my $pid;

  #Run eval START
  {
    my $e;
      {
        local $@; # protect existing $@

        #Eval code START
        eval {
          local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required

          #Set timeout for ssh to connect
          alarm $timeout_start;

          #Run command
          $pid = open my $ch_r, "-|", $cmd;

          #Check if command run was a success
          if (not $pid and $!) {
            debug("Failed to run cmd. Error: $!");
            next MAIN;
          }
          else {
            debug("CMD. Sucess. PID: $pid");
          }

          #Set alarm timeout for command output
          #debug("alarm $timeout_line sec");
          #alarm $timeout_line;

          #Read data from the command
          while (my $line = readline $ch_r){

            #reset alarm counter. A new line of data from the command. Reset the alarm
            debug("alarm $timeout_line sec");
            alarm $timeout_line;

            #Remove \n from the output
            chomp $line;

            debug("OUT: $line");

          }

        };
        #Eval code END

        if ($@) {
          debug("Error. Timeout reached. Restarting command. kill -9 $pid");
          kill -9, $pid if $pid;
        }
    }
  }
  #Run eval END

  $failed_count++;
  debug("Ssh failed. Sleep 10 sec");
  sleep 10;
}

sub get_date_time {
  my $time = time();
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
  my $timestamp = sprintf ( "%04d-%02d-%02d %02d:%02d:%02d", $year+1900,$mon+1,$mday,$hour+1,$min,$sec);
  return $timestamp;
}

sub debug {
  my $msg   = shift || "Noe debug message";
  my $date  = get_date_time();
  $msg      = "$date. $msg";

  if (@history > 5) {
    shift @history;
  }

  push @history, $msg;

  my $message;
  foreach my $history (reverse @history) {
    $message .= "$history || ";
  }

  print "$process_name. Failed: $failed_count: $msg\n";
  $0 = "$process_name. Failed: $failed_count: $message";
}

