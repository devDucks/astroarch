#!/bin/bash
# Exit on the first error, if any

set -e

# Grab the OS architecture for further forked logic
ARCH=$(uname -m)

#paru -S pishrink-git

# Choose disk to write and prepare
count=0
IFS=$'\n'
for device_info in `lsblk -d -n -o NAME,TYPE,SIZE`; do
count=$((count+1))
device_name=$(echo $device_info | cut -d" " -f1)
dev[$count]=$device_name
printf '%s: %s\n' "$count" "$device_info"
done

read -rp "Select disk (numbers 1-$count): " selection

DISK="/dev/${dev[$selection]}"
PART1="$DISK"1""
PART2="$DISK"2""

echo "Installing on $DISK"
echo "Are you sure ?"
read -p "Press enter to continue"
echo
echo "Erase disk $DISK"
read -p "Press enter to continue"
sudo -S dd if=/dev/zero of=$DISK bs=440 count=1 status=progress
echo
echo "Make partitions on $DISK"
#read -p "Press enter to continue"
(
  echo p;
  echo o;
  echo n;
  echo ;
  echo ;
  echo ;
  echo +537M;
  echo t;
  echo 0c;
  echo a;
  echo n;
  echo ;
  echo ;
  echo ;
  echo ;
  echo w;
) | sudo fdisk $DISK
echo
echo "Format partitions on $DISK"
#read -p "Press enter to continue"
sudo mkfs.vfat -n 'BOOT' $PART1
echo y | sudo mkfs.ext4 $PART2
echo "done"


# Create folder and mount
echo "Create folder root"
if [ ! -d ~/root ]; then
  mkdir ~/root
fi
echo "Mount partitions in folder"
#read -p "Press enter to continue"
sudo mount $PART2 ~/root
if [ ! -d ~/root/boot ]; then
  sudo mkdir ~/root/boot
fi
sudo mount $PART1 ~/root/boot
echo 'astro' | sudo -S echo ''
# Copy some files in chroot
echo $DISK > diskchroot
sudo cp ~/diskchroot ~/root
echo 'astro' | sudo -S echo ''
sudo mkdir -p ~/root/kstars/astronomy/
sudo cp ~/.local/share/kstars/astrometry/* ~/root/kstars/astronomy/
echo 'astro' | sudo -S echo ''
sudo cp astroarch_build_chroot.sh /home/astronaut/root
echo 'astro' | sudo -S echo ''
# Install base
echo "Install ArchLinux base"
#read -p "Press enter to continue"
# sudo pacstrap -K ~/root base base-devel linux-rpi linux-rpi-headers linux-firmware-whence linux-firmware linux-api-headers archlinuxarm-keyring
sudo pacstrap -K ~/root base linux-rpi linux-firmware base-devel linux-api-headers archlinuxarm-keyring
echo 'astro' | sudo -S echo ''
# Enter chroot and install AstroArch
echo "arch-chroot : install AstroArch"
#read -p "Press enter to continue"
sudo -S arch-chroot ~/root /astroarch_build_chroot.sh
echo 'astro' | sudo -S echo ''
# Umount disk and delete folder
echo "umount" $DISK
sudo umount -l $PART1
sudo umount -l $PART2
echo "delete folder root"
sudo rm -R ~/root
echo 'astro' | sudo -S echo ''
echo "create image astroarch"
sudo dd if=$DISK of=astroarch.img bs=8M status=progress
echo 'astro' | sudo -S echo ''
sudo pishrink.sh -za astroarch.img astroarch-X.X.X.img.gz
