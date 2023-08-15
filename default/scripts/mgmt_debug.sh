#!/bin/bash
# script to start debugs , stop debugs and collect logs , send Tar files to ftp
#  -m mode : on/off/send
#  -s severity : ERROR , WARNING , INFO , TRACE
#  -t topics  
#  -c classes
#  -ip ftp server ip_address 
#  -username ftp server username
#  -password ftp server password
#  must run the script with all the parameters ,otherwise it will exit and write error message about wrong usage


if [ $1 ] && [ $1 = '--zabbix-test-run' ]
then
  echo ZABBIX TEST OK;
  exit;
fi


#given parameters 
all_flags_string="-m -c -t -s"
mode="null"
severity="null"
machine_type="null"
cma_name="null"
all_topics_from_parameters="null"
all_classes_from_parameters="null"

ip="null"
username="null"
password="null"

#counters
class_topic_counter=0

#flags counters
mode_counter=0;
topic_counter=0
class_counter=0
severity_counter=0
ip_counter=0
username_counter=0
password_counter=0

#topics and classes number
topics_number=0
classes_number=0


#------------------------------------------------------------------------------------usage--------------------------------------------------------------------------------------------------------------------------------------
usage() 
{
cat <<EOF
Usage: $0 [options] [--] [file...]

ZABBIX TEST OK

Arguments:

  -m <mode>
    mode : on , off , send
    on : to start debugging 
    off: to stop debugging && compress all logs files into tar.gz file -- tar.gz logs files cna be found in : $MDS_FWDIR/log/mgmt_debug_output
    send: send the tar.gz file (all logs) to ftp server
    
--------------topics , classes ----------------  (optional)
  -t <topics_names>
  topics : must use valid topics names
  
  -c <classes_names>
  classes : must use valid classes names
--------------------------------------------------- 
  -s <severity>
  severity : DEBUG , WARNING , INFO , TRACE , ERROR
---------------------------------------------------   
  -ip <ip_address>
  ftp server ip
  
  -username <ftp_username> 
  ftp server username

  -password <ftp_password>
  ftp server password
-------------------------------------------------------
-------------------------------------------------------
  examples : 
  
  enbaling debug on mds level on topic HA and severity DEBUG
   you must be in mds level , use "mdsenv" command 
   ./mgmt_debug.sh -m on -t HA -s DEBUG
  
  enabling debug on cma name test_Server on topic HA and severity WARNING
  1) mdsenv test_Server
  1.1) ./mgmt_debug.sh -m on -t HA -s WARNING 
  
  enabling debug on mgmt(SmartCenter) on topic HA and severity DEBUG
   must be in mgmt machine 
   ./mgmt_debug.sh -m on -t HA -s DEBUG
  
  disabling debug and collecting logs files on mds level on topic HA and severity DEBUG
   you must be in mds level , use "mdsenv" command
   ./mgmt_debug.sh -m off -t HA 
  
  disabling debug and collecting logs files on cma name test_Server on topic HA and severity DEBUG
  1) mdsenv test_Server
  1.1) ./mgmt_debug.sh -m off -t HA 
  
  disabling debug and collecting logs files on mgmt(SmartCenter) on topic HA and severity DEBUG
   must be in mgmt machine
   ./mgmt_debug.sh -m off -t HA  
  
  sending logs file to ftp , ip XX.YY.ZZ.CC , username admin , password 1234 
  ./mgmt_debug.sh -m send -ip XX.YY.ZZ.CC -username admin -password 1234

-------------------------------------------------------
------------------------------------------------------- 
  examples for combine between topics and classes 
  Start debugging a SmartCenter machine , topics HA && Permission , classes CacheSvcImpl && LinksManagerSvcImp, severity WARNING
   must be in mgmt machine
   ./mgmt_debug.sh -m on -t HA Permissions -c CacheSvcImpl LinksManagerSvcImpl -s WARNING

  Stop debug & compress log files on SmartCenter machine , topics HA && Permission , classes CacheSvcImpl && LinksManagerSvcImp
   must be in mgmt machine
   ./mgmt_debug.sh -m off -t HA Permissions -c CacheSvcImpl LinksManagerSvcImpl

