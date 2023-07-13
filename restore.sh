#!/bin/bash
###
### Restore script for VMmanager 6
### AO Exo-soft 2023 
### Author: Kalinichenko Ilya 
### mailto: i.kalinichenko@ispsystem.com
###

. ./common.sh

RESTORE_VM=$1
ask_missed() {
	read -p "Do you want to create VM and restore from local backup (y/n)?" choice
	case "$choice" in
		y|Y )	restore_missed;; 
		n|N )   pprint "Done"
			exit
			;;
		* ) echo "invalid";;
	esac
}
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
	if [ -z "$mysql_pass" ]; then
		pprint "Getting master configuration"
		VM_CONFIG=$(ssh -t root@$VM_IP cat /opt/ispsystem/vm/config.json)
		mysql_pass=$(echo $VM_CONFIG | jq -r '.MysqlRootPassword')
	fi
	backup_id=$(cat $BACKUP_LOCATION/${RESTORE_VM}/backup.json | jq -r '.id') 
	backup_name=$(cat $BACKUP_LOCATION/${RESTORE_VM}/backup.json | jq -r '.name') 
	backup_os=$(cat $BACKUP_LOCATION/${RESTORE_VM}/backup.json | jq -r '.os') 
	backup_expand=$(cat $BACKUP_LOCATION/${RESTORE_VM}/backup.json | jq -r '.expand_part') 
	backup_ipauto=$(cat $BACKUP_LOCATION/${RESTORE_VM}/backup.json | jq -r '.ip_automation') 
	backup_parent=$(cat $BACKUP_LOCATION/${RESTORE_VM}/backup.json | jq -r '.parent_disk') 
	backup_disk_id=$backup_parent
	backup_estimated=$(cat $BACKUP_LOCATION/${RESTORE_VM}/backup.json | jq -r '.estimated_size_mib') 
	backup_actualsize=$(cat $BACKUP_LOCATION/${RESTORE_VM}/backup.json | jq -r '.actual_size_mib') 
	backup_node=$(cat $BACKUP_LOCATION/${RESTORE_VM}/backup.json | jq -r '.node') 
	backup_internalname=$(cat $BACKUP_LOCATION/${RESTORE_VM}/backup.json | jq -r '.internal_name') 
	backup_state=$(cat $BACKUP_LOCATION/${RESTORE_VM}/backup.json | jq -r '.state') 
	backup_datecreate=$(cat $BACKUP_LOCATION/${RESTORE_VM}/backup.json | jq -r '.date_create') 
	pprint "Adding backup to VMmanager database..."
	ssh root@$VM_IP /bin/bash << DOCKER_EOF
docker exec -i mysql bash << EOF
MYSQL_PWD=$mysql_pass mysql isp -e "replace into vm_disk_backup(id,name,os,expand_part,ip_automation,parent_disk,estimated_size_mib,actual_size_mib,node,backup_location,schedule,internal_name,state,comment,date_create,available_until) value ($backup_id,'$backup_name',$backup_os,'$backup_expand','$backup_ipauto',$backup_parent,$backup_estimated,$backup_actualsize,$backup_node,null,null,'$backup_internalname','$backup_state','','$backup_datecreate',null)"
EOF
DOCKER_EOF
	pprint "Move local backup to VMmanager storage"
	backup_type=$(cat "$BACKUP_LOCATION/${RESTORE_VM}/backup_host.json" | jq -r '.type')
        backup_path=$(cat "$BACKUP_LOCATION/${RESTORE_VM}/backup_host.json" | jq -r '.list[-1]|.cluster.image_storage_path')	
	cp $BACKUP_LOCATION/${RESTORE_VM}/disk.zst $backup_path/${RESTORE_VM}_backup.${backup_type}.zst
	restore_vm_backup
}
restore_missed() {
	pprint "Getting master configuration"
	VM_CONFIG=$(ssh -t root@$VM_IP cat /opt/ispsystem/vm/config.json)
	mysql_pass=$(echo $VM_CONFIG | jq -r '.MysqlRootPassword')
	vm_ip=$(cat $BACKUP_LOCATION/${RESTORE_VM}/vm.json | jq -r '.metadata.ipv4[0].ip_addr')
	vm_ip_pool=$(cat $BACKUP_LOCATION/${RESTORE_VM}/vm.json | jq -r '.metadata.ipv4[0].ippool_id')
	pprint "Check if IP address $vm_ip is busy"
	check_ip=$(get $token "ip/v3/ip?where=name%20EQ%20%27${vm_ip}%27")
	check_err "$check_ip"
	if [ $(echo $check_ip | jq -r '.list | length') -ne 0 ]; then
		perror "Ip $vm_ip address is currently occupied or in use."
		read -p "Do you want to use new ip address (y/n)?" choice
		case "$choice" in
			y|Y )	new_ip=1;; 
			n|N )   pprint "Done"
				exit
				;;
			* ) echo "invalid";;
		esac
	fi
	pprint "Address is ready to use"
	vm_name=$(cat $BACKUP_LOCATION/${RESTORE_VM}/vm.json | jq -r '.metadata.name')
	vm_os=$(cat $BACKUP_LOCATION/${RESTORE_VM}/vm.json | jq -r '.metadata.os.id')
	vm_pass=$(pwgen -s 20 -1)
	vm_cluster=$(cat $BACKUP_LOCATION/${RESTORE_VM}/vm.json | jq -r '.metadata.cluster.id')
	vm_preset=$(cat $BACKUP_LOCATION/${RESTORE_VM}/vm.json | jq -r '.metadata.preset')
	vm_node=$(cat $BACKUP_LOCATION/${RESTORE_VM}/vm.json | jq -r '.metadata.node.id')
	vm_disk=$(cat $BACKUP_LOCATION/${RESTORE_VM}/vm.json | jq -r '.metadata.disks[0].size_mib')
	vm_disk_storage=$(cat $BACKUP_LOCATION/${RESTORE_VM}/vm.json | jq -r '.metadata.disks[0].storage.id')
	vm_user=$(cat $BACKUP_LOCATION/${RESTORE_VM}/vm.json | jq -r '.metadata.account.id')
	vm_domain=$(cat $BACKUP_LOCATION/${RESTORE_VM}/vm.json | jq -r '.metadata.domain')
	new_vm_json=$(mktemp /tmp/newvmXXXXX)
	cat << EOF > $new_vm_json
{
                "name": "$vm_name",
                "os": $vm_os,
                "password": "$vm_pass",
                "send_email_mode": "default",
                "cluster": $vm_cluster,
		"node": $vm_node,
                "preset": $vm_preset,
                "disks":
                [
                    {
                        "size_mib": $vm_disk,
                        "boot_order": 1,
			"storage": $vm_disk_storage,
                        "tags":
                        []
                    }
                ],
                "account": $vm_user,
                "custom_interfaces":
                [
                    {
                        "mac": null,
			"bridge": null,
			"ip_name": "$vm_ip",
                        "ip_count": 1
                    }
                ],
                "domain": "$vm_domain"
            }
