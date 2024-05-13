#!/bin/bash

BACKUP_PATH="/tmp/backupset/"

# check count of arguments
if [ $# -lt 2 ]; then
    echo -e "Using: executable [DOMAIN] [TYPE]\n\n[DOMAIN] can be obtained from \"virsh list --all\"\n[TYPE]: can be \"incr\" of \"full\""
    exit
fi

# check is doamin existing
check_vm=$(sudo virsh domstate $1)
if [[ $check_vm == "running" ]] || [[ $check_vm == "shut off" ]]; then
    echo "Domain \"$1\" exist"
    
    # do full or incremental backup
    if [[ $2 == full ]]; then
        b_type=full
        sudo rm -rf $BACKUP_PATH$1
        echo "Removing old full backup of \"$1\"" && echo "Creating full backup of \"$1\" domain"
    elif [[ $2 == incr ]]; then
        b_type=inc
        echo "Creating incremental backup of \"$1\""
    fi

    sudo docker run --rm \
    -v /var/lib/libvirt/images:/var/lib/libvirt/images \
    -v /run:/run \
    -v /var/tmp:/var/tmp \
    -v $BACKUP_PATH$1:$BACKUP_PATH$1 \
    ghcr.io/abbbi/virtnbdbackup:master \
    virtnbdbackup -d $1 -S -l $b_type -o $BACKUP_PATH$1

else
    echo "Domain \"$1\" does not exist"
fi