EOF
}
#---------------------------------------------------------------------------------------log-----------------------------------------------------------------------------------------------------------------------------------
log()
{
 printf '%s\n' "$*" 
}
#---------------------------------------------------------------------------------------error--------------------------------------------------------------------------------------------------------------------------------------
error() 
{ 
log "ERROR: $*" >&2
}
#---------------------------------------------------------------------------------------fatal--------------------------------------------------------------------------------------------------------------------------------
fatal()
{
error "$*"
exit 1
}
#----------------------------------------------------------------------------------------usage_fatal-------------------------------------------------------------------------------------------------------------------------
usage_fatal()
{
 error "$*"
 usage >&2
 exit 1
}
#----------------------------------------------------------------------------------------parse_parameters----------------------------------------------------------------------------------------------------------------------
parse_parameters()
{
  while [ "$#" -gt 0 ]; do
    arg=$1
    case $1 in
        -h) usage_fatal "help menu";;
        -m) is_mode_first_time; shift; mode=$1;;
        -t) is_topic_first_time; ((class_topic_counter++)); shift; all_topics_from_parameters=$1; get_all_topics_from_parameters $@; shift $topics_number;;
        -s) is_severity_first_time; shift; severity=$1;; 
        -c) is_class_first_time; ((class_topic_counter++)); shift; all_classes_from_parameters=$1; get_all_classes_from_parameters $@; shift $classes_number;;
        -ip) shift; ip=$1;;
        -username) shift; username=$1;;
        -password) shift; password=$1;;
         *) usage_fatal "unknown option: '$1'";;
    esac
    shift || usage_fatal "option '${arg}' requires a value"
done
}
#----------------------------------------------------------------------------------------get_all_topics_from_parameters--------------------------------------------------------------------------------------------------
get_all_topics_from_parameters()
{
#check if the word is not 1 of the flags then ok else exit from the function ,, return 
while [ "$#" -gt 0 ]; do

shift 

for string in $all_flags_string; do

if [ "$1" == "$string" ]
then
#echo "$1 in all_flags_string"
return
fi
done

#its not a flag , add it to the topics 
all_topics_from_parameters="$all_topics_from_parameters $1"
((topics_number++))
done
((topics_number--))
}
#----------------------------------------------------------------------------------------get_all_classes_from_parameters--------------------------------------------------------------------------------------------------
get_all_classes_from_parameters()
{
#check if the word is not 1 of the flags then ok else exit from the function ,, return 
while [ "$#" -gt 0 ]; do

shift 

for string in $all_flags_string; do

if [ "$1" == "$string" ]
then
#echo "$1 in all_flags_string"
return
fi
done

#its not a flag , add it to the classes 
all_classes_from_parameters="$all_classes_from_parameters $1"
((classes_number++))
done
((classes_number--))
}
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
is_mode_first_time()
{
  if [ "$mode_counter" == "0" ]
    then
      mode_counter=1
      return
    else
      fatal "cant use the flag -m more than one time"
  fi  
}
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
is_topic_first_time()
{
  if [ "$topic_counter" == "0" ]
    then
      topic_counter=1
      return
    else
      fatal "cant use the flag -t more than one time"
  fi  
}
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
is_class_first_time()
{
  if [ "$class_counter" == "0" ]
    then
      class_counter=1
      return
    else
      fatal "cant use the flag -c more than one time"
  fi  
}
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
is_severity_first_time()
{
  if [ "$severity_counter" == "0" ]
    then
      severity_counter=1
      return
    else
      fatal "cant use the flag -s more than one time"
  fi  
}

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
is_ip_first_time()
{
  if [ "$ip_counter" == "0" ]
    then
      ip_counter=1
      return
    else
      fatal "cant use the flag -ip more than one time"
  fi  
}
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
is_username_first_time()
{
  if [ "$username_counter" == "0" ]
    then
      username_counter=1
      return
    else
      fatal "cant use the flag -username more than one time"
  fi  
}
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
is_password_first_time()
{
  if [ "$password_counter" == "0" ]
    then
      password_counter=1
      return
    else
      fatal "cant use the flag -password more than one time"
  fi  
}
#-------------------------------------------------------------------------------------------check_is_all_topics_valid------------------------------------------------------------------------------------------------------------------
check_is_all_topics_valid()
{
#check if the topic exist in tdlog_topic.xml
cd $MDS_FWDIR/conf
all_topics="$(grep -o -P '(?<=name=).*(?=>)' tdlog_topic.xml)"

if [ -z "$all_topics" ]
then
fatal "can't find tdlog_topic.xml file "
fi

for topic in $@; do
check_is_topic_valid $topic $all_topics
done

}
#-------------------------------------------------------------------------------------------check_is_topic_valid--------------------------------------------------------------------------------------------------------------------
check_is_topic_valid()
{

parameter_topic=$1

#build 2 words with '' and ""
temp1="'$parameter_topic'"
temp2="\"$parameter_topic\""

#shift away the topic from the parameter ,, to stay with all the right topics
shift

for word in $@ ; do 

#case to check with ' ' 

case "$temp1" in
  ${word}) return 0 ;;
  
