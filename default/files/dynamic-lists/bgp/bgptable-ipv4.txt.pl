#!/usr/bin/perl
use warnings;
use strict;
use JSON;
use Data::Dumper;

# https://support.checkpoint.com/results/sk/sk167210

my $file = "bgptable-ipv4.txt";
my $dir_dest = "$file.dir";

mkdir $dir_dest if not -d $dir_dest;


my %data;


open my $fh_r, "<", $file or die "Can't read $file: $!";

while (my $line = readline $fh_r){
  chomp $line;

  next if not $line =~ /^\*\> \d/;

  # *> 12.48.114.0/24   202.12.28.1                            0 4777 2516 7922 33491 30573 i
  #    Network          Next Hop            Metric LocPrf Weight Path
  # *> 1.0.64.0/18      202.12.28.1                            0 4777 2516 7670 18144 i
  $line =~ s/^\*\> //;
  #my ($network, $next_hop, $metric, $locprf, $weight, $path) = split/\s{2,}/, $line;
  my ($network, $next_hop, $metric, $asn) = split/\s{1,}/, $line, 4;

  next if not defined $asn;

  $asn =~ s/..$//;

  $network .= "/24" if not $network =~ /\//;


  #print "$line\n";
  #print "\$asn: $asn\n";

  foreach my $asn_singel (split/ /, $asn){
    push @{$data{$asn_singel}}, $network;

    my $file_asn = "$dir_dest/asn-$asn_singel.csv";
    next if -f $file_asn;
    #print "$file_asn\n";
    open my $fh_w, ">>", $file_asn or die "Can't write to $file_asn: $!";
    print $fh_w "$network,$asn_singel\n";
    close $fh_w;


  }

}

#print "dumepr: \n";
#print Dumper %data;

my $number = 10000;
foreach my $key (keys %data){

  my @networks = @{$data{$key}};

  $number++;

  my $object = {
    "version"     => "1.0",
    "description" => "Generic Data Center file",
  };

  push @{$$object{'objects'}},
  {
    "name"        => "ASN-AS$key",
    "id"          => "e7f18b60-f22d-4f42-8dc2-050490e$number",
    "description" => "",
    "ranges"      =>  [@networks],
  };

  my $json_out = JSON::encode_json($object);

  my $file_asn = "$dir_dest/asn-$key.json";

  print "$file_asn\n";
  open my $fh_w, ">", $file_asn or die "Can't write to $file_asn: $!";
  print $fh_w $json_out;
  close $fh_w;

  #print $json_out;
  #exit;


}


__DATA__

{
      "version": "1.0",     
      "description": "Generic Data Center file example",
      "objects": [
                          {
                               "name": "Object A name",
                               "id": "e7f18b60-f22d-4f42-8dc2-050490ecf6d5",
                               "description": "Example for IPv4 addresses",
                               "ranges": [
                                                     "91.198.174.192",
                                                     "20.0.0.0/24",                        
                                                     "10.1.1.2-10.1.1.10"
                               ]              
                          },
                          {
                                "name": "Object B name",
                                "id": "a46f02e6-af56-48d2-8bfb-f9e8738f2bd0",
                                "description": "Example for IPv6 addresses",
                                "ranges": [
                                                     "2001:0db8:85a3:0000:0000:8a2e:0370:7334",
                                                     "0064:ff9b:0000:0000:0000:0000:1234:5678/96",
                                                     "2001:0db8:85a3:0000:0000:8a2e:2020:0-2001:0db8:85a3:0000:0000:8a2e:2020:5"                                        
                                ]
                          }
     ]
}


{
  "version": "1.0",
  "objects": [
    {
      "ranges": [
        "167.165.0.0/24",
        "167.165.0.0/24",
        "167.165.0.0/24",
        "167.165.0.0/24",
        "167.165.0.0/24",
        "167.165.0.0/24",
        "167.165.165.0/24",
        "167.165.165.0/24",
        "167.165.165.0/24",
        "167.165.165.0/24",
        "167.165.165.0/24",
        "167.165.165.0/24"
      ],
      "id": "e7f18b60-f22d-4f42-8dc2-050490e45688",
      "description": "",
      "name": "ASN-AS394534"
    }
  ],
  "description": "Generic Data Center file"
}

