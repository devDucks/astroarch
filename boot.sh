# Parallelize pacman download to 5
sed -i 's/#ParallelDownloads = 5/ParallelDownloads=5/g' /etc/pacman.conf

# Add astroarch pacman repo to pacman.conf (it must go first)
sed -i 's|\[core\]|\[astroarch\]\nSigLevel = Optional TrustAll\nServer = http://astroarch.astromatto.com:9000/$arch\n\n\[core\]|' /etc/pacman.conf

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

pacman -Syu base-devel go zsh plasma-desktop sddm networkmanager xf86-video-dummy \
	network-manager-applet networkmanager-qt chromium xorg alacritty \
	gpsd breeze-icons hicolor-icon-theme knewstuff linux-rpi linux-rpi-headers \
	knotifyconfig kplotting qt5-datavis3d qt5-quickcontrols \
	qt5-websockets qtkeychain stellarsolver xf86-video-fbdev \
	inetutils xplanet plasma-nm dhcp dnsmasq x11vnc gedit \
	dolphin uboot-tools usbutils cloud-guest-utils samba yay \
	python-numpy websockify novnc astrometry.net gsc \
	python-astropy python-extension-helpers \
	python-pyerfa python-sphinx-automodapi kstars phd2 \
	indi-3rdparty-libs indi-3rdparty-drivers --noconfirm --ask 4

# Allow wheelers to sudo without password to install packages
sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers

# Add astronaut to uucp for serial device ownership
usermod -aG uucp astronaut

# Run now the build script
bash /home/astronaut/.astroarch/build.sh