esac

#case to check with " "  

case "$temp2" in
  ${word}) return 0 ;;
  
esac

done

fatal "$parameter_topic is an invalid Topic"
}

#-------------------------------------------------------------------------------------------check_is_severity_valid----------------------------------------------------------------------------------------------------------
check_is_severity_valid()
{
if [ "$severity" != "ERROR" ] && [ "$severity" != "WARNING" ] && [ "$severity" != "INFO" ] && [ "$severity" != "DEBUG" ] && [ "$severity" != "TRACE" ]
then
  fatal "Invalid severity , choose one from ERROR,WARNING,INFO,DEBUG,TRACE"
fi
}

#-------------------------------------------------------------------------------------------check_is_mode_valid---------------------------------------------------------------------------------------------------------------
check_is_mode_valid()
{

#check if mode is inserted
if [ "$mode" == "null" ]
  then
    usage_fatal "You must Insert mode "
fi

#check if mode is valid
if [ "$mode" != "on" ] && [ "$mode" != "off" ] && [ "$mode" != "send" ]
  then
    fatal "Invalid mode , choose one from on,off,send"
fi
}
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
auto_identify_machine_type()
{
fwdir_full_path=$(echo $FWDIR)

# need to auto identify in which machine we are 

# checking if the output of $FWDIR have customer word  ---> then we are inside CMA 
customers_counter=`echo $FWDIR | grep -c customers`

# checking if the output of $FWDIR have CPmds  ---> then we are inside CPmds (must be without customers)
CPmds_counter=`echo $FWDIR | grep -c CPmds`

# checking both of them are not found then we are in MGMT
if [ "$customers_counter" == "1" ]
  then
    machine_type="cma"
    cma_name=$(echo $fwdir_full_path | cut -d '/' -f 5)
  else
    if [ "$CPmds_counter" == "1" ]
      then
        machine_type="mds"
      else
        machine_type="mgmt"
    fi 
fi
}

