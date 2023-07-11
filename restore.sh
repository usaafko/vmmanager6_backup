#!/bin/bash

. ./common.sh

RESTORE_VM=$1

pprint "Check if files $RESTORE_VM exists"

if [ -f "$BACKUP_LOCATION/$RESTORE_VM.zst" ] && [ -f "$BACKUP_LOCATION/$RESTORE_VM.json" ]; then
	pprint Ok
else
	perror "Can't find files to restore"
fi

metadata=$(cat $BACKUP_LOCATION/$RESTORE_VM.json)
vm_id=$(echo $metadata | jq -r '.metadata.id')

pprint "Check if VM exists"

vm_meta=$(get $token "vm/v3/host/$vm_id/metadata")
if echo $vm_meta | grep -qv error; then
	pprint "VM id $vm_id exists"
	pprint "Checking if backup exists in VMmanager"
	backup_id=${RESTORE_VM%%_*}
	backup_json=$(get $token "vm/v3/backup/$backup_id")
	if echo $backup_json | grep -qv error; then
		pprint "Found. Checking backup status"
		backup_status=$(echo $backup_json | jq -r '.state')
		backup_disk_id=$(echo $backup_json | jq -r '.parent_disk')
		if [ "x$backup_status" = "xactive" ]; then
			pprint "State OK"
			pprint "Restoring VM id $vm_id from backup id $backup_id"
			restore=$(post '{"backup":'$backup_id'}' "vm/v3/disk/$backup_disk_id/restore" $token)
			check_err "$restore"
			pprint "Done, VM will be restored. Please check VMmanager interface"
		else
			perror "Backup state: $backup_status"
		fi
	else
		perror "Can't find backup in VMmanager"
	fi
else
	pprint "VM not exists"
fi
