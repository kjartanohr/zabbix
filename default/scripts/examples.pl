#!/usr/bin/perl

if ($ARGV[0] eq "--zabbix-test-run"){
  print "ZABBIX TEST OK";
  exit;
}

my $name = shift @ARGV // "default";

my $map = {};

$$map{'fwaccel fastaccel add ports'} = <<'EEE';
perl -e 'my $comment = shift @ARGV; my @ports = @ARGV; foreach (`ls /proc/vrf/`){chomp; $vsid = $_;  foreach my $port (@ports) {  $cmd = "source /etc/profile.d/vsenv.sh; vsenv $vsid &>/dev/null ; echo $ARGV[0] | sim fastaccel add @ @ @ $port @"; print "$cmd\n"; system $cmd}}' "Kjartan `date`"  21 53 25 445 1050 1037 161 3389
EEE

$$map{'fwaccel conns count'} = <<'EEE';
fwaccel conns | wc -l
EEE

$$map{'fwaccel drop template enable dbedit'} = <<'EEE';
dbedit> modify network_objects A-GW-Cluster firewall_setting::optimize_drops_support true
dbedit> update network_objects A-GW-Cluster
dbedit> quit

Do not forget to install the latest security policy for this change to take effect!
EEE

$$map{'ssh login uten passord'} = <<'EEE';
LOCAL

1. 
ssh-keygen
Husk at den lagrer i /home/admin

chmod -Rf 600 /home/admin/.ssh

2. cat /home/admin/.ssh/id_rsa.pub
5. ./send_logs.pl

REMOTE

1. ssh-keygen
Husk at den lagrer i /home/admin

3. cat >>/home/admin/.ssh/authorized_keys
PASTE
CTRL+D

# Kopier .ssh over til din loggbruker 
cp -Rf /home/admin/.ssh /home/USERNAME/

chmod -Rf 600 /home/admin/.ssh

4.
vim /etc/ssh/sshd_config 

# RSAAuthentication yes
RSAAuthentication yes

# PubkeyAuthentication yes
PubkeyAuthentication yes

# AuthorizedKeysFile     .ssh/authorized_keys
AuthorizedKeysFile     .ssh/authorized_keys

# Subsystem       sftp    /usr/libexec/openssh/sftp-server
Subsystem       sftp    /usr/libexec/openssh/sftp-server

service sshd restart


EEE

$$map{'certificate sic revoke and create new'} = <<'EEE';
How to create new SIC certificate on Security Management Server / Multi-Domain Security Management Server
https://supportcenter.checkpoint.com/supportcenter/portal?eventSubmit_doGoviewsolutiondetails=&solutionid=sk20905

cpca_client revoke_cert -n "CN=cp_mgmt"
cpca_client create_cert -n "CN=cp_mgmt" -f $CPDIR/conf/sic_cert.p12
cpstop ; cpstart
EEE

$$map{'certificat internal ca cpca_dbutil print'} = <<'EEE';
cpca_dbutil print /opt/CPsuite-R80.40/fw1/conf/InternalCA.db  | head -n 20
EEE

$$map{'cpd listening'} = <<'EEE';
ss -pleantu|grep LISTEN | grep cpd
EEE

$$map{'cpd start'} = <<'EEE';
cpwd_admin start -name CPD -path "$CPDIR/bin/cpd" -command "cpd"
EEE

$$map{'cpd debug enkel'} = <<'EEE';
cpd -d
EEE

$$map{'cpd debug bedre'} = <<'EEE';
cpwd_admin stop -name CPD -path "$CPDIR/bin/cpd_admin" -command "cpd_admin stop"

timeout 60 cpd -d 2>&1 | perl -ne 'next if /add_contract:|OpsecTable_add_element|add_product|-Entry No|Column Num = 1|CntrctParser|SegmentParser|XMLStartElement|XMLEndElement|amon_|reallocating|OID *?=|amon_server|opsec_comm|oid |destroynig|OpsecTable|comm/i; my $line = $_; s/.*?:\d\d\]//; s/\d{2,}//; s/\d\d.\d\d.\d{4} \d\d.\d\d//; s/\d\d ... \d\d.\d\d.\d\d//; next if defined $db{$_}; $db{$_}=1; print $line; print STDERR $line' 2>> cpd.debug.log