#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# mode on , off  must have 1 machine type , topic or class , severity , and must be in the right machine , given as parameters 
check_mode_on_off_parameters_validation()
{

#auto identify the machine type 
auto_identify_machine_type
  
#check if used one and only one topic 
if [ "$class_topic_counter" == "0" ]
  then
    all_topics_from_parameters="webservices"
    all_classes_from_parameters="com.checkpoint.management.dleserver"
    class_topic_counter="2"
fi
  
#----------------------------------------------------------------------------Topic check
#check if topic is inserted 
if [ "$all_topics_from_parameters" != "null" ]
  then
#check if topic is valid 
    check_is_all_topics_valid $all_topics_from_parameters
fi

#----------------------------------------------------------------------------Severity check
#check if severity is inserted 
if [ "$mode" == "on" ]
  then
    if [ "$severity" == "null" ]
      then
        usage_fatal "You must Insert severity "
    fi
    
    #check if severity is valid 
    check_is_severity_valid
fi 

}
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# mode send must have ip , username and password given as parameters 
check_mode_send_parameters_validation() 
{
if [ "$ip" == "null" ]
  then
    fatal " You must insert ftp ip "
fi
  
if [ "$username" == "null" ]
  then
    fatal " You must insert ftp username "
fi
  
if [ "$password" == "null" ]
  then
    fatal " You must insert ftp password "
fi  
}
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------Start/Stop DEBUGS--------------------------------------------------------------------------------------------------------------------
start_fwm_debug()
{
case $machine_type in
  mds) fw debug mds on TDERROR_ALL_ALL=5 >/dev/null 2>&1; echo "successfully turn on mds_debug - mds level" ;;
  cma) fw debug fwm on TDERROR_ALL_ALL=5 >/dev/null 2>&1; echo "successfully turn on fwm_debug - cma" ;;
  mgmt)fw debug fwm on TDERROR_ALL_ALL=5 >/dev/null 2>&1; echo "successfully turn on fwm_debug - mgmt (SmartCenter)" ;;
esac
}
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
stop_fwm_debug()
{
case $machine_type in
  mds) fw debug mds off >/dev/null 2>&1; echo "successfully turn off mds_debug - mds level" ;;
  cma) fw debug fwm off >/dev/null 2>&1; echo "successfully turn off fwm_debug - cma" ;;
  mgmt)fw debug fwm off >/dev/null 2>&1; echo "successfully turn off fwm_debug - mgmt (SmartCenter)" ;;
esac
}
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
start_cpm_debug()
{
echo "running please wait..."
#starting cpm_debug.sh script with parameters , -t topic ,-s severity 

#if class_topic_counter = 2 then both are inserted
if [ "$class_topic_counter" == "2" ]
then
  $MDS_FWDIR/scripts/cpm_debug.sh -t $all_topics_from_parameters -c $all_classes_from_parameters -s $severity
  echo "successfully turn on cpm_debug "  
  echo "cpm_debug on topics : $all_topics_from_parameters "  
  echo "cpm_debug on classes : $all_classes_from_parameters "  
  echo "cpm_debug severity :- $severity"

else
#if not then 1 only inserted
if [ "$all_topics_from_parameters" != "null" ]
 then
	$MDS_FWDIR/scripts/cpm_debug.sh -t $all_topics_from_parameters -s $severity
  echo "successfully turn on cpm_debug "
  echo "cpm_debug on topics : $all_topics_from_parameters " 
  echo "cpm_debug severity :- $severity"
else
  $MDS_FWDIR/scripts/cpm_debug.sh -c $all_classes_from_parameters -s $severity
  echo "successfully turn on cpm_debug "
  echo "cpm_debug on classes : $all_classes_from_parameters "
  echo "cpm_debug severity :- $severity"
fi
fi
}
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
stop_cpm_debug()
{
echo "running please wait..."

#if class_topic_counter = 2 then both are inserted
if [ "$class_topic_counter" == "2" ]
then
  $MDS_FWDIR/scripts/cpm_debug.sh -t $all_topics_from_parameters -c $all_classes_from_parameters -s INFO
  echo "successfully turn off cpm_debug "  
  echo "cpm_debug on topics : $all_topics_from_parameters "  
  echo "cpm_debug on classes : $all_classes_from_parameters "  
  echo "cpm_debug severity :- INFO"  
#if not then 1 only inserted
else
if [ "$all_topics_from_parameters" != "null" ]
  then
    $MDS_FWDIR/scripts/cpm_debug.sh -t $all_topics_from_parameters -s INFO 
    echo "successfully turn off cpm_debug "
    echo "cpm_debug on topics : $all_topics_from_parameters "
    echo "cpm_debug severity :- INFO"
else
    $MDS_FWDIR/scripts/cpm_debug.sh -c $all_classes_from_parameters -s INFO
    echo "successfully turn off cpm_debug "
    echo "cpm_debug on classes : $all_classes_from_parameters "
    echo "cpm_debug severity :- INFO"
fi
fi
}
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
start_postgres_debug()
{
echo "successfully turn on postgres_debug"
#starting postgres_logs_on.sh script with auto enter 1 
echo "1" |. $MDS_FWDIR/scripts/postgres_logs_on.sh>/dev/null 2>&1;
}
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
stop_postgres_debug()
{
echo "successfully turn off postgres_debug"
#starting postgres_logs_off.sh script with auto enter 1 
echo "1" |. $MDS_FWDIR/scripts/postgres_logs_off.sh>/dev/null 2>&1;
}
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
start_solr_debug()
{
echo "successfully turn on solr_debug "
#starting solr_monitor_start.sh script 
echo "running please wait..."
$MDS_FWDIR/scripts/solr_monitor_start.sh
}
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
stop_solr_debug()
{
echo "successfully turn off solr_debug "
#starting solr_monitor_stop.sh script  
echo "running please wait..."
$MDS_FWDIR/scripts/solr_monitor_stop.sh
}

