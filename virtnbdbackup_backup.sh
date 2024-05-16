#!/bin/bash
# Original project https://github.com/abbbi/virtnbdbackup?tab=readme-ov-file#transient-virtual-machines-checkpoint-persistency

BACKUP_PATH="/tmp/backupset/"

# check count of arguments
if [ $# -lt 2 ]; then
    echo -e "Using: executable [DOMAIN] [TYPE]\n\n[DOMAIN] can be obtained from \"virsh list --all\"\n[TYPE]: can be \"incr\" of \"full\""
    exit
fi

# check is domain existing
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
    # delete old container and run new one
    sudo docker rm -f virtnbdbackup > /dev/null && \
    sudo docker run \
    --name virtnbdbackup \
    -v /var/lib/libvirt/images:/var/lib/libvirt/images \
    -v /run:/run \
    -v /var/tmp:/var/tmp \
    -v $BACKUP_PATH$1:$BACKUP_PATH$1 \
    ghcr.io/abbbi/virtnbdbackup:master \
    virtnbdbackup -d $1 -z -S -l $b_type -o $BACKUP_PATH$1 #| virsh shutdown $1 # power off debug

    exit_code=$(sudo docker inspect virtnbdbackup --format='{{.State.ExitCode}}')

    if [[ $exit_code == 0 ]]; then
        echo "Backup of \"$1\" was successfull (code = \"$exit_code\")"
    else
        echo "Error during backup (code = \"$exit_code\")"
        echo "Backup type changed to \"full\""
        # Stop VM
        sudo virsh destroy $1
        echo "Domain \"$1\" was forcibly turned off to allow the backup to start correctly"
        # Delete old backups
        echo "Deleting old backups..."
        sudo rm -rf $BACKUP_PATH$1
        # Relaunch full backup
        echo "Trying to relaunch backup..."
        sudo docker rm -f virtnbdbackup > /dev/null && \
        sudo docker run \
        --name virtnbdbackup \
        -v /var/lib/libvirt/images:/var/lib/libvirt/images \
        -v /run:/run \
        -v /var/tmp:/var/tmp \
        -v $BACKUP_PATH$1:$BACKUP_PATH$1 \
        ghcr.io/abbbi/virtnbdbackup:master \
        virtnbdbackup -d $1 -z -S -l full -o $BACKUP_PATH$1
        # Start VM
        echo "Starting \"$1\" to normal state"
        sudo virsh start $1
    fi
else
    echo "Domain \"$1\" does not exist"
fi