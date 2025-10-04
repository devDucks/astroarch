#!/bin/bash

# Grab the OS architecture for further forked logic
ARCH=$(uname -m)

# Check packages
check_pishrink=$(paru -Q | grep -c pishrink-git)

if [ $check_pishrink -eq 0 ]; then
    paru -Sy pishrink-git --noconfirm
fi

check_pigz=$(paru -Q | grep -c pigz)

if [ $check_pigz -eq 0 ]; then
    paru -Sy pigz --noconfirm
fi

check_archinstallscripts=$(paru -Q | grep -c arch-install-scripts)

if [ $check_archinstallscripts -eq 0 ]; then
    paru -Sy arch-install-scripts --noconfirm
fi

check_dosfstools=$(paru -Q | grep -c dosfstools)

if [ $check_dosfstools -eq 0 ]; then
    paru -Sy dosfstools --noconfirm
fi

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
echo $PART1
echo $PART2

echo "Installing on $DISK"
echo "Are you sure ?"
read -p "Press enter to continue"
echo
echo "Erase disk $DISK"
read -p "Press enter to continue"

# Erase
sudo sfdisk --wipe always --delete $DISK
echo

sudo sfdisk --quiet --wipe always $DISK << EOF
,+512M,0c,
,,,
EOF

# Format
echo "Format partitions on $DISK"
#read -p "Press enter to continue"
sudo mkfs.vfat $PART1
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
sudo cp diskchroot ~/root

#echo 'astro' | sudo -S echo ''

# Copy of the 50G astrometry file
#sudo mkdir -p ~/root/kstars/astronomy/
#sudo cp ~/.local/share/kstars/astrometry/* ~/root/kstars/astronomy/

echo 'astro' | sudo -S echo ''
sudo cp astroarch_build_chroot.sh /home/astronaut/root

echo 'astro' | sudo -S echo ''

# Install base rpi
echo "Install ArchLinux base rpi"
sudo pacstrap -K ~/root base base-devel linux-rpi linux-rpi-headers linux-firmware-whence linux-firmware linux-api-headers archlinuxarm-keyring

echo 'astro' | sudo -S echo ''

# Chroot and install AstroArch
echo "arch-chroot : install AstroArch"
sudo -S arch-chroot ~/root /astroarch_build_chroot.sh

echo 'astro' | sudo -S echo ''

# Umount disk and delete folder
echo "umount" $DISK
sudo umount -l $PART1
sudo umount -l $PART2
echo "delete folder root"
sudo rm -R ~/root

echo 'astro' | sudo -S echo ''

# Make image
echo "create image astroarch"
read -rp "What version number do you want for the image : " version
sudo dd if=$DISK of=astroarch.img bs=8M status=progress
echo 'astro' | sudo -S echo ''
sudo pishrink.sh -za astroarch.img astroarch-$version.img.gz
echo "Your image astroarch.img astroarch-$version.img.gz is ready"
