#!/usr/bin/env bash

ulimit -n 10000

set +x
SCRIPT=`basename ${BASH_SOURCE[0]}`
USER_NAME=`whoami`

PORT=5201
INTERVAL=1
UDP=1
TIME=10
LENGTH=128K
REVERSE=1


function HELP() {
    NORM=`tput sgr0`
    BOLD=`tput bold`
    REV=`tput smso`
    echo -e \\n"Help documentation for ${BOLD}${SCRIPT}.${NORM}"\\n
    echo -e "${REV}Basic usage:${NORM} ${BOLD}$SCRIPT file.ext${NORM}"\\n
    echo "Command line switches are optional. The following switches are recognized."
	echo "${REV}-p or --port${NORM} --Sets the value for option ${BOLD}set server port to listen on/connect to to n${NORM}. Default is ${BOLD}5201${NORM}."
	echo "${REV}-f or --format${NORM} --Sets the value for option ${BOLD}[kmKM] format to report: Kbits, Mbits, KBytes, MBytes."
	echo "${REV}-i or --interval${NORM} --Sets the value for option ${BOLD}pause n seconds between periodic bandwidth reports; use 0 to disable${NORM}. Default is ${BOLD}1${NORM}."
	echo "${REV}-f or --file${NORM} --Sets the value for option ${BOLD}client-side: read from file and write to network; server-side: read from network and write to file."
	echo "${REV}-B or --bind${NORM} --Sets the value for option ${BOLD}bind to a specific interface."
	echo "${REV}-u or --udp${NORM} --Sets the value for option ${BOLD}use UDP rather than TCP. 1 to activate${NORM}. Default is ${BOLD}1${NORM}."
	echo "${REV}-b or --bandwidth${NORM} --Sets the value for option ${BOLD}n[KM] set target bandwidth to n bits/sec."
	echo "${REV}-t or --time${NORM} --Sets the value for option ${BOLD}time in seconds to transmit for${NORM}. Default is ${BOLD}10${NORM}."
	echo "${REV}-n or --bytes${NORM} --Sets the value for option ${BOLD}number of bytes to transmit (instead of -t)."
	echo "${REV}-k or --blockbount${NORM} --Sets the value for option ${BOLD}number of blocks (packets) to transmit (instead of -t or -n)."
	echo "${REV}-l or --length${NORM} --Sets the value for option ${BOLD}length of buffer to read or write${NORM}. Default is ${BOLD}128K${NORM}."
	echo "${REV}-P or --parallel${NORM} --Sets the value for option ${BOLD}number of parallel client streams to run."
	echo "${REV}-R or --reverse${NORM} --Sets the value for option ${BOLD}run in reverse mode (server sends, client receives). 1 to activate${NORM}. Default is ${BOLD}1${NORM}."
	echo "${REV}-w or --window${NORM} --Sets the value for option ${BOLD}n[KM] window size / socket buffer size (this gets sent to the server and used on that side too)."

    echo -e "${REV}-h${NORM}  --Displays this help message. No further functions are performed."\\n
    echo -e "Example: ${BOLD}$SCRIPT -h${NORM}"\\n
    exit 1
}

