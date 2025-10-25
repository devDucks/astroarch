#!/bin/bash

source /etc/profile

# Exit on the first error, if any
set -e

# Grab the OS architecture for further forked logic
ARCH=$(uname -m)

DISK=$(cat 'diskchroot')

# Add UUID AstroArch partion 2
tune2fs -U c2cea082-7f3e-43e2-b6a1-0c8540d350cc "$DISK"2""

UUID_part1=$(blkid -o value -s UUID "$DISK"1"")
UUID_part2=$(blkid -o value -s UUID "$DISK"2"")
echo $DISK

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
sed -i 's|#ParallelDownloads = 5|ParallelDownloads=5|g' /etc/pacman.conf
sed -i 's|#ParallelDownloads = 5|ParallelDownloads=5\nILoveCandy\nDisableDownloadTimeout\n|g' /etc/pacman.conf

# Add astroarch pacman repo to pacman.conf (it must go first)
sed -i 's|\[core\]|\[astromatto\]\nSigLevel = Optional TrustAll\nServer = http://astroarch.astromatto.com:9000/$arch\n\n\[core\]|' /etc/pacman.conf

# Bootstrap pacman-key
pacman-key --init && pacman-key --populate archlinuxarm

# Update all packages now
pacman -Syu --noconfirm

# install packages
pacman -S wget git zsh vi dhcp dnsmasq paru usbutils uboot-tools cloud-guest-utils websockify \
		openssl-1.1 i2c-tools dhcpcd fuse2 pacman-contrib arandr  nss-mdns \
		arch-install-scripts argon2  atkmm bc cairomm dnssec-anchors dosfstools \
		ecryptfs-utils geoclue glibmm gparted gtkmm3 imath iw lbzip2 ldns \
		libdeflate libomxil-bellagio libsigc++ libsoup lrzip lzop nano net-tools netctl nilfs-utils \
		raspberrypi-utils rpi5-eeprom sshfs wireless-regdb wireless_tools drbl dtc \
		fortune-mod cowsay neofetch flatpak ark cups cups-pdf rpi-imager \
		openexr openresolv pangomm partimage pbzip2 pigz pixz jq \
		plasma-desktop plasma-nm plasma-x11-session sddm sddm-kcm xf86-video-dummy xf86-video-fbdev xorg xorg-fonts-misc \
		gnu-free-fonts breeze-icons hicolor-icon-theme \
		networkmanager network-manager-applet networkmanager-qt \
		knotifyconfig kplotting qt6-datavis3d qt5-quickcontrols knewstuff packagekit-qt6 qt6-serialport \
		qt6ct udisks2-qt5 qt6-serialport qt6-websockets qtkeychain \
		plasma-systemmonitor dolphin kate konsole ksystemlog discover kwalletmanager \
		kgpg spectacle kscreen dialog kdenetwork-filesharing screen kdialog \
		gpsd chrony tigervnc novnc samba pipewire-jack wireplumber \
		chromium firefox astroarch-status-notifications astromonitor astroarch-onboarding \
		xplanet astrometry.net gsc kstars phd2 stellarsolver astro_dmx \
		indi-3rdparty-libs indi-3rdparty-drivers indiserver-ui libcamera-ipa astroarch-onboarding --noconfirm --ask 4

# config hostnames
echo "astroarch" > /etc/hostname
echo "127.0.0.1          localhost" >> /etc/hosts
echo "127.0.1.1          astroarch" >> /etc/hosts

# Uncomment en_US UTF8 and generate locale files
sed -i -e 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen

# Set a standard TZ to avoid breaking plasma clock widget
timedatectl set-timezone Europe/London

# Allow wheelers to sudo without password to install packages
sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers

# create user astro with home, add it to wheel
useradd -mG wheel -m astronaut
echo "astronaut:astro" | chpasswd

# Add astronaut to uucp for serial device ownership
usermod -aG uucp,sys,network,power,audio,input,lp,storage,video,users astronaut

# XDG user directories
su astronaut -c "xdg-user-dirs-update"

# Add sddm user to video group
usermod -aG video sddm

# Pull the brain repo, this will be used for scripting out the final image
su astronaut -c "git clone https://github.com/devDucks/astroarch.git /home/astronaut/.astroarch"

# Allow x11 forwarding over SSH
sed -i 's/#AllowTcpForwarding yes/AllowTcpForwarding yes/g' /etc/ssh/sshd_config
sed -i 's/#X11DisplayOffset 10/X11DisplayOffset 10/g' /etc/ssh/sshd_config
sed -i 's/#X11UseLocalhost yes/X11UseLocalhost yes/g' /etc/ssh/sshd_config

# Install AUR packages
su astronaut -c "paru -Sy xrdp xorgxrdp --noconfirm"

# Make all necessary folders
mkdir /etc/sddm.conf.d
su astronaut -c "mkdir -p /home/astronaut/Pictures/wallpapers"

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
su astronaut -c "ln -s /home/astronaut/.astroarch/configs/.zshrc /home/astronaut/.zshrc"

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
ln -s /home/astronaut/.astroarch/systemd/resize_once.service /etc/systemd/system/resize_once.service
ln -s /home/astronaut/.astroarch/configs/.astroarch.version /home/astronaut/.astroarch.version
ln -s /home/astronaut/.astroarch/systemd/astroarch-onboarding.service /etc/systemd/system/astroarch-onboarding.service
ln -s /home/astronaut/.astroarch/systemd/astroarch-onboarding.timer /etc/systemd/system/astroarch-onboarding.timer

