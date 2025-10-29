# Exit on the first error, if any
set -e

# Grab the OS architecture for further forked logic
ARCH=$(uname -m)
HAS_VIRT=$(command -v systemd-detect-virt >/dev/null 2>&1 && echo 1 || echo 0)

# Parallelize pacman download to 5 and use pacman as progress bar
if [ "$HAS_VIRT" -eq 0 ]; then
    sed -i 's|#ParallelDownloads = 5|ParallelDownloads = 5|g' /etc/pacman.conf
    sed -i 's|ParallelDownloads = 5|ParallelDownloads = 5\nILoveCandy|g' /etc/pacman.conf
    sed -i 's|ParallelDownloads = 5|ParallelDownloads = 5\nDisableDownloadTimeout|g' /etc/pacman.conf
fi

# Add astroarch pacman repo to pacman.conf (it must go first)
if [ "$HAS_VIRT" -eq 0 ]; then
    sed -i 's|\[core\]|\[astromatto\]\nSigLevel = Optional TrustAll\nServer = http://astroarch.astromatto.com:9000/$arch\n\n\[core\]|' /etc/pacman.conf
fi

# Bootstrap pacman-key
pacman-key --init && pacman-key --populate archlinuxarm

# Update all packages now
pacman -Syu --noconfirm

# Install just 2 packages for the next actions
# list of commented locales
pacman -S wget sudo git --noconfirm

# create user astro with home, add it to wheel
useradd -G wheel -m astronaut
echo "astronaut:astro" | chpasswd

# Pull the brain repo, this will be used for scripting out the final image
su astronaut -c "git clone https://github.com/devDucks/astroarch.git /home/astronaut/.astroarch"

# Uncomment en_US UTF8 and generate locale files
sed -i -e 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen

# If we are on QEMU, packages have already been pulled in the docker phase - install only the pi kernel
if [ "$HAS_VIRT" -eq 1 ]; then
    pacman -Syu linux-rpi linux-rpi-headers linux-firmware --noconfirm --ask 4
else
    pacman -Syu base-devel pipewire-jack gnu-free-fonts wireplumber \
       zsh plasma-desktop sddm networkmanager xf86-video-dummy \
       network-manager-applet networkmanager-qt xorg konsole \
       gpsd breeze-icons hicolor-icon-theme knewstuff tigervnc \
       knotifyconfig kplotting qt6-datavis3d qt5-quickcontrols \
       qt6-websockets qtkeychain stellarsolver xf86-video-fbdev \
       xplanet plasma-nm dhcp dnsmasq kate plasma-systemmonitor \
       dolphin uboot-tools usbutils cloud-guest-utils samba paru \
       websockify novnc astrometry.net gsc kstars phd2 packagekit-qt6 \
       indi-3rdparty-libs indi-3rdparty-drivers linux-rpi linux-rpi-headers \
       i2c-tools indiserver-ui astro_dmx openssl-1.1 firefox chrony \
       ksystemlog discover kwalletmanager kgpg qt6-serialbus \
       qt6-serialport qt6ct udisks2 xorg-fonts-misc fuse2 \
       fortune-mod cowsay pacman-contrib arandr neofetch \
       astromonitor kscreen sddm-kcm flatpak plasma-x11-session \
       kdialog jq astroarch-onboarding dhcpcd iw --noconfirm --ask 4
fi


# Allow wheelers to sudo without password to install packages
sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers

# Add astronaut to uucp for serial device ownership
usermod -aG uucp,sys,network,power,audio,input,lp,storage,video,users astronaut

# Add sddm user to video group
usermod -aG video sddm

# Allow x11 forwarding over SSH
sed -i 's/#AllowTcpForwarding yes/AllowTcpForwarding yes/g' /etc/ssh/sshd_config
sed -i 's/#X11DisplayOffset 10/X11DisplayOffset 10/g' /etc/ssh/sshd_config
sed -i 's/#X11UseLocalhost yes/X11UseLocalhost yes/g' /etc/ssh/sshd_config

# Install AUR packages
su astronaut -c "paru -Sy xrdp xorgxrdp --noconfirm"

# Make all necessary folders
mkdir /etc/sddm.conf.d
su astronaut -c "mkdir -p /home/astronaut/.config"
su astronaut -c "mkdir -p /home/astronaut/Pictures/wallpapers"
su astronaut -c "mkdir -p /home/astronaut/Desktop"