function COPY_RESULTS() {
    ssh -l ${2} ${1} "mkdir -p /opt/logs/iperf3/${finalname}/${finalname1}"
    rsync -r ${date_folder}/* ${2}@${1}:/opt/logs/iperf3/${finalname}/${finalname1}
    ssh -l ${2} ${1} "cd /opt/logs/ && ./add_this_result.py /opt/logs/iperf3/${finalname}/${finalname1}/summary_sorted.html /opt/logs/iperf3/${finalname}/${finalname1}/"
    echo "Test Ended"
    echo "LOOK FOR THE RESULTS AT THE RESULTS at http://${1}/iperf3/${finalname}/${finalname1}"
    exit 1
}

function START_POWER_MONITOR(){
            touch $PWD/power_monitor.log
            for pid in `pidof mpstat`
            do
                echo ${pid}>/dev/null 2>&1
            done
	        echo $1
            cmd="python3 get_power.py ${pid} ${PWD}/power_monitor.log ${1}"
            if [ "$VERBOSE" == 1 ]
            then
                echo "`date -u` :: ${cmd}"
            fi
            echo "`date -u` :: ${cmd}" >> cmdline.txt
            eval ${cmd} &
}


function START_SYS_MONITOR(){
            touch $PWD/${LOG_LOCATION}/monitor.log
            mpstat -P ALL 5 | tr -s " " | sed 's/ /,/g' | grep -v '^$' | \
		 grep -v -e '^[A-Z][a-z].*' >> stat.csv &

	    for pid in `pidof mpstat`
            do
                echo ${pid}>/dev/null 2>&1
            done
            cmd="python monitor.py ${date_folder} $pid ${PWD}/${LOG_LOCATION}/monitor.log \
                benchlog_fn.log ${PWD}/${LOG_LOCATION}/monitor.html ${1}"
            if [ "$VERBOSE" == 1 ]
            then
                echo "`date -u` :: ${cmd}"
            fi
            echo "`date -u` :: ${cmd}" >> cmdline.txt
            eval ${cmd} &
}

function ENVIRONMENT_VERSIONS(){
../common/environment.sh
}

function KILL_MPSTAT(){
    if [ "$VERBOSE" == 1 ]
    then
        cmd="sudo killall mpstat"
        echo "`date -u` :: ${cmd}"
    else
        cmd="sudo killall mpstat>/dev/null 2>&1"
    fi
    eval ${cmd}
}

function CLEAN_UP(){
    cd ..
    find . -name *.py -type f -delete
    find . -name *.sh -type f -delete
    find . -name hosts.txt -type f -delete
    find . -name chart-template.html -type f -delete
    find . -name benchlog_fn.log -type f -delete
    cd client0
}

NUMARGS=$#
if [ $NUMARGS -eq 0 ]; then
  HELP
fi

if ! options=$(getopt -o s:c:C:w:u:x:y:hv:p:f:i:f:B:u:b:t:n:k:l:P:R:w: -l server:,webserver:,username:,client:,prefile:,postfile:,help,verbose_count:,port:,format:,interval:,file:,bind:,udp:,bandwidth:,time:,bytes:,blockbount:,length:,parallel:,reverse:,window: -- "$@")
then
    exit 1
fi

set -- $options
while [ $# -gt 0 ]
do
    case $1 in
        -s|--server) SYS_NAME="${2//\'/}" HOST_NAME="${2//\'/}" ;shift;;
        -w|--webserver) WEBSERVER="${2//\'/}" ;shift;;
        -u|--username) USER_NAME="${2//\'/}" ;shift;;
        -c|--client) CLIENT="${2//\'/}" ;shift;;
        -C|--Comment) shift;;
        -h|--help) HELP;;
        -v|--verbose_count) VERBOSE=1;shift;;
        -x|--prefile) shift;;
        -y|--postfile) shift;;
		-p|--port) PORT="${2//\'/}" ; shift;;
		-f|--format) FORMAT="${2//\'/}" ; shift;;
		-i|--interval) INTERVAL="${2//\'/}" ; shift;;
		-f|--file) FILE="${2//\'/}" ; shift;;
		-B|--bind) BIND="${2//\'/}" ; shift;;
		-u|--udp) UDP="${2//\'/}" ; shift;;
		-b|--bandwidth) BANDWIDTH="${2//\'/}" ; shift;;
		-t|--time) TIME="${2//\'/}" ; shift;;
		-n|--bytes) BYTES="${2//\'/}" ; shift;;
		-k|--blockbount) BLOCKCOUNT="${2//\'/}" ; shift;;
		-l|--length) LENGTH="${2//\'/}" ; shift;;
		-P|--parallel) PARALLEL="${2//\'/}" ; shift;;
		-R|--reverse) REVERSE="${2//\'/}" ; shift;;
		-w|--window) WINDOW="${2//\'/}" ; shift;;

        --) break;;
        -*) ;;
        *) break;;
    esac
    shift
done


date_folder=$(dirname $PWD)
comment_folder=$(dirname ${date_folder})
finalname=$(basename parentdir="$(dirname "$date_folder")")
finalname1=$(basename parentdir="$(dirname "$PWD")")

sudo chmod -R 760 $PWD
touch iperf3.type

logdate=$(date +%F)

#TODO: Define ${LOG_LOCATION} and ${logfile}
mkdir -p ${LOG_LOCATION}

#TODO:FIRETESTS

touch $PWD/${LOG_LOCATION}/monitor.log
touch $PWD/${LOG_LOCATION}/power_monitor.log

START_SYS_MONITOR ${SYS_NAME}
START_POWER_MONITOR ${SYS_NAME}

echo -n "Power:" >> ${LOG_LOCATION}/${logfile}

KILL_MPSTAT
sleep 10
cat powerstats.csv >> ${LOG_LOCATION}/${logfile}

cp powerstats.csv $PWD/${LOG_LOCATION}
cp power_monitor.log $PWD/${LOG_LOCATION}

echo "Collecting Results"
scp -r ${USER_NAME}@${HOST_NAME}:/opt/benchmarks/iperf3/${finalname}/${finalname1}/SERVER_STATS ../

cp *.csv ../
CLEAN_UP
COPY_RESULTS ${WEBSERVER} ${USER_NAME}