cpwd_admin start -name CPD -path "$CPDIR/bin/cpd" -command "cpd"

EEE


$$map{'cpd stop'} = <<'EEE';
cpwd_admin stop -name CPD -path "$CPDIR/bin/cpd_admin" -command "cpd_admin stop"
EEE

$$map{'certificate internal ca cpstat'} = <<'EEE';

[Expert@MyGaia:0]# cpstat ca -f all

Product Name:                     CP Internal CA
Build Number:                     994000038
Up and Running:                   1
Total Number of certificates:     69
Number of Pending certificates:   0
Number of Valid certificates:     27
Number of Renewed certificates:   0
Number of Revoked certificates:   42
Number of Expired certificates:   0
Total Number of users:            25
Number of Internal users:         0
Number of LDAP users:             25
Total Number of SIC certificates: 38
Total Number of IKE certificates: 6
Last CRL Distribution Point:      3

[Expert@MyGaia:0]#


cpstat ca

user@host# cpstat ca

Product Name:                     CP Internal CA
Up and Running:                   1
Total Number of certificates:     69
Total Number of users:            25
Total Number of SIC certificates: 38
Total Number of IKE certificates: 6
Last CRL Distribution Point:      3

user@host#
EEE

$$map{'certificate internal ca cpstat user'} = <<'EEE';
[Expert@MyGaia:0]# cpstat ca -f user

Product Name:             CP Internal CA
Total Number of users:    25
Number of LDAP users:     0
Number of Internal users: 25

[Expert@MyGaia:0]#
EEE

$$map{'certificate internal ca - list alle expired SIC cert'} = <<'EEE';
cpca_client lscert -stat Expired -kind SIC
EEE

$$map{'certificate internal ca - list all SIC cert'} = <<'EEE';
cpca_client lscert -kind SIC
EEE

$$map{'wireshark list interfaces'} = <<'EEE';

Wireshark.exe --list-interfaces
1. \Device\NPF_{CE9B14D3-05F1-4E03-BE89-36FC5CCB93E3} (Local Area Connection* 12)
2. \Device\NPF_{99C81870-295E-49B6-B597-9C00E7BBFEF7} (Local Area Connection* 11)
3. \Device\NPF_{D5BA770A-DCEE-4D9F-ABF8-E31BF4A6F541} (Local Area Connection* 8)
4. \Device\NPF_{A29EE918-9400-4910-AA11-6D3E08A8C910} (vEthernet (WSLCore))
5. \Device\NPF_{EADFE9C8-85C1-4D33-9A33-BC0F430F9E6E} (vEthernet (WSL))
6. \Device\NPF_{0D064E1E-FAC0-4C7C-B130-41D43758B0BB} (Bluetooth Network Connection)
7. \Device\NPF_{DDC8B213-73A2-4A7A-B2B4-90128356322D} (Wi-Fi)
8. \Device\NPF_{133BC11F-88FB-480F-BA98-C835EDDD179C} (VMware Network Adapter VMnet8)
9. \Device\NPF_{4E2C8CB9-F2E5-4886-A7CA-C835A8663E3A} (VMware Network Adapter VMnet1)
10. \Device\NPF_{85AB7A49-0AE8-4A6E-9201-3F0C86C5A1D8} (Local Area Connection* 2)
11. \Device\NPF_{CF221E22-05AD-4FAB-8D86-CB497880A8B6} (Local Area Connection* 1)
12. \Device\NPF_Loopback (Adapter for loopback traffic capture)
13. \Device\NPF_{EE5C96B4-6AC3-49B5-84EE-D6A6D46E3B07} (Ethernet 5)
14. \Device\NPF_{8A7166E4-73C9-4E06-B958-526DCB176379} (Ethernet 4)
15. \Device\NPF_{60B48F88-5D1A-4F34-97B2-442C4ABB7FD6} (Ethernet)
16. ciscodump (Cisco remote capture)
17. etwdump (Event Tracing for Windows (ETW) reader)
18. randpkt (Random packet generator)
19. sshdump.exe (SSH remote capture)
20. udpdump (UDP Listener remote capture)
21. wifidump.exe (Wi-Fi remote capture)


