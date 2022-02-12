#!/bin/sh

reboot_pi () {
  echo "Unmounting /boot before rebooting"	
  umount /boot
  echo "Remounting / in RO mode"
  mount / -o remount
  sync
  echo "Starting reboot"
  reboot -f
  sleep 5
  exit 0
}

check_commands () {
  if ! command -v whiptail > /dev/null; then
      echo "whiptail not found"
      sleep 5
      return 1
  fi
  for COMMAND in grep cut sed parted fdisk findmnt; do
    if ! command -v $COMMAND > /dev/null; then
      FAIL_REASON="$COMMAND not found"
      echo $FAIL_REASON
      return 1
    fi
  done
  return 0
}

get_variables () {
  ROOT_PART_DEV=$(findmnt / -o source -n)
  ROOT_PART_NAME=$(echo "$ROOT_PART_DEV" | cut -d "/" -f 3)
  ROOT_DEV_NAME=$(echo /sys/block/*/"${ROOT_PART_NAME}" | cut -d "/" -f 4)
  ROOT_DEV="/dev/${ROOT_DEV_NAME}"
  ROOT_PART_NUM=$(cat "/sys/block/${ROOT_DEV_NAME}/${ROOT_PART_NAME}/partition")

  BOOT_PART_DEV=$(findmnt /boot -o source -n)
  BOOT_PART_NAME=$(echo "$BOOT_PART_DEV" | cut -d "/" -f 3)
  BOOT_DEV_NAME=$(echo /sys/block/*/"${BOOT_PART_NAME}" | cut -d "/" -f 4)
  BOOT_PART_NUM=$(cat "/sys/block/${BOOT_DEV_NAME}/${BOOT_PART_NAME}/partition")

  OLD_DISKID=$(fdisk -l "$ROOT_DEV" | sed -n 's/Disk identifier: 0x\([^ ]*\)/\1/p')

  ROOT_DEV_SIZE=$(cat "/sys/block/${ROOT_DEV_NAME}/size")
  TARGET_END=$((ROOT_DEV_SIZE - 1))

  PARTITION_TABLE=$(parted -m "$ROOT_DEV" unit s print | tr -d 's')

  LAST_PART_NUM=$(echo "$PARTITION_TABLE" | tail -n 1 | cut -d ":" -f 1)

  ROOT_PART_LINE=$(echo "$PARTITION_TABLE" | grep -e "^${ROOT_PART_NUM}:")
  ROOT_PART_START=$(echo "$ROOT_PART_LINE" | cut -d ":" -f 2)
  ROOT_PART_END=$(echo "$ROOT_PART_LINE" | cut -d ":" -f 3)
}

fix_partuuid() {
  mount -o remount,rw "$ROOT_PART_DEV"
  mount -o remount,rw "$BOOT_PART_DEV"
  DISKID="$(tr -dc 'a-f0-9' < /dev/hwrng | dd bs=1 count=8 2>/dev/null)"
  fdisk "$ROOT_DEV" > /dev/null <<EOF
x
i
0x$DISKID
r
w
EOF

  mount -o remount,ro "$ROOT_PART_DEV"
  mount -o remount,ro "$BOOT_PART_DEV"
}

check_variables () {
  if [ "$BOOT_DEV_NAME" != "$ROOT_DEV_NAME" ]; then
      FAIL_REASON="Boot and root partitions are on different devices"
      echo $FAIL_REASON
      return 1
  fi

  if [ "$ROOT_PART_NUM" -ne "$LAST_PART_NUM" ]; then
    FAIL_REASON="Root partition should be last partition"
    echo $FAIL_REASON
    return 1
  fi

  if [ "$ROOT_PART_END" -gt "$TARGET_END" ]; then
    FAIL_REASON="Root partition runs past the end of device"
    echo $FAIL_REASON
    return 1
  fi

  if [ ! -b "$ROOT_DEV" ] || [ ! -b "$ROOT_PART_DEV" ] || [ ! -b "$BOOT_PART_DEV" ] ; then
    FAIL_REASON="Could not determine partitions"
    echo $FAIL_REASON
    return 1
  fi
}

check_kernel () {
  MAJOR="$(uname -r | cut -f1 -d.)"
  MINOR="$(uname -r | cut -f2 -d.)"
  if [ "$MAJOR" -eq "4" ] && [ "$MINOR" -lt "9" ]; then
    echo "Old kernel!"
    return 0
  fi
  if [ "$MAJOR" -lt "4" ]; then
    echo "Very old kernel"
    return 0
  fi
  NEW_KERNEL=1
}

main () {
  echo "Setting env vars"
  get_variables
  echo "Vars set up"
  if ! check_variables; then
    return 1
  fi

  check_kernel
  echo "checked kernel"

  if [ "$ROOT_PART_END" -eq "$TARGET_END" ]; then
    echo "Partition already at maxmium, rebooting"
    #reboot_pi
  fi
  echo "ROOT_PART_NUM $ROOT_PART_NUM"
  echo "TARGET_END $TARGET_END"
  echo "ROOT_DEV $ROOT_DEV"

  if ! printf "resizepart %s\nyes\n%ss\n" "$ROOT_PART_NUM" "$TARGET_END" | parted "$ROOT_DEV" ---pretend-input-tty; then
    FAIL_REASON="Root partition resize failed"
    echo $FAIL_REASON
    return 1
  fi

  echo "Partizion resized correctly"
  echo "Resizing filesystem"
  sleep 5
  mount / -o remount
  resize2fs /dev/mmcblk1p2
  sleep 5
  mount / -o remount,ro
  echo "Filesystem resized"
  #fix_partuuid

  return 0
}

mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t tmpfs tmp /run
mkdir -p /run/systemd

mount /boot
mount / -o remount,ro

sed -i 's| init=/home/astronaut/\.astroarch/init_resize\.sh||' /boot/boot.txt
cd /boot && ./mkscr && cd /

mount /boot -o remount,ro
sync

#if ! check_commands; then
#  reboot_pi
#fi

if main; then
  whiptail --infobox "Resized root filesystem. Rebooting in 5 seconds..." 20 60
  sleep 5
else
  whiptail --msgbox "Could not expand filesystem, please try raspi-config or rc_gui.\n${FAIL_REASON}" 20 60
  sleep 5
fi

reboot_pi