#--------------------------------------------------------------------------------------------start_debug-----------------------------------------------------------------------------------------------------------------------
start_debug()
{
start_cpm_debug
start_fwm_debug
start_solr_debug
start_postgres_debug

echo "Done - started all debugs successfully"
}
#--------------------------------------------------------------------------------------------stop_debug----------------------------------------------------------------------------------------------------------------
stop_debug()
{
stop_cpm_debug
stop_fwm_debug
stop_solr_debug
stop_postgres_debug

echo "Done - Stopped all debugs successfully"

#collecting logs files to TAR to ----> mgmt_debug_output folder
collect_logs_files

#count number of TAR files , and remove the first one created if there are more than 5
count_and_remove_tar_files
}
#--------------------------------------------------------------------------------------------try to connect to ftp----------------------------------------------------------------------------------------------------------------
collect_logs_files()
{

case $machine_type in
  mds) FOLDERSUFFIX="mds";;
  mgmt) FOLDERSUFFIX="mgmt";;
  cma) FOLDERSUFFIX="cma_$cma_name";;
esac

now=$(date +%d-%m-%Y-%H-%M-%S)
TARFILENAME=$FOLDERSUFFIX$now".tar.gz"

#create mgmt_debug_output folder if not exist
cd $MDS_FWDIR/log
if [ ! -d  "mgmt_debug_output" ]
  then
    echo "first time creating mgmt_debug_output directory"
    mkdir "mgmt_debug_output"
fi

#--------------------------------------------collec cpm logs
#cp $MDS_FWDIR/log/cpm.elg* $FOLDERNAME
cpm_logs=$MDS_FWDIR/log/cpm.elg*
#--------------------------------------------collect fwm/mds logs
if [ "$machine_type" == "mds" ]
  then
#cp $MDS_FWDIR/log/mds.elg* $FOLDERNAME
    fwm_logs=$MDS_FWDIR/log/mds.elg*
fi

if [ "$machine_type" == "cma" ]
  then
#cp $FWDIR/log/fwm.elg* $FOLDERNAME
    fwm_logs=$FWDIR/log/fwm.elg*
fi

if [ "$machine_type" == "mgmt" ]
  then
#cp $MDS_FWDIR/log/fwm.elg* $FOLDERNAME
    fwm_logs=$MDS_FWDIR/log/fwm.elg*
fi

#--------------------------------------------collect postgres logs
postgres_logs=$MDS_FWDIR/log/postgres.elg
#--------------------------------------------collect solr logs
solr_logs=$MDS_FWDIR/log/solr*
#--------------------------------------------collect api logs
api_logs=$MDS_FWDIR/log/api.*
#--------------------------------------------Creating Tar file

