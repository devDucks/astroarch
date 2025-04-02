#!/bin/bash

source /etc/profile

# Exit on the first error, if any
set -e

# Grab the OS architecture for further forked logic
ARCH=$(uname -m)

DISK=$(cat 'diskchroot')
UUID_part1=$(blkid -o value -s UUID "$DISK"1"")
UUID_part2=$(blkid -o value -s UUID "$DISK"2"")
echo $DISK

sed -i 's/root=\/dev\/mmcblk0p2/root=UUID='$UUID_part2'/' /boot/cmdline.txt
sed -i '/root/ s/$/ video=HDMI-A-1:1920x1080M@60D/' /boot/cmdline.txt

# ROOT PASSWD
echo "root passwd"
echo "root:root" | chpasswd

# FSTAB
cat << EOF >> /etc/fstab
# Static information about the filesystems.
# See fstab(5) for details.

UUID=$UUID_part1  /boot   vfat    defaults,noexec,nodev,showexec        0       0
UUID=$UUID_part2  /       ext4    rw,relatime                           0       1
EOF

# Parallelize pacman download to 5 and use pacman as progress bar
sed -i 's|ParallelDownloads = 5|ParallelDownloads=5|g' /etc/pacman.conf
sed -i '/ParallelDownloads=5/aILoveCandy' /etc/pacman.conf
sed -i '/ParallelDownloads=5/aDisableDownloadTimeout' /etc/pacman.conf

# Add astroarch pacman repo to pacman.conf (it must go first)
sed -i 's|\[core\]|\[astromatto\]\nSigLevel = Optional TrustAll\nServer = http://astroarch.astromatto.com:9000/$arch\n\n\[core\]|' /etc/pacman.conf

# config hostnames
echo "astroarch" > /etc/hostname
echo "127.0.0.1          localhost" >> /etc/hosts
echo "127.0.1.1          astroarch" >> /etc/hosts


# Bootstrap pacman-key
pacman-key --init && pacman-key --populate archlinuxarm

# Allows installation without asking for the root password after waiting
#sed -i 's|# unlock_time = 600|unlock_time = 0|g'  /etc/security/faillock.conf
#sed -i 's|# root_unlock_time = 900|root_unlock_time = 0|g'  /etc/security/faillock.conf

# Update all packages now
pacman -Syu --noconfirm

# install packages
pacman -S wget git pipewire-jack gnu-free-fonts wireplumber \
        zsh plasma-desktop sddm networkmanager xf86-video-dummy \
		network-manager-applet networkmanager-qt chromium xorg konsole \
		gpsd breeze-icons hicolor-icon-theme knewstuff5 tigervnc \
		knotifyconfig5 kplotting5 qt6-datavis3d qt5-quickcontrols \
		qt5-websockets qtkeychain stellarsolver xf86-video-fbdev \
		xplanet plasma-nm dhcp dnsmasq kate plasma-systemmonitor \
		dolphin uboot-tools usbutils cloud-guest-utils samba paru \
		websockify novnc astrometry.net gsc kstars phd2 packagekit-qt6 \
		indi-3rdparty-libs indi-3rdparty-drivers rpi-imager \
		i2c-tools indiserver-ui astro_dmx openssl-1.1 firefox chrony \
		ksystemlog discover kwalletmanager kgpg dhcpcd spectacle \
		qt6-serialport qt6ct udisks2-qt5 xorg-fonts-misc fuse2 \
		fortune-mod cowsay pacman-contrib arandr neofetch nss-mdns \
		astromonitor kscreen sddm-kcm flatpak ark cups cups-pdf\
		arch-install-scripts argon2 astroarch-status-notifications atkmm bc cairomm dialog dnssec-anchors dosfstools \
		ecryptfs-utils geoclue glibmm gparted gtkmm3 imath iw kdenetwork-filesharing lbzip2 ldns libcamera libcamera-ipa \
		libdeflate libomxil-bellagio libsigc++ libsoup lrzip lzop nano net-tools netctl networkmanager-qt5 nilfs-utils \
		openexr openresolv pangomm partimage pbzip2 pigz pixz qt5-serialport \
		qt5ct raspberrypi-utils rpi5-eeprom screen sshfs vi wireless-regdb wireless_tools drbl dtc --noconfirm --ask 4

# Uncomment en_US UTF8 and generate locale files
sed -i -e 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen

# Set a standard TZ to avoid breaking plasma clock widget
timedatectl set-timezone Europe/London

# Allow wheelers to sudo without password to install packages
sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers

