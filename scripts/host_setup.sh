#!/bin/bash -e

function addFstabEntry() {
    local mountTarget=$1
    local dataDir=$2
    local fileSystem=$3
    local params=$4

    # Copy fstab without empty last line
    sed '/^$/d' /etc/fstab > /etc/fstab.1

    # Add mounting of the new device
    echo "$mountTarget $dataDir $fileSystem $params 0 0" >> /etc/fstab.1
    echo '' >> /etc/fstab.1
    mv /etc/fstab.1 /etc/fstab
}

function mount_lvm() {
    local LVM_DEV=$1
    local DATA_DIR=$2
    echo "Old /etc/fstab contents:"
    cat /etc/fstab
    echo ''

    # Add mounting of the new LVM device
    addFstabEntry $LVM_DEV $DATA_DIR "ext4" "defaults,noatime"

    mount -o noatime $LVM_DEV $DATA_DIR
}

function create_lvm() {
    local DATA_DEV=$1
    local DATA_DIR=$2
    local NAME_SUFFIX=$3

    local VOLUME_GROUP="vg$NAME_SUFFIX"
    local LOGICAL_VOLUME="lv$NAME_SUFFIX"
    local LVM_DEV=/dev/$VOLUME_GROUP/$LOGICAL_VOLUME

    echo "Creating LVM volume $LVM_DEV"

    # Check parameters
    if [ -z "$DATA_DIR" ]; then
        echo "Missing data directory path in parameter. Exiting."
        exit 1
    fi

    if [ -z "$DATA_DEV" ]; then
        echo "Missing device path in parameter. Exiting."
        exit 1
    fi

    # Everything is done already
    if [ -d "$DATA_DIR" ]; then
        echo Creating data store.. $DATA_DIR is already mounted, nothing to do.
        exit 0
    fi

    # Create LVM volume
    pvcreate $DATA_DEV -y
    vgcreate $VOLUME_GROUP $DATA_DEV
    lvcreate -l 100%FREE -n $LOGICAL_VOLUME $VOLUME_GROUP

    mkfs.ext4 $LVM_DEV

    # Mount data store partition on location from parameter
    mkdir -p $DATA_DIR

    mount_lvm $LVM_DEV $DATA_DIR
}

echo "preparing LVM volumes"
create_lvm "/dev/xvdb" "/opt/dynatrace-managed" "bin"
create_lvm "/dev/xvdc" "/var/opt/dynatrace-managed" "misc"
create_lvm "/dev/xvdd" "/var/opt/dynatrace-managed/server" "srv"
create_lvm "/dev/xvde" "/var/opt/dynatrace-managed/cassandra" "cas"
create_lvm "/dev/xvdf" "/var/opt/dynatrace-managed/elasticsearch" "elastic"