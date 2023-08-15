#!/bin/bash
#bin

if [ $1 ] && [ $1 = '--zabbix-test-run' ]
then
  echo ZABBIX TEST OK;
  exit;
fi

mkdir /usr/share/zabbix
curl -k -O http://zabbix.kjartanohr.no/zabbix/zabbix_agents_3.2.7.linux2_6.i386.tar.gz || curl_cli -k -O http://zabbix.kjartanohr.no/zabbix/zabbix_agents_3.2.7.linux2_6.i386.tar.gz 

tar xfz zabbix_agents_3.2.7.linux2_6.i386.tar.gz -C /usr/share/zabbix/
mkdir -p /usr/local/etc/
ln -s /usr/share/zabbix/conf/zabbix_agentd.conf /usr/local/etc/zabbix_agentd.conf

curl -k -O http://zabbix.kjartanohr.no/zabbix/perl-5.10.1_compiled.tar.gz || curl_cli -k -O http://zabbix.kjartanohr.no/zabbix/perl-5.10.1_compiled.tar.gz

tar xfz perl-5.10.1_compiled.tar.gz -C /usr/share/zabbix/bin/
ln -s /usr/share/zabbix/bin/perl-5.10.1/perl /bin/perl

curl_cli -s -k https://zabbix.kjartanohr.no/zabbix/repo/default/scripts/download_repo_scripts.pl | perl

/usr/share/zabbix/repo/scripts/auto/download_repo_script.pl
sleep 5
/usr/share/zabbix/repo/scripts/auto/install_perl_5.32.0.pl

	
/usr/share/zabbix/repo/scripts/auto/download_repo.pl http://zabbix.kjartanohr.no/zabbix/repo/__VER__/scripts/auto/ /usr/share/zabbix/repo/scripts/auto/

/usr/share/zabbix/repo/scripts/auto/download_repo.pl http://zabbix.kjartanohr.no/zabbix/repo/__VER__/files/debug_templates/ /usr/share/zabbix/repo/scripts/auto/
	
/usr/share/zabbix/repo/scripts/auto/download_repo.pl http://zabbix.kjartanohr.no/zabbix/repo/__VER__/files/auto/ /usr/share/zabbix/repo/files/auto/

grep zabbix /etc/rc.local || echo '/usr/share/zabbix/bin/zabbix_watchdog.pl & '>>/etc/rc.local
curl http://zabbix.kjartanohr.no/zabbix/zabbix_watchdog.pl >/usr/share/zabbix/bin/zabbix_watchdog.pl || curl_cli http://zabbix.kjartanohr.no/zabbix/zabbix_watchdog.pl >/usr/share/zabbix/bin/zabbix_watchdog.pl
chmod +x /usr/share/zabbix/bin/zabbix_watchdog.pl
nohup /usr/share/zabbix/bin/zabbix_watchdog.pl </dev/null >/dev/null 2>&1 & 

sleep 2

ps xauwef|grep zabb
ss -pleantu|grep zabb
sleep 1

tail -f /tmp/zabbix*.log
