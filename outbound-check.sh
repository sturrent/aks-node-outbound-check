#!/bin/bash

# script name: outbound-check.sh
# Version v0.0.2 20231219
# Set of tools to deploy AKS troubleshooting labs

# "-a|--all" run all checks
# "-d|--dns" check DNS resolution
# "-k|--k8s-api" check Kubernetes API connectivity
# "-o|--outbound" check outbound connectivity to Internet
# "-r|--required-out" check connectivity to required FQDNs
# "-s|--src" get public source IP use in outbound
# "-h|--help" help info
# "--version" print version

# Variable definition

#SCRIPT_PATH="$( cd "$(dirname "$0")" ; pwd -P )"
#SCRIPT_NAME="$(echo $0 | sed 's|\.\/||g')"
SCRIPT_VERSION="Version v0.0.2 20231219"
NODE_DNS_SRV="$(grep ^nameserver /etc/resolv.conf | cut -d " " -f 2)"
API_SERVER_FQDN="$(grep "server:" /var/lib/kubelet/kubeconfig | awk '{print $2}' | cut -d ':' -f 2 | tr -d '/')"
AZURE_DNS_SERVER="168.63.129.16"
FQDN_DNS_CHECK="mcr.microsoft.com"
OUTBOUND_DST="mcr.microsoft.com/v2/"
SHORT_RUN='0'


# set an initial value for the flags
ALL=0
HELP=0
DNS_CHECK=0
OUT_CHECK=0
REQUIRED_CHECK=0
SRC_CHECK=0
VERSION=0

# read the options
TEMP=$(getopt -o d:o:akrsh --long dns,outbound,all,k8s-api,required,src,help,version -n 'outbound-check.sh' -- "$@")
eval set -- "$TEMP"

while true;
do
    case "$1" in
        -a|--all) ALL=1; shift;;
        -h|--help) HELP=1; shift;;
        -d|--dns) DNS_CHECK=1; case "$2" in
            -*) shift;;
            "") shift 2;;
            *) FQDN_DNS_CHECK="$2"; shift 2;;
            esac;;
        -o|--outbound) OUT_CHECK=1; case "$2" in
            -*) shift;;
            "") shift 2;;
            *) OUTBOUND_DST="$2"; shift 2;;
            esac;;
        -r|--required-out) REQUIRED_CHECK=1; shift;;
        -s|--src) SRC_CHECK=1; shift;;
        --version) VERSION=1; shift;;
        --) shift ; break ;;
        *) echo -e "Error: invalid argument\n" ; exit 3 ;;
    esac
done

## Funtion definition

# DNS check
function check_dns () {
    FQDN_DNS_CHECK="$1"
    echo -e ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>_DNS_>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n"
    echo -e "DNS check for FQDN ${FQDN_DNS_CHECK}\n"
    nslookup "$FQDN_DNS_CHECK"

    if [[ "$NODE_DNS_SRV" != "$AZURE_DNS_SERVER" ]]
    then
        echo -e "\nDNS check using Azure internal DNS:\n"
        nslookup "$FQDN_DNS_CHECK" "$AZURE_DNS_SERVER"
    fi
    echo -e "\n<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<_DNS_<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n"
}

# Outbound check
function check_outbound_dst () {
    OUTBOUND_DST="$1"
    SHORT_RUN="$2"
    echo -e ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>_Outbound_>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n"
    if [ "$SHORT_RUN" -eq "1" ]
    then 
        echo -e "Outbound check using dst = mcr.microsoft.com/v2/\n"
        curl -m 7 --insecure --proxy-insecure --silent -I https://mcr.microsoft.com/v2/
    else
        echo -e "Outbound check using dst = ${OUTBOUND_DST}\n"    
        curl -v -m 7 --insecure --proxy-insecure --silent "${OUTBOUND_DST}" 2>&1
    fi
    echo -e "\n<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<_Outbound_<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n"
}

# Required FQDN outbound
function check_outbound_required_fqdn () {
    echo -e ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>_Required_Outbound_>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n"
    echo -e "Outbound check for required FQDNs\n" 
    echo URL = http_status
    echo mcr.microsoft.com = "$(curl -m 7 --insecure --proxy-insecure -s -o /dev/null -I -w "%{http_code}" https://mcr.microsoft.com/v2/)"
    echo "$API_SERVER_FQDN" = "$(curl -m 7 --insecure --proxy-insecure -s -o /dev/null -I -w "%{http_code}" https://"${API_SERVER_FQDN}")"
    echo management.azure.com = "$(curl -m 7 --insecure --proxy-insecure -s -o /dev/null -I -w "%{http_code}" https://management.azure.com:443)"
    echo login.microsoftonline.com = "$(curl -m 7 --insecure --proxy-insecure -s -o /dev/null -I -w "%{http_code}" https://login.microsoftonline.com:443)"
    echo packages.microsoft.com = "$(curl -m 7 --insecure --proxy-insecure -s -o /dev/null -I -w "%{http_code}" https://packages.microsoft.com:443)"
    echo acs-mirror.azureedge.net = "$(curl -m 7 --insecure --proxy-insecure -s -o /dev/null -I -w "%{http_code}" https://acs-mirror.azureedge.net:443)"
    echo -e "\n<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<_Required_Outbound_<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n"
}

# Outbound public IP source check
function check_outbound_src () {
    echo -e ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>_Outbound_src_IP_>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n"
    echo -e "Outbound source IP check\n"
    OUTBOUD_IP=$(curl -m 7 --insecure --proxy-insecure --silent ifconfig.io)
    #OUTBOUD_IP=$(dig +short myip.opendns.com @resolver1.opendns.com -4)
    echo "Public Outbound IP = ${OUTBOUD_IP}"
    echo -e "\n<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<_Outbound_src_IP_<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n"
}

# Run all checks
function check_all () {
    SHORT_RUN='1'
    echo -e "Running all checks...\n"
    check_dns "$FQDN_DNS_CHECK"
    check_dns "$API_SERVER_FQDN"
    check_outbound_dst "$OUTBOUND_DST" "$SHORT_RUN"
    check_outbound_src
    check_outbound_required_fqdn
}

# Usage description
function print_usage_text () {
    NAME_EXEC="outbound-check"
    echo -e "$NAME_EXEC usage: $NAME_EXEC [-a|--all] [-d|--dns <FQDN>] [-o|--outbound <FQDN|IP>] [-r|--required-out] [-s|--src] [-h|--help] [--version]\n"
echo -e '"-a|--all" run all checks
"-d|--dns" check DNS resolution
"-k|--k8s-api" check Kubernetes API connectivity
"-o|--outbound" check outbound connectivity to Internet
"-r|--required-out" check connectivity to required FQDNs
"-s|--src" get public source IP use in outbound
"-h|--help" help info
"--version" print version\n'
}

## Flag validation

#if -h | --help option is selected usage will be displayed
if [ $HELP -eq 1 ]
then
	print_usage_text
	exit 0
fi

if [ $VERSION -eq 1 ]
then
	echo -e "$SCRIPT_VERSION\n"
	exit 0
fi


# main

if [ $ALL -eq 1 ]
then
    check_all
else
    if [ $DNS_CHECK -eq 1 ]
    then
        check_dns "$FQDN_DNS_CHECK"
    fi

    if [ $OUT_CHECK -eq 1 ]
    then
        check_outbound_dst "$OUTBOUND_DST" "$SHORT_RUN"
    fi

    if [ $SRC_CHECK -eq 1 ]
    then
        check_outbound_src
    fi

    if [ $REQUIRED_CHECK -eq 1 ]
    then
        check_outbound_required_fqdn
    fi
fi

exit 0