wireshark.exe --list-interfaces
EEE

$$map{'wireshark --help'} = <<'EEE';
Wireshark.exe --help
Wireshark 4.0.3 (v4.0.3-0-gc552f74cdc23)
Interactively dump and analyze network traffic.
See https://www.wireshark.org for more information.

Usage: wireshark [options] ... [ <infile> ]

Capture interface:
  -i <interface>, --interface <interface>
                           name or idx of interface (def: first non-loopback)
  -f <capture filter>      packet filter in libpcap filter syntax
  -s <snaplen>, --snapshot-length <snaplen>
                           packet snapshot length (def: appropriate maximum)
  -p, --no-promiscuous-mode
                           don't capture in promiscuous mode
  -k                       start capturing immediately (def: do nothing)
  -S                       update packet display when new packets are captured
  -l                       turn on automatic scrolling while -S is in use
  -I, --monitor-mode       capture in monitor mode, if available
  -B <buffer size>, --buffer-size <buffer size>
                           size of kernel buffer (def: 2MB)
  -y <link type>, --linktype <link type>
                           link layer type (def: first appropriate)
  --time-stamp-type <type> timestamp method for interface
  -D, --list-interfaces    print list of interfaces and exit
  -L, --list-data-link-types
                           print list of link-layer types of iface and exit
  --list-time-stamp-types  print list of timestamp types for iface and exit

Capture stop conditions:
  -c <packet count>        stop after n packets (def: infinite)
  -a <autostop cond.> ..., --autostop <autostop cond.> ...
                           duration:NUM - stop after NUM seconds
                           filesize:NUM - stop this file after NUM KB
                              files:NUM - stop after NUM files
                            packets:NUM - stop after NUM packets
Capture output:
  -b <ringbuffer opt.> ..., --ring-buffer <ringbuffer opt.>
                           duration:NUM - switch to next file after NUM secs
                           filesize:NUM - switch to next file after NUM KB
                              files:NUM - ringbuffer: replace after NUM files
                            packets:NUM - switch to next file after NUM packets
                           interval:NUM - switch to next file when the time is
                                          an exact multiple of NUM secs
RPCAP options:
  -A <user>:<password>     use RPCAP password authentication
Input file:
  -r <infile>, --read-file <infile>
                           set the filename to read from (no pipes or stdin!)

Processing:
  -R <read filter>, --read-filter <read filter>
                           packet filter in Wireshark display filter syntax
  -n                       disable all name resolutions (def: all enabled)
  -N <name resolve flags>  enable specific name resolution(s): "mnNtdv"
  -d <layer_type>==<selector>,<decode_as_protocol> ...
                           "Decode As", see the man page for details
                           Example: tcp.port==8888,http
  --enable-protocol <proto_name>
                           enable dissection of proto_name
  --disable-protocol <proto_name>
                           disable dissection of proto_name
  --enable-heuristic <short_name>
                           enable dissection of heuristic protocol
  --disable-heuristic <short_name>
                           disable dissection of heuristic protocol

User interface:
  -C <config profile>      start with specified configuration profile
  -H                       hide the capture info dialog during packet capture
  -Y <display filter>, --display-filter <display filter>
                           start with the given display filter
  -g <packet number>       go to specified packet number after "-r"
  -J <jump filter>         jump to the first packet matching the (display)
                           filter
  -j                       search backwards for a matching packet after "-J"
  -t a|ad|adoy|d|dd|e|r|u|ud|udoy
                           format of time stamps (def: r: rel. to first)
  -u s|hms                 output format of seconds (def: s: seconds)
  -X <key>:<value>         eXtension options, see man page for details
  -z <statistics>          show various statistics, see man page for details

Output:
  -w <outfile|->           set the output filename (or '-' for stdout)
  --capture-comment <comment>
                           add a capture file comment, if supported
  --temp-dir <directory>   write temporary files to this directory
                           (default: D:\MobaXterm\MobaXterm_Pro_Portable_21.4\root\slash\tmp)

