#!/bin/bash


VM_URL='https://172.31.49.33'
VM_LOGIN='admin@example.com'
VM_PASS='q1w2e3'
BACKUP_LOCATION='/backup'
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
	if echo $1 | grep -q error; then
		perror "Request failed with error: $1"
		exit 1
	fi
}
pprint "Get auth token"

token_json=$(post '{"email": "'$VM_LOGIN'", "password": "'$VM_PASS'"}' 'auth/v4/public/token')

while echo $token_json | grep -q error 
do
	perror "Can't login, do another try"
	sleep 5
	token_json=$(post '{"email": "'$VM_LOGIN'", "password": "'$VM_PASS'"}' 'auth/v4/public/token')
done 
	
token=$(echo $token_json | jq -r '.token')