# create user astro with home, add it to wheel
useradd -G wheel -m astronaut
echo "astronaut:astro" | chpasswd

# Add astronaut to uucp for serial device ownership
usermod -aG uucp,sys,network,power,audio,input,lp,storage,video,users astronaut
su astronaut -c "xdg-user-dirs-update"

# Add sddm user to video group
usermod -aG video sddm

# Pull the brain repo, this will be used for scripting out the final image
#su astronaut -c "git clone https://github.com/devDucks/astroarch.git /home/astronaut/.astroarch"
su astronaut -c "git clone -b 1.10 --single-branch https://github.com/sc74/astroarch.git /home/astronaut/.astroarch"

# Allow x11 forwarding over SSH
sed -i 's/#AllowTcpForwarding yes/AllowTcpForwarding yes/g' /etc/ssh/sshd_config
sed -i 's/#X11DisplayOffset 10/X11DisplayOffset 10/g' /etc/ssh/sshd_config
sed -i 's/#X11UseLocalhost yes/X11UseLocalhost yes/g' /etc/ssh/sshd_config

# Make all necessary folders
mkdir /etc/sddm.conf.d
#su astronaut -c "mkdir -p /home/astronaut/.config"
su astronaut -c "mkdir -p /home/astronaut/Pictures/wallpapers"
#su astronaut -c "mkdir -p /home/astronaut/Desktop"

# install oh-my-zsh and set the default shell to zsh
chsh -s /usr/bin/zsh astronaut
rm /home/astronaut/.bash*
cd /home/astronaut
ZSH=/home/astronaut/.oh-my-zsh sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
chown astronaut:astronaut .oh-my-zsh/

# Set local Hostname resolution
sed -i 's|hosts: mymachines |&mdns_minimal [NOTFOUND=return] |g' /etc/nsswitch.conf

# Set the samba pass
ln -s /home/astronaut/.astroarch/configs/smb.conf /etc/samba/smb.conf
systemctl start smb
(echo astro; echo astro) | smbpasswd -s -a astronaut
systemctl stop smb

# Link a zsh config for astronaut
su astronaut -c "ln -s /home/astronaut/.astroarch/build-astroarch/configs/.zshrc /home/astronaut/.zshrc"

# Start NetworkManager and sleep to create the hotspot
systemctl start NetworkManager
sleep 5

# Remove eventually existing systemd configs we are going to substitute
rm -f /usr/lib/systemd/system/novnc.service

# Disable systemd-timesyncd and enable chronyd
systemctl disable systemd-timesyncd
systemctl enable chronyd

# Symlink now files
ln -s /home/astronaut/.astroarch/configs/kde_settings.conf /etc/sddm.conf.d/kde_settings.conf
ln -s /home/astronaut/.astroarch/systemd/novnc.service /usr/lib/systemd/system/novnc.service
ln -s /home/astronaut/.astroarch/systemd/x0vncserver.service /etc/systemd/system/x0vncserver.service
ln -s /home/astronaut/.astroarch/configs/.astroarch.version /home/astronaut/.astroarch.version

# Copy config.txt in /boot
cp /home/astronaut/.astroarch/configs/config.txt /boot

# Copy xorg config
cp /home/astronaut/.astroarch/configs/xorg.conf /etc/X11/

# Copy v3d X config
cp /home/astronaut/.astroarch/configs/99-v3d.conf /etc/X11/xorg.conf.d

# Copy the polkit script to allow rebooting, shutting down with no errors
cp /home/astronaut/.astroarch/configs/99-polkit-power.rules /etc/polkit-1/rules.d/

# Copy the systemd unit to create AP / resize
cp /home/astronaut/.astroarch/systemd/create_ap.service /etc/systemd/system/
cp /home/astronaut/.astroarch/systemd/resize_once.service /etc/systemd/system/

# Enable vncserver
systemctl enable x0vncserver

# Copy the config for kwinrc
su astronaut -c "cp /home/astronaut/.astroarch/configs/kwinrc /home/astronaut/.config"

# Enable now all services
systemctl enable systemd-resolved.service dhcpcd.service sshd.service systemd-networkd.service sddm.service novnc.service NetworkManager.service avahi-daemon.service nmb.service smb.service create_ap.service resize_once.service cups.service

# Script for autostart settings plasma
mkdir -p /home/astronaut/.config/autostart/
cp /home/astronaut/.astroarch/build-astroarch/desktop/plasmasystemsettings.sh.desktop /home/astronaut/.config/autostart/