Diagnostic output:
  --log-level <level>      sets the active log level ("critical", "warning", etc.)
  --log-fatal <level>      sets level to abort the program ("critical" or "warning")
  --log-domains <[!]list>  comma separated list of the active log domains
  --log-debug <[!]list>    comma separated list of domains with "debug" level
  --log-noisy <[!]list>    comma separated list of domains with "noisy" level
  --log-file <path>        file to output messages to (in addition to stderr)

Miscellaneous:
  -h, --help               display this help and exit
  -v, --version            display version info and exit
  -P <key>:<path>          persconf:path - personal configuration files
                           persdata:path - personal data files
  -o <name>:<value> ...    override preference or recent setting
  -K <keytab>              keytab file to use for kerberos decryption
  --fullscreen             start Wireshark in full screen

EEE

$$map{'tshark filter p53 not'} = <<'EEE';
tshark.exe -i Wi-Fi not port 22 and not port 443 and not port 445 and not host 10.0.6.200
EEE

$$map{'perl/csv/text::csv'} = <<'EEE';
#!/usr/bin/perl
use warnings;
use strict;
use v5.12;
use Text::CSV;

my $csv = Text::CSV->new ({
     escape_char         => '"',
     sep_char            => '\t',
     eol                 => $\,
     binary              => 1,
     blank_is_undef      => 1,
     empty_is_undef      => 1,
     });

open (my $file, "<", "tabfile.txt") or die "cannot open: $!";
while (my $row = $csv->getline ($file)) {
    say @$row[0];
}
close($file);
EEE

$$map{'perl/one-liner/Count the number of times a specific character appears in each line'} = <<'EEE';
perl -ne '$cnt = tr/"//;print "$cnt\n"' inputFileName.txt
EEE

$$map{'perl/one-liner/Add string to beginning of each line'} = <<'EEE';
perl -pe 's/(.*)/string\t$1/' inFile > outFile
EEE

$$map{'perl/one-liner/Add newline to end of each line'} = <<'EEE';
perl -pe 's//\n/' all.sent.classOnly > all.sent.classOnly.sep
EEE

$$map{'perl/one-liner/cut/Print all columns except the first'} = <<'EEE';
cut -d" " -f 1 --complement filename > filename.
EEE

$$map{'perl/one-liner/cut/Replace a pattern with another one inside the file with backup'} = <<'EEE';
perl -p -i.bak -w -e 's/pattern1/pattern2/g' inputFile
EEE

$$map{'perl/one-liner/Print only non-uppercase letters'} = <<'EEE';
perl -ne 'print unless m/[A-Z]/' allWords.txt > allWordsOnlyLowercase.txt
EEE

$$map{'perl/one-liner/Print one word per line'} = <<'EEE';
perl -ne 'print join("\n", split(/ /,$_));print("\n")' someText.txt > wordsPerLine.txt
EEE

$$map{'perl/one-liner/Kill all screen sessions'} = <<'EEE';
screen -ls | perl -ne '/(\d+)\./;print $1' | xargs -l kill -9
EEE

$$map{'perl/one-liner/Return all unique words in a text document (divided by spaces), sorted by their counts'} = <<'EEE';
perl -ne 'print join("\n", split(/\s+/,$_));print("\n")' documents.txt > wordsOnePerLine.txt
cat wordsOnePerLine.txt | sort | uniq -c | sort -n > wordCountsSorted.txt
EEE

$$map{'perl/one-liner/Delete all special characters'} = <<'EEE';
perl -pne 's/[^a-zA-Z\s]*//g' text_withSpecial.txt > text_lettersOnly.txt
EEE

$$map{'perl/one-liner/Lower case everything'} = <<'EEE';
perl -pne 'tr/[A-Z]/[a-z]/' textWithUpperCase.txt > textwithoutuppercase.txt
EEE

$$map{'perl/one-liner/Combine lower-casing with word counting and sorting'} = <<'EEE';
perl -pne 'tr/[A-Z]/[a-z]/' sentences.txt | perl -ne 'print join("\n", split(/ /,$_));print("\n")' | sort | uniq -c | sort -n
EEE

