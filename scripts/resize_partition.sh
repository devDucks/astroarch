#!/bin/bash

# WARNING: This script doesn't work with encrypted/lvm/luks partitions

set -e

partition=$( mount | grep -E  "on / type [a-z]+" | awk '{print $1}')

if [ $(echo $partition | grep -c sda) -eq 1 ]; then
    ROOT_DISK=$(echo | sed 's/[0-9]//g')
    ROOT_PARTITION=$(echo $partition | grep -Eo [0-9]+)
    MEDIA=usb
elif [ $(echo $partition | grep -cE "(mmcblk|nvme)") -eq 1 ]; then
    ROOT_DISK=$(echo $partition | cut -d "p" -f1)
    ROOT_PARTITION=$(echo $partition | cut -d "p" -f2)
    MEDIA=other
fi

if [ -z $ROOT_DISK ] || [ -z $ROOT_PARTITION ] || [ -z $MEDIA ]; then
    exit 2
fi

# Run now growpart on the root disk to grow the partition
growpart -N ${ROOT_DISK} ${ROOT_PARTITION} && growpart ${ROOT_DISK} ${ROOT_PARTITION} || exit 0

# Resize the root partition to full available space
if [ $MEDIA == "other"]; then
    resize2fs ${ROOT_DISK}p${ROOT_PARTITION} || exit 0
elif [ $MEDIA = "usb" ]; then
    resize2fs ${ROOT_DISK}${ROOT_PARTITION} || exit 0
else
    echo "unknown media $MEDIA, erroring" && exit 3
fi