EOF
	if [ -n "$new_ip" ]; then
		cat $new_vm_json | jq ".custom_interfaces[0].ippool = $vm_ip_pool | del(.custom_interfaces[0].ip_name) | del(.custom_interfaces[0].bridge)" > $new_vm_json.new
		mv $new_vm_json.new $new_vm_json
	fi
	pprint "Creating new VM..."
	newvm=$(post "@${new_vm_json}" 'vm/v3/host' $token)
	check_err "$newvm"
	rm -f $new_vm_json
	vm_id=$(echo $newvm | jq -r '.id')
	while true
	do
		vm_json=$(get $token "vm/v3/host/$vm_id")
		check_err "$vm_json"
		if [ "x$(echo $vm_json | jq -r '.state')" = "xactive" ]; then
			break
		fi
		pprint "Waiting..."
		sleep 5
	done
	new_metadata=$(get $token "vm/v3/host/$vm_id/metadata")
	check_err "$new_metadata"
	echo $new_metadata > $BACKUP_LOCATION/${RESTORE_VM}/vm.json
	new_vm_disk=$(echo $new_metadata | jq -r '.metadata.disks[0].id')
	pprint "New vm disk id $new_vm_disk"
	new_backup_json=$(cat $BACKUP_LOCATION/${RESTORE_VM}/backup.json | jq ".parent_disk = $new_vm_disk")
       echo "$new_backup_json" > $BACKUP_LOCATION/${RESTORE_VM}/backup.json
       restore_existing	
}
restore_vm_backup() {
	pprint "Restoring VM id $vm_id from backup id $backup_id"
	restore=$(post '{"backup":'$backup_id'}' "vm/v3/disk/$backup_disk_id/restore" $token)
	check_err "$restore"
	pprint "Done, VM will be restored. Please check VMmanager interface"
}

### Start restoring
pprint "Check if files $RESTORE_VM exists"

if [ -f "$BACKUP_LOCATION/$RESTORE_VM/disk.zst" ] && [ -f "$BACKUP_LOCATION/${RESTORE_VM}/vm.json" ] && [ -f "$BACKUP_LOCATION/${RESTORE_VM}/backup.json" ] && [ -f "$BACKUP_LOCATION/${RESTORE_VM}/backup_host.json" ] ; then
	pprint Ok
else
	perror "Can't find files to restore"
	exit 1
fi

metadata=$(cat $BACKUP_LOCATION/${RESTORE_VM}/vm.json)
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
			restore_vm_backup
		else
			perror "Backup state: $backup_status"
			ask_existing
		fi
	else
		perror "Can't find backup in VMmanager"
		ask_existing
	fi
else
	perror "VM not exists"
	ask_missed
fi
