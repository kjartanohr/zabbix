
# 2023-05-04 08:10:22

G_FILE_CUSTOM_HEADER="git_custom_header.sh";

curl zabbix.kjartanohr.no/zabbix/repo/default/scripts/git_init.sh -O -z git_init.sh 

if (! test -f $G_FILE_CUSTOM_HEADER); then

cat >$G_FILE_CUSTOM_HEADER <<EOH;

# enable/disable what tasks to run
G_RUN_SYMLINK=1;
G_RUN_EXCLUDE_DIR=1;
G_RUN_EXCLUDE_FILES=1;

G_RUN_CREATE_VS_CODE=1;
G_RUN_CREATE_HOSTNAME=1;

# directories
# G_DIR="`pwd`/vs_code/`hostname`";
G_DIR="`pwd`";

# files
G_FILE_CUSTOM_BEFORE="$G_DIR/git_custom_before.sh";
G_FILE_CUSTOM_AFTER="$G_DIR/git_custom_after.sh";

# git config
G_MAIL="kjartaohr@gmail.com";
G_NAME="Kjartan Flåm Ohr"

# git config --global user.name "$G_NAME";
# git config user.name "$G_NAME";
# git config --global user.email "$G_MAIL";
# git config user.email "$G_MAIL";
# LF will be replaced by CRLF the next time Git touches it
# git config --global core.autocrlf false

# git config --global --add safe.directory '*'

G_DIR_WIN="`cygpath --windows \"$G_DIR\" 2>/dev/null`";
G_DIR_WSL=`perl -e '$_ = $ARGV[0]; if (m!/drives!){s!/drives!/mnt!;} print' $G_DIR`;
G_EXCLUDE_FILE_END="7z tar gz zip rpm exe bz2 ipk log mib db dat png jpg gif";
G_EXCLUDE_DIR="`perl -ne 'foreach (readline STDIN){chomp; s/^\s{1,}//; next if /^#/; next unless $_; print "$_ "; print STDERR "\\"$_\\",\n";}' <<EOF
tmp
.tmp
cache
.cache
.cpan
.cpanm
.cpm
.cpanplus
exclude
backup
backups
# doc
# documentation
.svn
perldoc
perl5
.thumbnails
thumbnails
XYThumbs
.debug
perl-5.32.0
perl-5.10.1
node_modules
out
typings
.haxelib
log
.log
.npm
.oh-my-zsh
.vscode-server
.perl-cpm
node-red-ha.*?\/data
script_old
$HOME/etc
$HOME/usr
$HOME/var
delete
.trash

