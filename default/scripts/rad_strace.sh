#!/bin/bash
#bin

if [ $1 ] && [ $1 = '--zabbix-test-run' ]
then
  echo ZABBIX TEST OK;
  exit;
fi

perl -e 'while (1){foreach (`ps wxa`){next if /perl|\/httpd|zabbix/; s/^\s{0,}//; s/\s{1,}$//; s/\s{2,}/ /g; s/^.*?\s{1,}.*?\s{1,}.*?\s{1,}.*?\s{1,}//; s/^\s{1,}//; if(defined $db{$_}){next}else{chomp; print "$_\n\n"; $db{$_} = 1;} }  }'strace -v -ff -F -q -v  -s 4000 -p `pgrep rad` 2>&1 | perl -ne 's/\<\.\.\. //; next if /\]\s(?:send resumed|gettimeofday|fcntl64|munmap|futex|fstat64|mmap2|poll|rt_sigprocmask|epoll_wait|close|_llseek|clock_gettime|ioctl|time|stat64)/; next if /This line starts the header|AutoUpdater|ENOENT|EAGAIN|libUEPMPIAddon.so|HKLM_registry|\.so|ReferenceCount|unfinished \./; s/\\n|\\r/\n/g; s/\\t/ /g; s/\s{2,}/ /g; print; print "\n";'