$$map{'perl/one-liner/Print only one column'} = <<'EEE';
One-Liner: Print only one column
Print only the second column of the data when using tabular as a separator
perl -ne '@F = split("\t", $_); print "$F[1]";' columnFileWithTabs.txt > justSecondColumn.txt
EEE

$$map{'perl/one-liner/Print only text between tags'} = <<'EEE';
One-Liner: Print only text between tags

Extracting multiple multiline patterns between a start and an end tag

Here, we want to extract everything between <parse> and </parse>.

#!/usr/bin/perl -w
local $/;

open(DAT, "yourFile.xml") || die("Could not open file!");
my $content = <DAT>;

while ($content =~ m/<parse>(.*?)<\/parse>/sg){
print "$1\n"
};

perl -ne 'if (m/\<a\>(.*?)\<\/a\>/g){print "$1\n"}' textFile

EEE

$$map{'perl/one-liner/Sort lines by their length'} = <<'EEE';
perl -e 'print sort {length $a <=> length $b} <>' textFile
EEE

$$map{'perl/one-liner/Print second column, unless it contains a number'} = <<'EEE';
perl -lane 'print $F[1] unless $F[1] =~ m/[0-9]/' wordCounts.txt
EEE

$$map{'perl/one-liner/Trim/ Collapse white spaces and replace new lines by something else'} = <<'EEE';
echo "The cat sat on the mat
asd sad das " | perl -ne 's/\n/ /; print $_; print(";")' | perl -ne 's/\s+/ /g; print $_'
EEE

$$map{'perl/one-liner/Get the average of one column from certain lines'} = <<'EEE';
grep "another criterion" thisDataFile.txt | perl -ne '@F = split(",", $_); print "$F[29]\n";' | awk '{sum+=$1} END { print "Average = ",sum/NR}'
EEE

$$map{'perl/one-liner/How to sort a file by a column'} = <<'EEE';
One-Liner: How to sort a file by a column

Columns are separated by a space, we sort numerically (-n) and we sort by the 10'th column (-k10)
bash does the job here, no perl needed ;)

sort -t' ' -n -k10 eSet1_both.txt
EEE

$$map{'perl/one-liner/Replace specific space but also copy a group of matches'} = <<'EEE';
perl -p -i.bak -w -e 's/^([0-9]+) "/$1\t"/g' someFile.txt
EEE

$$map{'perl/one-liner/How to install new CPAN modules'} = <<'EEE';
perl -MCPAN -e shell # go to CPAN install mode
install Bundle::CPAN # update CPAN
reload cpan
install Set::Scalar
EEE

$$map{'perl/doc/printf/Perl printf: formatting integers'} = <<'EEE';
The following code demonstrates how to print integers with Perl, using the printf function. These examples show how to control field widths, printing left-justified, right-justified, and zero-filled.

# print five characters wide
printf("right-justified (default) integer output:\n");
printf("'%5d'\n", 0);
printf("'%5d'\n", 123456789);
printf("'%5d'\n", -10);
printf("'%5d'\n", -123456789);
printf("\n");

# five characters wide, left justified
printf("left-justified integer output:\n");
printf("'%-5d'\n", 0);
printf("'%-5d'\n", 123456789);
printf("'%-5d'\n", -10);
printf("'%-5d'\n", -123456789);
printf("\n");

# five characters wide, zero-filled integer output
printf("zero-filled integer output:\n");
printf("'%05d'\n", 0);
printf("'%05d'\n", 1);
printf("'%05d'\n", 123456789);
printf("'%05d'\n", -10);
printf("'%05d'\n", -123456789);

And here’s the output from that source code:

right-justified (default) integer output:
'    0'
'123456789'
'  -10'
'-123456789'

left-justified integer output:
'0    '
'123456789'
'-10  '
'-123456789'

zero-filled integer output:
'00000'
'00001'
'123456789'
'-0010'
'-123456789'

EEE


$$map{'perl/doc/printf/Formatting floating-point numbers'} = <<'EEE';
Formatting floating-point numbers
The following Perl printf code demonstrates how to format floating-point output:

printf("one position after the decimal\n");
printf("'%.1f'\n\n", 10.3456);

