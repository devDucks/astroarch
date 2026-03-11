#!/usr/bin/env bash
set -euo pipefail

echo "Available block devices:"
lsblk -d -o NAME,SIZE,MODEL | grep -v loop

echo ""
read -rp "Enter the target USB device (e.g. /dev/sdb): " TARGET_DEV

if [[ ! -b "$TARGET_DEV" ]]; then
    echo "ERROR: '$TARGET_DEV' is not a valid block device. Aborting."
    exit 1
fi

echo ""
echo "WARNING: ALL DATA ON $TARGET_DEV WILL BE DESTROYED."
echo "Device info:"
lsblk "$TARGET_DEV"
echo ""
read -rp "Type 'yes' to confirm you want to partition $TARGET_DEV: " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk "$TARGET_DEV"
  o # clear the in memory partition table
  n # new partition
  p # primary partition
  1 # partition number 1
    # default - start at beginning of disk
  +256M # 256 MB boot parttion
  t # prompt to change partition type
  0c # Make the partition a W95 FAT32
  n # new partition
  p # primary partition
  2 # partion number 2
    # default, start immediately after preceding partition
    # default, extend partition to end of disk
  p # print the in-memory partition table
  w # write the partition table
  q # and we're done
EOF
