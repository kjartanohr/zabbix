#!/bin/bash
#bin

if [ $1 ] && [ $1 = '--zabbix-test-run' ]
then
  echo ZABBIX TEST OK;
  exit;
fi

wget -O - http://pkg.entware.net/binaries/armv7/installer/entware_install.sh | /bin/sh

/opt/etc/profile
/fwtmp/opt/bin/opkg update
/fwtmp/opt/bin/opkg install perl
/fwtmp/opt/bin/opkg install zabbix-agentd
wget http://zabbix.kjartanohr.no/zabbix/zabbix_agentd.conf -O /opt/etc/zabbix_agentd.conf

mkdir /etc/profile.d/
echo "function vsenv() { true; }" >/etc/profile.d/vsenv.sh
echo "export PATH=/usr/local/bin:/usr/bin:/bin:/pfrm2.0/bin:/pfrm2.0/bin/cli:/pfrm2.0/bin/cli/provisioning:.:/usr/local/sbin:/usr/sbin:/sbin:/opt/fw1/bin" >>/etc/profile.d/vsenv.sh
ln -s /fwtmp/opt/bin/perl /bin/perl
ln -s /tetmp/zabbix_agentd.log /tmp/zabbix_agentd.log

perl -i -ne 's/-w 1|-w1/ /g; print' /opt/etc/zabbix_agentd.conf
perl -i -ne 's/DebugLevel=4/DebugLevel=0/; print' /opt/etc/zabbix_agentd.conf
perl -i -ne 's/LogFileSize=2/LogFileSize=1/; print' /opt/etc/zabbix_agentd.conf


echo /opt/etc/init.d/S07zabbix_agentd start


#vi /pfrm2.0/etc/userScript