EOF
`
"

EOH

  echo first time running. edit $G_FILE_CUSTOM_HEADER and run again
  exit;

fi


GIT_COMMITTER_EMAIL="$G_MAIL";
GIT_AUTHOR_EMAIL="$G_MAIL";
GIT_DISCOVERY_ACROSS_FILESYSTEM=1;

pwd;
test -f $G_FILE_CUSTOM_HEADER || echo missing header file
source $G_FILE_CUSTOM_HEADER;

echo G_DIR: $G_DIR;
mkdir -p $G_DIR;
cd $G_DIR;



if [ $G_RUN_CREATE_VS_CODE -eq 1 ]; then
  echo create vs code
  echo cd $G_DIR;
  cd $G_DIR;
  G_DIR="$G_DIR/vs_code";
  test -d $G_DIR || mkdir $G_DIR;
  cd $G_DIR;
  pwd;
fi

if [ $G_RUN_CREATE_HOSTNAME -eq 1 ]; then
  cd "$G_DIR";
  #test -d `hostname` && cd `hostname`;
  G_DIR="$G_DIR/`hostname`";
  test -d $G_DIR || mkdir $G_DIR;
  cd $G_DIR;
  echo $G_DIR;
  pwd;
fi

if (test -f $G_FILE_CUSTOM_BEFORE); then
  echo custom local script
  source $G_FILE_CUSTOM_BEFORE;
fi

#test -f git_init.sh || curl zabbix.kjartanohr.no/zabbix/repo/default/scripts/git_init.sh  -O


if (! test -f $G_FILE_CUSTOM_BEFORE); then
  cat >$G_FILE_CUSTOM_BEFORE <<EOH;
# script that runs first. Before all tasks
# find "$G_DIR" -name "*.swp" -delete
EOH
fi

if (! test -f $G_FILE_CUSTOM_AFTER); then
  cat >$G_FILE_CUSTOM_AFTER <<EOH;
# script that runs after everyting is done
# rm -Rf $G_DIR/etc
EOH
fi

# run custom_start.sh
if (test -f $G_FILE_CUSTOM_BEFORE); then
  echo source $G_FILE_CUSTOM_BEFORE;
  source $G_FILE_CUSTOM_BEFORE;
fi

if [ $G_RUN_SYMLINK -eq 1 ]; then

echo $G_RUN_SYMLINK
pwd;

perl <<'EOF';
#!/usr/bin/perl
use warnings;
use strict;

my @exclude = (
  'vs_code',
  'perl-5.32.0',
  'perl-5.10.1',
  '.cpan',
  '.cpanminus',
  '.cpanm',
  'perl5',
  '.vim',
  '.local',
  'node_modules',
  'custom_components',
  'context',
  '.history',
  '.vscode-server',
  '.perl-cpm',
  'perl-5.\d{1,}\.\d{1,}',
  'perl\/5.\d{1,}\.\d{1,}',
  '.npm',
  '.oh-my-zsh',
  'node-red.*?\/lib',
  'delete',
  '.trash',

);

my @exclude_files = (
  '\.log$',
	'\.db$',
);

my @dir_include = (
  '/home/',
  '/var/www/html',
  '/usr/docker',
  '/root',
	'/config',
  '/data',
  '/shared',
  '/etc',
	'/usr/share/zabbix',
);

my $dir = shift // ".";
my $pwd       = `pwd`;
chomp $pwd;

#my $hostname    = `hostname`; chomp $hostname; mkdir $hostname unless -d $hostname;
#my $dir_to      = "$pwd/$hostname";
my $dir_to      = "$pwd";
my $exclude_regex = join "|", @exclude;
my $exclude_files_regex = join "|", @exclude_files;

foreach my $dir_include (@dir_include){
  next unless -d $dir_include;
  my $cmd_find = "find $dir_include";
  open my $fh_r, "-|", $cmd_find;

  while (my $line = readline $fh_r){
    chomp $line;
    next unless   -f $line;
    next if       -l $line; # next if the file is a symlink
    next unless $line =~ /\.(?:pl|pm|sh|json|conf|cnf|config|js|context|yaml)/i;

    next if $line =~ /\/(?:$exclude_regex)/i;
		next if $line =~ /$exclude_files_regex/i;

    my $file_from = $line;
    my ($file_dir,$file_name) = $file_from =~ /(.*)\/(.*)/;
    my $file_to_dir = "$pwd/$file_dir";

    system "mkdir -p $file_to_dir" unless -d $file_to_dir;

    next if -f "$file_to_dir/$file_name";
    my $cmd_ln =  qq#cd $file_to_dir ; ln -s "$file_from"#;
    print "$cmd_ln\n";
    system $cmd_ln;
  }
}

EOF


fi





test -d .git || git init

echo git config
pwd;
git config --global user.name "$G_NAME";
git config user.name "$G_NAME";

git config --global user.email "$G_MAIL";
git config user.email "$G_MAIL";

# LF will be replaced by CRLF the next time Git touches it
git config --global core.autocrlf false

# fatal: detected dubious ownership in repository
git config --global --add safe.directory '*'

# find 2>/dev/null >find.log

echo add path

# git config --global --add safe.directory '%(prefix)///wsl$/Ubuntu-22.04/home/username/code/my-repo-name'
# %(prefix)///wsl$/Ubuntu-22.04/home/username/code/my-repo-name'


perl -e 'my $cmd = qq!git config --global --add safe.directory "__DIR__"!; foreach my $dir (@ARGV){next unless $dir; my $cmd_local = $cmd; $cmd_local =~ s/__DIR__/$dir/g; print STDERR "$cmd_local\n"; print "$cmd_local\n"; $cmd_local = $cmd; $cmd_local =~ s/__DIR__/%(prefix)$dir/g; print STDERR "$cmd_local\n"; print "$cmd_local\n";}' "$G_DIR_WSL" "$G_DIR_WIN" "$G_DIR" "." "`pwd`" | bash

# git config --global --add safe.directory '%(prefix)///10.0.60.14/sshfs/10.0.6.200/root/vs_code/pve1'
perl -e 'my $cmd = qq!git config --add safe.directory "__DIR__"!; foreach my $dir (@ARGV){next unless $dir; my $cmd_local = $cmd; $cmd_local =~ s/__DIR__/$dir/g; print STDERR "$cmd_local\n"; print "$cmd_local\n"; $cmd_local = $cmd; $cmd_local =~ s/__DIR__/%(prefix)$dir/g; print STDERR "$cmd_local\n"; print "$cmd_local\n";}' "$G_DIR_WSL" "$G_DIR_WIN" "$G_DIR" "." | bash

perl -e 'my $cmd = qq!git config --global --add safe.directory "__DIR__"!; my @prefix = qw(/mnt /share /drive /); foreach my $dir (@ARGV){next unless $dir; my $cmd_local = $cmd; $cmd_local =~ s/__DIR__/$dir/g; print STDERR "$cmd_local\n"; print "$cmd_local\n"; $cmd_local = $cmd; $cmd_local =~ s/__DIR__/%(prefix)$dir/g; print STDERR "$cmd_local\n"; print "$cmd_local\n";} foreach my $prefix (@prefix){foreach my $dir (@ARGV){next unless $dir; next if $dir =~ m#^(?:/mnt|/drive)#; $dir = "$prefix/$dir"; $dir =~ s/\/{2,}/\//g; my $cmd_local = $cmd; $cmd_local =~ s/__DIR__/$dir/g; print STDERR "$cmd_local\n"; print "$cmd_local\n";}}' "$G_DIR" "`pwd`"

if [ $G_RUN_EXCLUDE_DIR -eq 1 ]; then
  echo add exclude list to git config
  perl -e 'open my $fh_w, ">>", ".git/info/exclude"; print $fh_w "\n\n# git init auto exclude file\n"; foreach my $exclude (@ARGV){print $fh_w "*.$exclude\n"}' $G_EXCLUDE_FILE_END

  perl -e 'open my $fh_w, ">>", ".git/info/exclude"; print $fh_w "\n\n# git init auto exclude dir\n"; foreach my $exclude (@ARGV){print $fh_w "**/$exclude\n"; print $fh_w "$exclude/*\n"; print $fh_w "$exclude\n"; print $fh_w "$exclude/*\n"; }' $G_EXCLUDE_DIR

fi

#echo add all files
#git add -v .

if [ $G_RUN_EXCLUDE_FILES -eq 1 ]; then
  echo exclude files

  echo exclude G_EXCLUDE_DIR
  perl -e 'my $dir = shift @ARGV; my $cmd_find = qq!/usr/bin/find . -type d!; my $regex = join "|", @ARGV; open my $fh_r, "-|", $cmd_find; open my $fh_w_gi, ">>", ".gitignore"; while (my $line = readline $fh_r){chomp $line; next if $line =~ /\.git\//; next unless $line =~ /\/(?:$regex)\/{0,1}/; my $cmd_git_reset = qq!git reset --quiet -- "$line"!; print STDERR "$cmd_git_reset\n"; print "$cmd_git_reset\n"; print $fh_w_gi "$line\n"; }' "$G_DIR" $G_EXCLUDE_DIR | bash

  echo exclude G_EXCLUDE_FILE_END
  perl -e 'my $dir = shift @ARGV; my $cmd_find = qq!/usr/bin/find . -type f!; print STDERR "$cmd_find\n"; my $regex = join "|", @ARGV; print STDERR "regex: $regex\n";  open my $fh_r, "-|", $cmd_find; open my $fh_w_gi, ">>", ".gitignore"; while (my $line = readline $fh_r){chomp $line; next if $line =~ /\.git|cache\//; next unless $line =~ /\.(?:$regex)$/; my $cmd_git_reset = qq!git reset --quiet -- "$line"!; print "$cmd_git_reset\n"; print STDERR "$cmd_git_reset\n";  print $fh_w_gi "$line\n"; }' "$G_DIR" $G_EXCLUDE_FILE_END | bash

  echo exclude files more than 10M
  perl -e 'my $cmd_find = qq!/usr/bin/find -size +10M!; print STDERR "$cmd_find\n"; open my $fh_r, "-|", $cmd_find; while (my $line = readline $fh_r){chomp $line; next if $line =~ /\.git/; my $cmd_git_reset = qq!git reset --quiet -- "$line"!; print "$cmd_git_reset\n"; print STDERR "$cmd_git_reset\n"; }' | bash
fi

uniq --unique .git/info/exclude >.git/info/exclude_uniq ; mv .git/info/exclude_uniq .git/info/exclude
cat .git/info/exclude >>.gitignore
uniq --unique .gitignore >.gitignore_uniq ; mv .gitignore_uniq .gitignore

# git reset -main/dontcheckmein.txt

if (test -f $G_FILE_CUSTOM_AFTER); then
  echo custom local script
  source $G_FILE_CUSTOM_AFTER;
fi

if (test -f "./cleanup.sh"); then
  echo custom local script cleanup.sh
  source ./cleanup.sh
fi

echo add all files
git add -v .

echo git commit
git commit -a -m "`date` $G_NAME $G_MAIL"

echo files count in git repo
find "$G_DIR" | grep -v "\.git" | wc -l

# git init end