# Script autostart update-astroarch
cp /home/astronaut/.astroarch/build-astroarch/desktop/update-astroarch.sh.desktop /home/astronaut/.config/autostart/

# Install astrometry files
mkdir -p /home/astronaut/.local/share/kstars/astrometry/
mv /kstars/astronomy/* /home/astronaut/.local/share/kstars/astrometry/

# Clear script in autostart
cp /home/astronaut/.astroarch/build-astroarch/systemd/clear-install-astroarch.service /etc/systemd/system/
cp /home/astronaut/.astroarch/build-astroarch/systemd/clear-install-astroarch.timer /etc/systemd/system/
systemctl enable clear-install-astroarch.timer

# Copy wallpapers
su astronaut -c "cp /home/astronaut/.astroarch/wallpapers/bubble.jpg /home/astronaut/Pictures/wallpapers"
su astronaut -c "cp /home/astronaut/.astroarch/wallpapers/south-milky.jpg /home/astronaut/Pictures/wallpapers"
su astronaut -c "cp /home/astronaut/.astroarch/wallpapers/pacman.jpg /home/astronaut/Pictures/wallpapers"

# Copy desktop icons
su astronaut -c "ln -s /usr/share/applications/org.kde.konsole.desktop /home/astronaut/Desktop/Konsole"
su astronaut -c "ln -s /usr/share/applications/org.kde.kstars.desktop /home/astronaut/Desktop/Kstars"
su astronaut -c "ln -s /usr/share/applications/astrodmx_capture.desktop /home/astronaut/Desktop/AstroDMx_capture"
su astronaut -c "ln -s /usr/share/applications/phd2.desktop /home/astronaut/Desktop/phd2.desktop"
su astronaut -c "ln -s /usr/share/applications/xgps.desktop /home/astronaut/Desktop/xgps.desktop"
su astronaut -c "ln -s /usr/share/applications/indiserver-ui.desktop /home/astronaut/Desktop/indiserver-ui.desktop"

# Remove actual novnc icons
rm -r /usr/share/webapps/novnc/app/images/icons/*

# Copy custom novnc icons folder
cp -r /home/astronaut/.astroarch/assets/icons/* /usr/share/webapps/novnc/app/images/icons

# Copy the screensaver config, by default it is off
su astronaut -c "cp /home/astronaut/.astroarch/configs/kscreenlockerrc /home/astronaut/.config/kscreenlockerrc"

# Disable Kwallet by default
su astronaut -c "echo $'[Wallet]\nEnabled=false' > /home/astronaut/.config/kwalletrc"

# Assigns files to user astronaut
chown -R astronaut:astronaut /home/astronaut

########################################################################################
# This section allows you to install some packages from a GitHub repo. If the packages are on your site with a repo, install the packages in the packages section. Then copy the services to /etc/systemd/system and enable them
# Onboarding
# Disable alpm for repo in disk
sed -i 's|DownloadUser = alpm|#DownloadUser = alpm|g' /etc/pacman.conf
# Repository sc74.github.io
su astronaut -c "git clone https://github.com/sc74/sc74.github.io.git /home/astronaut/.astroarch/sc74.github.io"
sed -i 's|\[astromatto\]|\[sc74\]\nSigLevel = Optional TrustAll\nServer = file:///home/astronaut/.astroarch/sc74.github.io/aarch64\n\n\[astromatto\]|' /etc/pacman.conf
yes | LC_ALL=en_US.UTF-8 pacman -Syu --noconfirm
# Install package astroarch-onboarding
yes | LC_ALL=en_US.UTF-8 pacman -S astroarch-onboarding --noconfirm --ask 4
cp /home/astronaut/.astroarch/build-astroarch/systemd/astroarch-onboarding.service /etc/systemd/system/
systemctl enable astroarch-onboarding.service

# Install some packages
pacman -S rustdesk-bin indi-pylibcamera libcamera-rpi python-libcamera-rpi libcamera-ipa-rpi libcamera-docs-rpi libcamera-tools-rpi  \
		gst-plugin-libcamera-rpi python-pycamera2 rpicam-apps --noconfirm --ask 4
# Delete repo sc74
sed -i -e '/\[sc74\]/,+2d' /etc/pacman.conf
# Enable alpm
sed -i 's|#DownloadUser = alpm|DownloadUser = alpm|g' /etc/pacman.conf
########################################################################################

# Restores faillock
sed -i 's|unlock_time = 0|# unlock_time = 600|g'  /etc/security/faillock.conf

# Take sudoers to the original state
sed -i 's/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers

echo "exit arch-chroot"
exit