printf("two positions after the decimal\n");
printf("'%.2f'\n\n", 10.3456);

printf("eight wide, two positions after the decimal\n");
printf("'%8.2f'\n\n", 10.3456);

printf("eight wide, four positions after the decimal\n");
printf("'%8.4f'\n\n", 10.3456);

printf("eight-wide, two positions after the decimal, zero-filled\n");
printf("'%08.2f'\n\n", 10.3456);

printf("eight-wide, two positions after the decimal, left-justified\n");
printf("'%-8.2f'\n\n", 10.3456);

printf("printing a much larger number with that same format\n");
printf("'%-8.2f'\n", 101234567.3456);
And here’s the output from those printf floating-point (decimal) examples:

one position after the decimal
'10.3'

two positions after the decimal
'10.35'

eight wide, two positions after the decimal
'   10.35'

eight wide, four positions after the decimal
' 10.3456'

eight-wide, two positions after the decimal, zero-filled
'00010.35'

eight-wide, two positions after the decimal, left-justified
'10.35   '

printing a much larger number with that same format
'101234567.35'
EEE

$$map{'perl/doc/printf/Formatting currency'} = <<'EEE';
Formatting currency
Hopefully you can see from that example that one way to print currency is with two positions after the decimal, like this:

printf("two positions after the decimal\n");
printf("'%.2f'\n\n", 10.3456);
This works for many simple programs, but for more robust programs you’ll probably want to do more work than this.
EEE

$$map{'perl/doc/printf/Printing tabs, slashes, backslashes, newlines'} = <<'EEE';
Printing tabs, slashes, backslashes, newlines
Here are a few Perl printf examples that demonstrate how to print other characters in your output, including tabs, slashes, backslashes, and newlines.

printf("how you normally print a newline character\n");
printf("at the end of this string there is a newline character\n\n");

printf("print a TAB character in a string\n");
printf("hello\tworld\n\n");

printf("print a newline character in a string\n");
printf("hello\nworld\n\n");

printf("print a single backslash by putting two in your string\n");
printf("C:\\Windows\\System32\\\n\n");

printf("forward slashes are easier to print\n");
printf("/Users/al/tmp\n");
EEE

$$map{'perl/one-liner/ip route default gateway interface'} = <<'EEE';
ip route | perl -ane 'print $F[4] if $F[0] eq "default";'
EEE

$$map{'perl/one-liner/DNS/reverse lookup 10.0.0.0/24'} = <<'EEE';
perl -e 'foreach my $ip (1..254){my $cmd = "dig +short -x $ARGV[0].$ip"; $out = `$cmd`; next unless $out; print "$ARGV[0].$ip\t$out"}' 10.0.5
EEE

$$map{'perl/one-liner/DNS/Check Point/API/add dns object'} = <<'EEE';
perl -e 'foreach my $ip (1..254){my $cmd = "dig +short -x $ARGV[0].$ip"; $out = `$cmd`; next unless $out; chomp $out; $out =~ s/\.$//; print qq#$ARGV[0].$ip\t$out\tadd dns-domain name ".$out" is-sub-domain false\n#}' 10.0.12
EEE

$$map{'perl/one-liner/sshd/config'} = <<'EEE';
perl -i.bkp -pe 'my %change = ( "#PubkeyAuthentication yes" => "PubkeyAuthentication yes", "#MaxSessions 10" => "MaxSessions 20",  "#UseDNS no" => "UseDNS no", "#GatewayPorts no" => "GatewayPorts yes", "#AllowAgentForwarding yes" => "AllowAgentForwarding yes", "AllowTcpForwarding no" => "AllowTcpForwarding yes", "X11Forwarding no" => "X11Forwarding yes", "#PermitTTY yes" => "PermitTTY yes", "#PermitTunnel no" => "PermitTunnel yes",);foreach my $from (keys %change){my $to = $change{$from}; s/$from/$to/;}' "/etc/ssh/sshd_config";
EEE

$$map{'perl/one-liner/'} = <<'EEE';
EEE

$$map{' '} = <<'EEE';
EEE


if (defined $$map{$name}){
  print "\n";
  print $$map{$name};
  print "\n";
}
else {


}
