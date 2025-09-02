###
### Common variables for backup\restore script
### AO Exo-soft 2023 
### Author: Kalinichenko Ilya 
### mailto: i.kalinichenko@ispsystem.com
###

# VMmanager 6 URL
VM_URL='https://172.31.51.138'

# VMmanager 6 user with administrator rights 
# Script will use it to create backup, restore backup, create new VM
VM_ADMIN_LOGIN='admin@example.com'
VM_ADMIN_PASS='q1w2e3r4'

# VMmanager 6 advanced user  
# Script will use it to restore backup, create new VM
VM_ADV_LOGIN='adv@example.com'
VM_ADV_PASS='q1w2e3r4'

# VMmanager 6 master server IP. Please configure SSH access from this node to master by ssh keys
VM_IP='172.31.51.138'
VM_SSH_LOGIN='root'

# Directory, where script will store backups
# In this directory restore.sh will search files to restore 
BACKUP_LOCATION='/backup'