# install oh-my-zsh and set the default shell to zsh
chsh -s /usr/bin/zsh astronaut
rm /home/astronaut/.bash*
cd /home/astronaut
ZSH=/home/astronaut/.oh-my-zsh sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
chown -R astronaut:astronaut /home/astronaut/.oh-my-zsh/

# Set the samba pass
ln -s /home/astronaut/.astroarch/configs/smb.conf /etc/samba/smb.conf
systemctl start smb
(echo astro; echo astro) | smbpasswd -s -a astronaut
systemctl stop smb

# Link a zsh config for astronaut
ln -s /home/astronaut/.astroarch/configs/.zshrc /home/astronaut/.zshrc

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
ln -s /home/astronaut/.astroarch/systemd/x0vncserver-xrdp.service /etc/systemd/user/x0vncserver-xrdp.service

# Copy xorg config
cp /home/astronaut/.astroarch/configs/xorg.conf /etc/X11/

# Copy v3d X config
cp /home/astronaut/.astroarch/configs/99-v3d.conf /etc/X11/xorg.conf.d

# Copy udev rule to disable wifi power saving
cp /home/astronaut/.astroarch/configs/81-wifi-powersave.rules /etc/udev/rules.d/81-wifi-powersave.rules

# Polkit rules go here
cp /home/astronaut/.astroarch/configs/99-polkit-power.rules /etc/polkit-1/rules.d/
cp /home/astronaut/.astroarch/configs/50-udiskie.rules /etc/polkit-1/rules.d/
cp /home/astronaut/.astroarch/configs/50-networkmanager.rules /etc/polkit-1/rules.d/

# Copy the systemd unit to create the AP the first boot
cp /home/astronaut/.astroarch/systemd/create_ap.service /etc/systemd/system/

# Enable vncserver
systemctl enable x0vncserver
systemctl --user -M astronaut@ enable x0vncserver-xrdp

# Enable xrdp
mv /etc/xrdp/startwm.sh /etc/xrdp/startwm.sh-old
ln -sfn /home/astronaut/.astroarch/configs/startwm.sh /etc/xrdp/startwm.sh
ln -sfn /home/astronaut/.astroarch/configs/Xwrapper.config /etc/xrdp/Xwrapper.config
# Add user xrdp
sudo useradd xrdp -d / -c 'xrdp daemon' -s /usr/sbin/nologin
# Set user in xrdp.ini
sudo sed -i '/#runtime_user=xrdp/s/^#//' /etc/xrdp/xrdp.ini
sudo sed -i '/#runtime_group=xrdp/s/^#//' /etc/xrdp/xrdp.ini
sudo sed -i 's/bitmap_cache=true/bitmap_cache=false/g' /etc/xrdp/xrdp.ini
# Set user in xrdp.sesman.ini
sudo sed -i '/#SessionSockdirGroup=xrdp/s/^#//' /etc/xrdp/sesman.ini
sudo sed -i '/TerminalServerUsers=tsusers/s/^/#/' /etc/xrdp/sesman.ini
# Set permissions
sudo chown root:xrdp /etc/xrdp/rsakeys.ini
sudo chmod u=rw,g=r /etc/xrdp/rsakeys.ini
sudo chmod 755 /etc/xrdp/cert.pem
sudo chmod 755 /etc/xrdp/key.pem
# Allows adding devices from the xorg.conf.d section
sudo sed -i '/Option "AutoAddDevices" "off"/s/^/#/' /etc/X11/xrdp/xorg.conf

#
su astronaut -c "cat <<EOF >/home/astronaut/.config/plasmanotifyrc
[DoNotDisturb]
WhenFullscreen=false
WhenScreensMirrored=false
EOF"

# Copy the config for kwinrc
su astronaut -c "cp /home/astronaut/.astroarch/configs/kwinrc /home/astronaut/.config"

# Enable now all services
systemctl enable sddm.service \
	  novnc.service \
	  dhcpcd.service \
	  NetworkManager.service \
	  avahi-daemon.service \
	  nmb.service \
	  smb.service \
	  xrdp.service \
	  xrdp-sesman.service

# If we are on qemu, enable also the AP creation and resize scripts
if [ "$HAS_VIRT" -eq 1 ]; then
    systemctl enable create_ap.service resize_once.service
fi

# Take sudoers to the original state
sed -i 's/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers

# Copy wallpapers
su astronaut -c "cp /home/astronaut/.astroarch/wallpapers/bubble.jpg /home/astronaut/Pictures/wallpapers"
su astronaut -c "cp /home/astronaut/.astroarch/wallpapers/south-milky.jpg /home/astronaut/Pictures/wallpapers"
su astronaut -c "cp /home/astronaut/.astroarch/wallpapers/pacman.jpg /home/astronaut/Pictures/wallpapers"

# Autostart AstroArch-onboarding
su astronaut -c "mkdir /home/astronaut/.config/autostart"

# Copy desktop icons
su astronaut -c "ln -snf /usr/share/applications/org.kde.konsole.desktop /home/astronaut/Desktop/Konsole"
su astronaut -c "ln -snf /usr/share/applications/org.kde.kstars.desktop /home/astronaut/Desktop/Kstars"
su astronaut -c "ln -snf /usr/share/applications/astrodmx_capture.desktop /home/astronaut/Desktop/AstroDMx_capture"
su astronaut -c "ln -snf /usr/share/applications/phd2.desktop /home/astronaut/Desktop/PHD2"
su astronaut -c "ln -snf /home/astronaut/.astroarch/desktop/update-astroarch.desktop /home/astronaut/Desktop/update-astroarch"
su astronaut -c "ln -snf /home/astronaut/.astroarch/desktop/astroarch-tweak-tool.desktop /home/astronaut/Desktop/AstroArch-Tweak-Tool"
su astronaut -c "ln -snf /usr/share/astroarch_onboarding/desktop/AstroArch-onboarding.desktop /home/astronaut/Desktop/AstroArch-onboarding"
su astronaut -c "cp /usr/share/astroarch_onboarding/desktop/AstroArch-onboarding-x11.desktop /home/astronaut/.config/autostart/AstroArch-onboarding-x11.desktop"
su astronaut -c "cp /usr/share/astroarch_onboarding/desktop/AstroArch-onboarding-xrdp.desktop /home/astronaut/.config/autostart/AstroArch-onboarding-xrdp.desktop"

# Make the icons executable so there will be no ! on the first boot
chmod +x /home/astronaut/Desktop/update-astroarch
chmod +x /home/astronaut/Desktop/AstroArch-onboarding
chmod +x /home/astronaut/Desktop/AstroArch-Tweak-Tool

# Remove actual novnc icons
rm -r /usr/share/webapps/novnc/app/images/icons/*

# Copy custom novnc icons folder
cp -r /home/astronaut/.astroarch/assets/icons/* /usr/share/webapps/novnc/app/images/icons

# config hostnames
echo "astroarch" > /etc/hostname
echo "127.0.0.1          localhost" >> /etc/hosts
echo "127.0.1.1          astroarch" >> /etc/hosts

# Copy the screensaver config, by default it is off
su astronaut -c "cp /home/astronaut/.astroarch/configs/kscreenlockerrc /home/astronaut/.config/kscreenlockerrc"

# Set a standard TZ to avoid breaking plasma clock widget
timedatectl set-timezone Europe/London

# If we are on a raspberry let's adjust /boot/config.txt
cp /home/astronaut/.astroarch/configs/config.txt /boot/config.txt

install -o root -g root -m 644 /home/astronaut/.astroarch/configs/kdeglobals /etc/xdg/

# Config plasma theme AstroArch
cp -r /home/astronaut/.astroarch/configs/look-and-feel/astroarch /usr/share/plasma/look-and-feel/
cp -r /home/astronaut/.astroarch/configs/layout-templates/astroarchPanel /usr/share/plasma/layout-templates/

# Disable Kwallet by default
su astronaut -c "echo $'[Wallet]\nEnabled=false' > /home/astronaut/.config/kwalletrc"

# Increases the xrdp buffer
sudo sed -i 's|#tcp_send_buffer_bytes=32768|tcp_send_buffer_bytes= 4194304|g' /etc/xrdp/xrdp.ini

# Modprobe brcmfmac
bash -c "echo \"options brcmfmac feature_disable=0x282000\" > /etc/modprobe.d/brcmfmac.conf"

# Override cmdline.txt (Only on QEMU)
if [ "$HAS_VIRT" -eq 1 ]; then
    echo "root=UUID=$(blkid -s UUID -o value /dev/vda2) rw rootwait console=tty1 fsck.repair=yes video=HDMI-A-1:1920x1080M@60D" > /boot/cmdline.txt
fi

# Reboot and enjoy now, if QEMU stop and add indexes
if [ "$HAS_VIRT" -eq 0 ]; then
    reboot
else
    echo "Astroarchization achieved, now it's your turn"
fi
