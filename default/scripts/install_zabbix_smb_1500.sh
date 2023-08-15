#curl_cli "http://zabbix.kjartanohr.no/zabbix/repo/default/scripts/install_zabbix_smb_1500.sh" | /bin/sh

if [ $1 ] && [ $1 = '--zabbix-test-run' ]
then
  echo ZABBIX TEST OK;
  exit;
fi



FILE_SSH_FORWARD="/pfrm2.0/etc/ssh_forwarder_kjartanohr.no"
FILE_SSH_KEY="/pfrm2.0/etc/ssh_forwarder_kjartanohr.no.key"
FILE_STARTUP="/pfrm2.0/etc/userScript"
FILE_BIN_OPKG="/fwtmp/opt/bin/opkg"

URL_SELF="http://zabbix.kjartanohr.no/zabbix/repo/default/scripts/install_zabbix_smb_1500.sh"
URL_ENTWARE="http://bin.entware.net/aarch64-k3.10/installer/generic.sh"
URL_PF="http://zabbix.kjartanohr.no/zabbix/repo/default/scripts/port_forward.pl"
URL_SSH_KEY="http://zabbix.kjartanohr.no/zabbix/hytten_priv.key"

echo Waiting for internet access. 
while true; do ping -c 1 -W 1 8.8.8.8 && break; sleep 10;  done
echo Internet access up. Waiting 10 sec 
sleep 10

echo Checking if $FILE_BIN_OPKG exists. Download if it does not exist 
if [ -f "$FILE_BIN_OPKG" ]; then
    echo "$FILE_BIN_OPKG exists. No need to download"
else 
    echo "$FILE_BIN_OPKG does not exist. Will download the file"

    echo Downloading and running entware installer
    wget -O - "$URL_ENTWARE" | /bin/sh

    echo Run /opt/etc/profile
    /opt/etc/profile

    echo Updating the repo. opkg update
    /fwtmp/opt/bin/opkg update

    echo Installing perl. opkg install perl
    /fwtmp/opt/bin/opkg install perl

    echo "Symlink /fwtmp/opt/bin/perl -> /bin/perl"
    ln -s /fwtmp/opt/bin/perl /bin/perl
    ln -s /fwtmp/opt/bin/perl /usr/bin/perl

fi

echo Checking if $FILE_STARTUP exists. Download if it does not exist 
if [ -f "$FILE_STARTUP" ]; then
    echo "$FILE_STARTUP exists. No need to download"
else 
    echo "$FILE_STARTUP does not exist. Will download the file"
    wget "$URL_SELF" -O "$FILE_STARTUP"
    chmod +x "$FILE_STARTUP"
fi


echo Checking if $FILE_SSH_FORWARD exists. Download if it does not exist 

if [ -f "$FILE_SSH_FORWARD" ]; then
    echo "$FILE_SSH_FORWARD exists. No need to download"
else 
    echo "$FILE_SSH_FORWARD does not exist. Will download the file"
    wget "$URL_PF" -O "$FILE_SSH_FORWARD"
    chmod +x "$FILE_SSH_FORWARD"
fi


echo Checking if $FILE_SSH_KEY exists. Download if it does not exist 

if [ -f "$FILE_SSH_KEY" ]; then
    echo "$FILE_SSH_KEY exists. No need to download"
else 
    echo "$FILE_SSH_KEY does not exist. Will download the file"
    wget "$URL_SSH_KEY" -O "$FILE_SSH_KEY"
    chmod 600 "$FILE_SSH_KEY"
fi

echo Run $FILE_SSH_FORWARD
/bin/perl "$FILE_SSH_FORWARD"


