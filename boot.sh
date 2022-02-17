# Parallelize pacman download to 5
sed -i 's/#ParallelDownloads = 5/ParallelDownloads=5/g' /etc/pacman.conf

# Add astroarch pacman repo to pacman.conf
cat <<EOF >> /etc/pacman.conf
[astroarch]
SigLevel = Optional TrustAll
Server = http://astroarch.astromatto.com:9000/$$arch
EOF

# Bootstrap pacman-key
pacman-key --init && pacman-key --populate archlinuxarm

# Update all packages now
pacman -Syu --noconfirm

# Install just 2 packages for the next actions
pacman -S wget sudo git --noconfirm

# create user astro with home, add it to wheel
useradd -G wheel -m astronaut
passwd astronaut

# Pull the brain repo, this will be used for scripting out the final image
su astronaut -c "git clone https://github.com/MattBlack85/astroarch.git /home/astronaut/.astroarch"

pacman -Syu base-devel go zsh plasma-desktop sddm networkmanager xf86-video-dummy \
	network-manager-applet networkmanager-qt chromium xorg alacritty \
	cmake cfitsio fftw gsl libjpeg-turbo libnova libtheora libusb boost \
	libraw libgphoto2 libftdi libdc1394 libavc1394 \
	ffmpeg gpsd breeze-icons hicolor-icon-theme knewstuff \
	knotifyconfig kplotting qt5-datavis3d qt5-quickcontrols \
	qt5-websockets qtkeychain stellarsolver xf86-video-fbdev \
	extra-cmake-modules kf5 eigen inetutils xplanet plasma-nm \
	dhcp dnsmasq x11vnc gedit dolphin uboot-tools usbtools \
	cloud-guest-utils samba yay --noconfirm

# Allow wheelers to sudo without password to install packages
sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers

# Run now the build script
bash /home/astronaut/.astroarch/build.sh