all_logs="$cpm_logs $fwm_logs $api_logs $solr_logs $postgres_logs "

echo "successfully statring to collect logs files into TAR file "

# -c – Creates a new .tar archive file.
# -v – Verbosely show the .tar file progress.
# -f – File name type of the archive file.
# -z – filter archive through gzip.
tar -cvzf $MDS_FWDIR/log/mgmt_debug_output/$TARFILENAME $all_logs 

echo "file path : $MDS_FWDIR/log/mgmt_debug_output/$TARFILENAME"

}
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
try_to_connect_to_ftp()
{
STATUS=`ftp -nv $ip <<EOF
user $username $password
bye
EOF`

is_logged_in_successfull=`echo $STATUS | grep -c "Logged on"`

if [ "$is_logged_in_successfull" -eq "1" ]
  then
    echo "connected successfully to ftp server"
  else
    fatal "failed to connect to ftp server"
fi
}

#--------------------------------------------------------------------------------------------send_logs_to_ftp----------------------------------------------------------------------------------------------------------------
send_logs_to_ftp()
{
#check the parameters validation
#check_mode_send_parameters_validation

#check if mgmt_debug_output folder if not exist
cd $MDS_FWDIR/log
if [ ! -d  "mgmt_debug_output" ]
  then
    fatal "you dont have logs , you must run debugs on , then debugs off before you try to send the logs "
fi

#checking connection to ftp server 
try_to_connect_to_ftp

#get the name of the last updated log file 
cd $MDS_FWDIR/log/mgmt_debug_output
last_updated_log_file_all_info=$(ls -lrt | tail -n 1)

if [ "$last_updated_log_file_all_info" == "total 0" ]
  then
    fatal "there  no tar logs files , please run debug on && off first then send them to ftp"
  else
    last_update_log_file_name=$(echo $last_updated_log_file_all_info | cut -d ' ' -f 9-)
fi
echo "last update : $last_update_log_file_name"

#send the generated TAR file from mgmt_debug_output folder to the ftp server 
connect_send_response=`ftp -nv $ip <<EOF
user $username $password
mput "$last_update_log_file_name"
echo "y"
bye
EOF`

#printing the response for all the commands
echo "$connect_send_response"

}
#--------------------------------------------------------------------------------------------send_logs_to_ftp----------------------------------------------------------------------------------------------------------------
count_and_remove_tar_files()
{
#log into mgmt_debug_output directory 
cd $MDS_FWDIR/log/mgmt_debug_output # change to mgmt_debug_output

#getting number of Tar files in the directory
number_of_tar_files=$(ls | wc -l)

#-----if we have more than 5 files then we are continuing to remove most old file-----
  while [ "$number_of_tar_files" -gt 5 ]; do
    #find the most old modified Tar file
    the_most_old_tar_file=$(ls -lt | tail -n 1)

    #getting the name of the Tar file 
    the_most_old_tar_file_name=$(echo $the_most_old_tar_file | cut -d ' ' -f 9-)

    #removing the Tar from the directory
    rm -f -- $the_most_old_tar_file 
    ((number_of_tar_files--))
  done

return 0

#echo "successfully deleted the oldest tar file : $the_most_old_tar_file_name "

}
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------Main Script--------------------------------------------------------------------------------------------------------------------

#parse parameters 
parse_parameters $@
#check if mode is inserted and valid 
check_is_mode_valid

#----------------------------------------------------------------------------On / Off --> must have severity , topics , classes , 1 machine type (if cma then must have cma_name)
if [ "$mode" == "on" ] || [ "$mode" == "off" ]
then
  check_mode_on_off_parameters_validation
fi

#----------------------------------------------------------------------------Send --> must have ip , username , password , machine 
if [ "$mode" == "send" ]
then
  check_mode_send_parameters_validation
fi

#----------------------------------------------------------------------------Go to the right scenario
#working in the right mode on/off/send
case $mode in
  on) start_debug;;
  off) stop_debug;;
  send) send_logs_to_ftp;;
esac

exit
