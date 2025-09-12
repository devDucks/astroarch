#!/bin/bash

# put your device here
SDDEV=/dev/sde

SDPARTBOOT="${SDDEV}1"
SDPARTROOT="${SDDEV}2"
WORKDIR=${HOME}/arch-install
SDMOUNT=${WORKDIR}/sd
LINUXRPI=${WORKDIR}/linux-rpi

# creating directories

sudo umount $SDPARTBOOT
sudo umount $SDPARTROOT

mkdir -p ${SDMOUNT}
mkdir -p ${LINUXRPI}

pushd ${WORKDIR}/

echo ""
echo "====== Download ======"
echo ""

wget -nc http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz

# download core.db to search for the latest linux-rpi to get the bootloader
base="http://mirror.archlinuxarm.org/aarch64/core"

if [ ! -f "core.db.tar.gz" ]; then
    curl -JLO ${base}/core.db.tar.gz
else
    echo "File ‘core.db.tar.gz’ already there; not retrieving."
fi

# search for latest version of the file to download
latest_pkg=$(tar -tzf core.db.tar.gz \
  | grep -E '^linux-rpi-[0-9]+\.[0-9]+\.[0-9]+-[0-9]+/desc$' \
  | while read f; do
      tar -xOzf core.db.tar.gz "$f" | awk '/%FILENAME%/{getline; print}'
    done | grep 'aarch64' | sort -V | tail -n1)


# and download it
if [ ! -f "${latest_pkg}" ]; then
    curl -JLO "${base}/${latest_pkg}"
else
    echo "File ‘${latest_pkg}’ already there; not retrieving."
fi

echo
echo " - Extracting linux-rpi"
rm -rf ${LINUXRPI}/* # clean folder
tar -xf "${latest_pkg}" -C "${LINUXRPI}/"
echo " - done"


echo ""
echo "====== Disk Partition ======"
echo ""

# clear partitions
sudo sfdisk --wipe always --delete $SDDEV

# create partitions
sudo sfdisk --quiet --wipe always $SDDEV << EOF
,+512M,0c,
,,,
EOF

# formatting the partitions
sudo mkfs.vfat -F 32 $SDPARTBOOT
sudo mkfs.ext4 -E lazy_itable_init=0,lazy_journal_init=0 -F $SDPARTROOT

sudo mount $SDPARTROOT ${SDMOUNT}
sudo mkdir -p ${SDMOUNT}/boot
sudo mount $SDPARTBOOT ${SDMOUNT}/boot

# exit 1
echo ""
echo "====== Mount and copy Bootloader ======"
echo ""

echo "- copying root folder..."
sudo bsdtar -xpf "${WORKDIR}/ArchLinuxARM-rpi-aarch64-latest.tar.gz" -C "$SDMOUNT"
echo "- done" 

# remove u-boot and copy bootloader from archlinux
sudo rm -rf ${SDMOUNT}/boot/*
sudo cp -rf ${LINUXRPI}/boot/* ${SDMOUNT}/boot/


echo ""
echo "====== Setup SSH ======"
echo ""

# change authentication with password in sshd_config
sudo sed -i \
  -e 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' \
  -e 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' \
  ${SDMOUNT}/etc/ssh/sshd_config

echo "- done."
echo " "
echo "- Unmount SD card"

# unmount 
sudo umount $SDPARTBOOT
sudo umount $SDPARTROOT
echo "- done."
echo " "
echo "============ Finish =============="
echo " "
echo " "
echo "When booting on your raspberry with (user: root ; passw: root) run this commands:"
echo " "
echo "> pacman-key --init"
echo "> pacman-key --populate archlinuxarm"
echo " "
echo "> pacman -R linux-aarch64 uboot-raspberrypi"
echo "> pacman -Syu --overwrite \"/boot/*\" linux-rpi"
echo " "
echo "> reboot"
popd


