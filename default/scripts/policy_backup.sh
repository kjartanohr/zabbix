find /var/opt/ -name state -type d 2>/dev/null | perl -ne 'my $date = `date "+%Y-%m-%d-%H-%M-%S"`; chomp $date; chomp; my $safe = $_; $safe =~ s/\W/_/g; my $cmd = "tar cfz $date-policy-$safe.tar.gz $_"; print "$cmd\n"; system $cmd'
