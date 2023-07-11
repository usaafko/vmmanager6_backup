#!/bin/bash

. ./common.sh

BACKUP_VM=$1

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
echo ${metadata} > ${BACKUP_LOCATION}/${backup_name}_vm.json

pprint "Saving backup metadata"
backup_json=$(get $token "vm/v3/backup/$backup_id")
check_err "$backup_json"
echo $backup_json > ${BACKUP_LOCATION}/${backup_name}_backup.json


pprint "Done"
