#!/bin/bash


VM_URL='https://172.31.49.33'
VM_LOGIN='admin@example.com'
VM_PASS='q1w2e3'
BACKUP_VM=$1
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

pprint "Get vm metadata"
metadata=$(get $token "vm/v3/host/$BACKUP_VM/metadata")
check_err "$metadata"

pprint "Backup vm"
stamp=$(date +%s)
post '{"name": "backup by script '$stamp'", "comment":"", "backup_locations": null}' "vm/v3/host/$BACKUP_VM/backup" $token > /dev/null

while true
do
	backup_json=$(get $token "vm/v3/host/$BACKUP_VM/backup")
	check_err "$backup_json"
	state=$(echo $backup_json | jq -r '.list[-1] | .state')
	if [ "x$state" = "xactive" ]; then
		break
	fi
	pprint "Waiting..."
	sleep 5
done

backup_id=$(echo $backup_json | jq -r '.list[-1] | .id')
backup_disk_id=$(echo $backup_json | jq -r '.list[-1] | .disk.id')
backup_disk_name=$(echo $backup_json | jq -r '.list[-1] | .disk.name')
backup_path=$(echo $backup_json | jq -r '.list[-1] | .cluster.image_storage_path')

backup_name="${backup_id}_${backup_disk_id}_${backup_disk_name}"
backup_file="${backup_path}/${backup_name}_backup"
backup_type='qcow2'
if [ -f "${backup_file}.qcow2.zst" ]; then
	backup_type='qcow2'
else
	backup_type='raw'
fi


pprint "Copy $backup_name file to backup location"
cp -f ${backup_file}.${backup_type}.zst $BACKUP_LOCATION/${backup_name}.zst
echo ${metadata} > ${BACKUP_LOCATION}/${backup_name}.json

pprint "Done"
