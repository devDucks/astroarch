# Exit on the first error, if any
set -e

# try to identify the platform TODO: IF pieces that may differ depending on the platform
raspi=$(cat /proc/cpuinfo | grep -c Raspberry)

# Parallelize pacman download to 5 and use pacman as progress bar
sed -i 's|#ParallelDownloads = 5|ParallelDownloads=5\nILoveCandy\n|g' /etc/pacman.conf

# Add astroarch pacman repo to pacman.conf (it must go first)
sed -i 's|\[core\]|\[astromatto\]\nSigLevel = Optional TrustAll\nServer = http://astroarch.astromatto.com:9000/$arch\n\n\[core\]|' /etc/pacman.conf

# Bootstrap pacman-key
pacman-key --init && pacman-key --populate archlinuxarm

# Update all packages now
pacman -Syu --noconfirm

# Install just 2 packages for the next actions
pacman -S wget sudo git --noconfirm

# create user astro with home, add it to wheel
useradd -G wheel -m astronaut
echo "astronaut:astro" | chpasswd

# Pull the brain repo, this will be used for scripting out the final image
su astronaut -c "git clone https://github.com/MattBlack85/astroarch.git /home/astronaut/.astroarch"

# Uncomment en_US UTF8 and generate locale files
sed -i -e 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen

pacman -Syu base-devel pipewire-jack gnu-free-fonts pipewire-media-session \
        zsh plasma-desktop sddm networkmanager xf86-video-dummy \
	network-manager-applet networkmanager-qt5 chromium xorg konsole \
	gpsd breeze-icons hicolor-icon-theme knewstuff5 tigervnc \
	knotifyconfig5 kplotting5 qt5-datavis3d qt5-quickcontrols \
	qt5-websockets qtkeychain stellarsolver xf86-video-fbdev \
	xplanet plasma-nm dhcp dnsmasq kate plasma-systemmonitor \
	dolphin uboot-tools usbutils cloud-guest-utils samba paru \
	websockify novnc astrometry.net gsc kstars phd2 \
	indi-3rdparty-libs indi-3rdparty-drivers linux-rpi linux-rpi-headers \
	i2c-tools indiserver-ui astro_dmx openssl-1.1 firefox chrony \
	fortune-mod cowsay pacman-contrib arandr neofetch --noconfirm --ask 4

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

# install oh-my-zsh and set the default shell to zsh
chsh -s /usr/bin/zsh astronaut
rm /home/astronaut/.bash*
cd /home/astronaut
ZSH=/home/astronaut/.oh-my-zsh sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
chown astronaut:astronaut .oh-my-zsh/

# Set the samba pass
ln -s /home/astronaut/.astroarch/configs/smb.conf /etc/samba/smb.conf
systemctl start smb
(echo astro; echo astro) | smbpasswd -s -a astronaut
systemctl stop smb

# Link a zsh config for astronaut
ln -s /home/astronaut/.astroarch/configs/.zshrc /home/astronaut/.zshrc

# prepare folder for user services
su astronaut -c "mkdir -p /home/astronaut/.config/systemd/user/default.target.wants"

# make a dir to store sddm config
mkdir /etc/sddm.conf.d

# Start NetworkManager and sleep to create the hotspot
systemctl start NetworkManager
sleep 5

# Create the hotspot and set autoconnect to true
nmcli device wifi hotspot ifname wlan0 ssid AstroArch password "astronomy"
nmcli connection modify Hotspot connection.autoconnect-priority -100
nmcli connection modify Hotspot connection.autoconnect true

# Create Xauthority for x11vnc
su astronaut -c "touch /home/astronaut/.Xauthority"

# Remove eventually existing systemd configs we are going to substitute
rm /usr/lib/systemd/system/novnc.service

# Disable systemd-timesyncd and enable ntp
systemctl disable systemd-timesyncd
systemctl enable chronyd

