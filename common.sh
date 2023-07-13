#!/bin/bash
###
### Common functions for backup\restore script
### AO Exo-soft 2023 
### Author: Kalinichenko Ilya 
### mailto: i.kalinichenko@ispsystem.com
###

. ./vars.sh
post() {
	data="$1"
	if [ -n "$3" ]; then
		token="$3"
		curl -ks -H "x-xsrf-token: $token" -H "ses6: $token" -H  "accept: application/json" -H  "Content-Type: application/json" -X POST  -d "$data" $VM_URL/$2
	else
		curl -ks -H  "accept: application/json" -H  "Content-Type: application/json" -X POST  -d "$data" $VM_URL/$2
	fi
} 
get() {
	TOKEN=$1
	URL=$2
	curl -ks -H  "accept: application/json" -H  "Content-Type: application/json" -H "x-xsrf-token: $TOKEN" -H "ses6: $TOKEN" $VM_URL/$URL
}
NC='\033[0m' # No Color

pprint() {
        GREEN='\033[0;32m'
        echo -e "===> $(date) ${GREEN}${1}${NC}"
}
perror() {
        RED='\033[0;31m'
        echo -e "===> $(date) ${RED}${1}${NC}"
}
check_err() {
	if echo $1 | grep -q '"error"'; then
		perror "Request failed with error: $1"
		exit 1
	fi
}
usage() {
	cat << EOF 
Usage:
	Please fill variables in env.sh
	To restore backups when VM or backup is deleted configure SSH access from node to VMmanager master

	restore.sh [backup name] Start restoring of backup
	backup.sh [vm id] Start backuping VM with VMmanager id

EOF
}
if [ -z "$1" ]; then
	usage
	exit
fi	

pprint "Get auth token"

token_json=$(post '{"email": "'$VM_LOGIN'", "password": "'$VM_PASS'"}' 'auth/v4/public/token')
first_login=1
while echo $token_json | grep -q error 
do
	if [ "$first_login" -gt 1 ]; then
		perror "Can't login, do another try"
	fi
	sleep 5
	token_json=$(post '{"email": "'$VM_LOGIN'", "password": "'$VM_PASS'"}' 'auth/v4/public/token')
	first_login=2
done 
	
token=$(echo $token_json | jq -r '.token')

