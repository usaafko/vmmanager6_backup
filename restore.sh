#!/bin/bash

. ./common.sh

RESTORE_VM=$1

ask_existing() {
	read -p "Do you want to restore from local backup (y/n)?" choice
	case "$choice" in
		y|Y )	restore_existing;; 
		n|N )   pprint "Done"
			exit
			;;
		* ) echo "invalid";;
	esac
}
restore_existing() {
	pprint "Getting master configuration"
	VM_CONFIG=$(ssh  root@$VM_IP cat /opt/ispsystem/vm/config.json)
	mysql_pass=$(echo $VM_CONFIG | jq -r '.MysqlRootPassword')
	backup_id=$(cat $BACKUP_LOCATION/${RESTORE_VM}_backup.json | jq -r '.id') 
	backup_name=$(cat $BACKUP_LOCATION/${RESTORE_VM}_backup.json | jq -r '.name') 
	backup_os=$(cat $BACKUP_LOCATION/${RESTORE_VM}_backup.json | jq -r '.os') 
	backup_expand=$(cat $BACKUP_LOCATION/${RESTORE_VM}_backup.json | jq -r '.expand_part') 
	backup_ipauto=$(cat $BACKUP_LOCATION/${RESTORE_VM}_backup.json | jq -r '.ip_automation') 
	backup_parent=$(cat $BACKUP_LOCATION/${RESTORE_VM}_backup.json | jq -r '.parent_disk') 
	backup_estimated=$(cat $BACKUP_LOCATION/${RESTORE_VM}_backup.json | jq -r '.estimated_size_mib') 
	backup_actualsize=$(cat $BACKUP_LOCATION/${RESTORE_VM}_backup.json | jq -r '.actual_size_mib') 
	backup_node=$(cat $BACKUP_LOCATION/${RESTORE_VM}_backup.json | jq -r '.node') 
	backup_internalname=$(cat $BACKUP_LOCATION/${RESTORE_VM}_backup.json | jq -r '.internal_name') 
	backup_state=$(cat $BACKUP_LOCATION/${RESTORE_VM}_backup.json | jq -r '.state') 
	backup_datecreate=$(cat $BACKUP_LOCATION/${RESTORE_VM}_backup.json | jq -r '.date_create') 
	pprint "Adding backup to VMmanager database..."
	ssh root@$VM_IP << DOCKER_EOF
docker exec -i mysql bash << EOF
mysql isp -p$mysql_pass -e "replace into vm_disk_backup(id,name,os,expand_part,ip_automation,parent_disk,estimated_size_mib,actual_size_mib,node,backup_location,schedule,internal_name,state,comment,date_create,available_until) value ($backup_id,'$backup_name',$backup_os,'$backup_expand','$backup_ipauto',$backup_parent,$backup_estimated,$backup_actualsize,$backup_node,null,null,'$backup_internalname','$backup_state','','$backup_datecreate',null)"
EOF
DOCKER_EOF
	pprint "Move local backup to VMmanager storage"
	backup_type=$(cat "$BACKUP_LOCATION/${RESTORE_VM}_config.json" | jq -r '.type')
        backup_path=$(cat "$BACKUP_LOCATION/${RESTORE_VM}_config.json" | jq -r '.list[-1]|.cluster.image_storage_path')	
	cp $BACKUP_LOCATION/${RESTORE_VM}.zst /$backup_path/${RESTORE_VM}_backup.${backup_type}.zst
	pprint "Done. Please run restore.sh again"
}
pprint "Check if files $RESTORE_VM exists"

if [ -f "$BACKUP_LOCATION/$RESTORE_VM.zst" ] && [ -f "$BACKUP_LOCATION/${RESTORE_VM}_vm.json" ] && [ -f "$BACKUP_LOCATION/${RESTORE_VM}_backup.json" ] && [ -f "$BACKUP_LOCATION/${RESTORE_VM}_config.json" ] ; then
	pprint Ok
else
	perror "Can't find files to restore"
fi

metadata=$(cat $BACKUP_LOCATION/${RESTORE_VM}_vm.json)
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
			ask_existing
			#TODO: ask user and restore from local file
		fi
	else
		perror "Can't find backup in VMmanager"
		ask_existing
		#TODO: ask user and restore from local file
	fi
else
	pprint "VM not exists"
	#TODO: restore from local files
fi