# Symlink now files
ln -s /home/astronaut/.astroarch/configs/kde_settings.conf /etc/sddm.conf.d/kde_settings.conf
ln -s /home/astronaut/.astroarch/systemd/novnc.service /usr/lib/systemd/system/novnc.service
ln -s /home/astronaut/.astroarch/systemd/x0vncserver.service /etc/systemd/system/x0vncserver.service
ln -s /home/astronaut/.astroarch/configs/20-headless.conf /usr/share/X11/xorg.conf.d/20-headless.conf
ln -s /home/astronaut/.astroarch/systemd/resize_once.service /etc/systemd/system/resize_once.service
ln -s /home/astronaut/.astroarch/configs/.astroarch.version /home/astronaut/.astroarch.version
ln -s /home/astronaut/.astroarch/configs/99-polkit-power.rules /etc/polkit-1/rules.d/99-polkit-power.rules

# Set vncpassword
vncpasswd astro

# Enable oneshot script to set the bubble nebula wallpaper
su astronaut -c "cp /home/astronaut/.astroarch/systemd/change_wallpaper_once.service /home/astronaut/.config/systemd/user"
su astronaut -c "ln -s /home/astronaut/.config/systemd/user/change_wallpaper_once.service /home/astronaut/.config/systemd/user/default.target.wants/change_wallpaper_once.service"

# Copy the config for kwinrc
su astronaut -c "cp /home/astronaut/.astroarch/configs/kwinrc /home/astronaut/.config"

# Enable now all services
systemctl enable sddm.service novnc.service dhcpcd.service NetworkManager.service avahi-daemon.service nmb.service smb.service systemd-timesyncd.service

# Take sudoers to the original state
sed -i 's/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers

# Link wallpaper
su astronaut -c "mkdir -p /home/astronaut/Pictures"
su astronaut -c "cp /home/astronaut/.astroarch/wallpapers/bubble.jpg /home/astronaut/Pictures/bubble.jpg"

# Copy desktop icons
su astronaut -c "mkdir -p /home/astronaut/Desktop"
su astronaut -c "cp /home/astronaut/.astroarch/desktop/org.kde.konsole.desktop /home/astronaut/Desktop"
su astronaut -c "cp /home/astronaut/.astroarch/desktop/org.kde.kstars.desktop /home/astronaut/Desktop"
su astronaut -c "cp /home/astronaut/.astroarch/desktop/phd2.desktop /home/astronaut/Desktop"
su astronaut -c "ln -s /usr/share/applications/astrodmx_capture.desktop /home/astronaut/Desktop/AstroDMx_capture"

# Make the icons executable so there will be no ! on the first boot
chmod +x /home/astronaut/Desktop/*

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

# If we are on a raspberry let's adjust /boot/config.txt
if [ $raspi -eq 1 ]; then
    echo dtparam=i2c_arm=on >> /boot/config.txt
    echo dtparam=audio=on >> /boot/config.txt
    echo display_auto_detect=1 >> /boot/config.txt
    echo dtoverlay=vc4-kms-v3d >> /boot/config.txt
    echo max_framebuffers=2 >> /boot/config.txt
    echo disable_overscan=1 >> /boot/config.txt
    echo otg_mode=1 >> /boot/config.txt
    echo arm_boost=1 >> /boot/config.txt
    echo gpu_mem=256 >> /boot/config.txt
    echo disable_splash=1 >> /boot/config.txt
    echo 3dtparam=krnbt=on >> /boot/config.txt
    echo hdmi_drive=2 >> /boot/config.txt
    echo dtoverlay=i2c-rtc >> /boot/config.txt
    echo i2c-dev > /etc/modules-load.d/raspberrypi.conf
fi

# Disable Kwallet by default
su astronaut -c "echo $'[Wallet]\nEnabled=false' > /home/astronaut/.config/kwalletrc"

# Reboot and enjoy now
reboot
