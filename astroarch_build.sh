# Exit on the first error, if any
set -e

# Grab the OS architecture for further forked logic
ARCH=$(uname -m)

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
su astronaut -c "git clone https://github.com/devDucks/astroarch.git /home/astronaut/.astroarch"

# Uncomment en_US UTF8 and generate locale files
sed -i -e 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen

pacman -Syu base-devel pipewire-jack gnu-free-fonts wireplumber \
        zsh plasma-desktop sddm networkmanager xf86-video-dummy \
	network-manager-applet networkmanager-qt5 chromium xorg konsole \
	gpsd breeze-icons hicolor-icon-theme knewstuff5 tigervnc \
	knotifyconfig5 kplotting5 qt5-datavis3d qt5-quickcontrols \
	qt5-websockets qtkeychain stellarsolver xf86-video-fbdev \
	xplanet plasma-nm dhcp dnsmasq kate plasma-systemmonitor \
	dolphin uboot-tools usbutils cloud-guest-utils samba paru \
	websockify novnc astrometry.net gsc kstars phd2 packagekit-qt5 \
	indi-3rdparty-libs indi-3rdparty-drivers linux-rpi linux-rpi-headers \
	i2c-tools indiserver-ui astro_dmx openssl-1.1 firefox chrony \
	ksystemlog discover kwalletmanager kgpg qt5-serialbus \
	qt5-serialport qt5ct udisks2-qt5 xorg-fonts-misc fuse2 \
	fortune-mod cowsay pacman-contrib arandr neofetch \
	astromonitor kscreen sddm-kcm flatpak ckbcomp astroarch-onboarding kdialog --noconfirm --ask 4

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
chown astronaut:astronaut .oh-my-zsh/

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
ln -s /home/astronaut/.astroarch/systemd/astroarch-onboarding.service /etc/systemd/system/astroarch-onboarding.service

# Copy xorg config
cp /home/astronaut/.astroarch/configs/xorg.conf /etc/X11/

# Copy v3d X config
cp /home/astronaut/.astroarch/configs/99-v3d.conf /etc/X11/xorg.conf.d

# Copy the polkit script to allow rebooting, shutting down with no errors
cp /home/astronaut/.astroarch/configs/99-polkit-power.rules /etc/polkit-1/rules.d/

# Copy the systemd unit to create the AP the first boot
cp /home/astronaut/.astroarch/systemd/create_ap.service /etc/systemd/system/

# Enable vncserver
systemctl enable x0vncserver

# Copy the config for kwinrc
su astronaut -c "cp /home/astronaut/.astroarch/configs/kwinrc /home/astronaut/.config"

# Enable now all services
systemctl enable sddm.service novnc.service dhcpcd.service NetworkManager.service avahi-daemon.service nmb.service smb.service

# Take sudoers to the original state
sed -i 's/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers

# Copy wallpapers
su astronaut -c "cp /home/astronaut/.astroarch/wallpapers/bubble.jpg /home/astronaut/Pictures/wallpapers"
su astronaut -c "cp /home/astronaut/.astroarch/wallpapers/south-milky.jpg /home/astronaut/Pictures/wallpapers"
su astronaut -c "cp /home/astronaut/.astroarch/wallpapers/pacman.jpg /home/astronaut/Pictures/wallpapers"

# Copy desktop icons
su astronaut -c "ln -s /usr/share/applications/org.kde.konsole.desktop /home/astronaut/Desktop/Konsole"
su astronaut -c "ln -s /usr/share/applications/org.kde.kstars.desktop /home/astronaut/Desktop/Kstars"
su astronaut -c "ln -s /usr/share/applications/astrodmx_capture.desktop /home/astronaut/Desktop/AstroDMx_capture"

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
sed -i 's/max_framebuffers=2/max_framebuffers=2\nframebuffer_depth=24/g' /boot/config.txt
sed -i 's/dtoverlay=vc4-kms-v3d/dtoverlay=vc4-kms-v3d,cma-512/g' /boot/config.txt
echo dtparam=i2c_arm=on >> /boot/config.txt
echo dtparam=audio=on >> /boot/config.txt
echo disable_overscan=1 >> /boot/config.txt
echo gpu_mem=256 >> /boot/config.txt
echo 3dtparam=krnbt=on >> /boot/config.txt
echo dtoverlay=i2c-rtc >> /boot/config.txt
echo kernel=kernel8.img >> /boot/config.txt
echo hdmi_enable_4kp60=1 >> /boot/config.tx
echo i2c-dev > /etc/modules-load.d/raspberrypi.conf

# Pi5 only settings should go here
echo [pi5] >> /boot/config.txt
echo dtparam=rtc_bbat_vchg=3000000 >> /boot/config.txt

# Disable Kwallet by default
su astronaut -c "echo $'[Wallet]\nEnabled=false' > /home/astronaut/.config/kwalletrc"

# Reboot and enjoy now
reboot