# Copy xorg config
cp /home/astronaut/.astroarch/configs/xorg.conf /etc/X11/

# Copy v3d X config
cp /home/astronaut/.astroarch/configs/99-v3d.conf /etc/X11/xorg.conf.d

# Copy udev rule to disable wifi power saving
cp /home/astronaut/.astroarch/configs/81-wifi-powersave.rules /etc/udev/rules.d/81-wifi-powersave.rules

# Copy the polkit script to allow rebooting, shutting down with no errors
cp /home/astronaut/.astroarch/configs/99-polkit-power.rules /etc/polkit-1/rules.d/

# Copy the systemd unit to create AP / resize
cp /home/astronaut/.astroarch/systemd/create_ap.service /etc/systemd/system/

# Copy the config for kwinrc
su astronaut -c "cp /home/astronaut/.astroarch/configs/kwinrc /home/astronaut/.config"

# Enable xrdp
mv /etc/xrdp/startwm.sh /etc/xrdp/startwm.sh-old
ln -s /home/astronaut/.astroarch/configs/startwm.sh /etc/xrdp/startwm.sh
ln -s /home/astronaut/.astroarch/configs/Xwrapper.config /etc/xrdp/Xwrapper.config
cp /home/astronaut/.astroarch/configs/50-udiskie.rules /etc/polkit-1/rules.d/50-udiskie.rules
cp /home/astronaut/.astroarch/configs/50-networkmanager.rules /etc/polkit-1/rules.d/50-networkmanager.rules
# Add user xrdp
sudo useradd xrdp -d / -c 'xrdp daemon' -s /usr/sbin/nologin
# Set user in xrdp.ini
sudo sed -i '/#runtime_user=xrdp/s/^#//' /etc/xrdp/xrdp.ini
sudo sed -i '/#runtime_group=xrdp/s/^#//' /etc/xrdp/xrdp.ini
sudo sed -i '/#SessionSockdirGroup=xrdp/s/^#//' /etc/xrdp/sesman.ini
# Set permissions
sudo chown root:xrdp /etc/xrdp/rsakeys.ini
sudo chmod u=rw,g=r /etc/xrdp/rsakeys.ini
sudo chmod 755 /etc/xrdp/cert.pem
sudo chmod 755 /etc/xrdp/key.pem
# Allows adding devices from the xorg.conf.d section
sudo sed -i '/Option "AutoAddDevices" "off"/s/^/#/' /etc/X11/xrdp/xorg.conf

# Enable now all services
systemctl enable systemd-resolved.service dhcpcd.service sshd.service systemd-networkd.service sddm.service novnc.service NetworkManager.service avahi-daemon.service nmb.service smb.service create_ap.service x0vncserver.service cups.service xrdp.service xrdp-sesman.service resize_once.service

# Install astrometry files
#mkdir -p /home/astronaut/.local/share/kstars/astrometry/
#mv /kstars/astronomy/* /home/astronaut/.local/share/kstars/astrometry/

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
su astronaut -c "cp /home/astronaut/.astroarch/desktop/update-astroarch.desktop /home/astronaut/Desktop/update-astroarch"
su astronaut -c "cp /home/astronaut/.astroarch/desktop/astroarch-tweak-tool.desktop /home/astronaut/Desktop/AstroArch-Tweak-Tool"
su astronaut -c "cp /usr/share/astroarch_onboarding/desktop/AstroArch-onboarding.desktop /home/astronaut/Desktop/AstroArch-onboarding.desktop"

# Autostart AstroArch-onboarding
su astronaut -c "mkdir /home/astronaut/.config/autostart"
su astronaut -c "cp /usr/share/astroarch_onboarding/desktop/AstroArch-onboarding-x11.desktop /home/astronaut/.config/autostart/AstroArch-onboarding-x11.desktop"
su astronaut -c "cp /usr/share/astroarch_onboarding/desktop/AstroArch-onboarding-xrdp.desktop /home/astronaut/.config/autostart/AstroArch-onboarding-xrdp.desktop"

# Make the icons executable so there will be no ! on the first boot
chmod +x /home/astronaut/Desktop/update-astroarch

# Remove actual novnc icons
rm -r /usr/share/webapps/novnc/app/images/icons/*

# Copy custom novnc icons folder
cp -r /home/astronaut/.astroarch/assets/icons/* /usr/share/webapps/novnc/app/images/icons

# Copy the screensaver config, by default it is off
su astronaut -c "cp /home/astronaut/.astroarch/configs/kscreenlockerrc /home/astronaut/.config/kscreenlockerrc"

# Config plasma theme AstroArch
cp -r /home/astronaut/.astroarch/configs/look-and-feel/astroarch /usr/share/plasma/look-and-feel/
cp -r /home/astronaut/.astroarch/configs/layout-templates/astroarchPanel /usr/share/plasma/layout-templates/

chown root:root /home/astronaut/.astroarch/configs/kdeglobals
chmod 644 /home/astronaut/.astroarch/configs/kdeglobals
cp /home/astronaut/.astroarch/configs/kdeglobals /etc/xdg/

# Disable Kwallet by default
su astronaut -c "echo $'[Wallet]\nEnabled=false' > /home/astronaut/.config/kwalletrc"

# Assigns files to user astronaut
chown -R astronaut:astronaut /home/astronaut

# Take sudoers to the original state
sed -i 's/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers

echo "exit arch-chroot"
exit
