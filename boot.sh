#TODO here, parallelize pacman downloads
sed -i 's/#ParallelDownloads = 5/ParallelDownloads=5/g' /etc/pacman.conf
pacman-key --init && pacman-key --populate archlinuxarm
pacman -Syu --noconfirm
pacman -S wget sudo git --noconfirm

# create user astro with home, add it to wheel
useradd -G wheel -m astronaut
passwd astronaut

su astronaut -c "git clone https://github.com/MattBlack85/astroarch.git /home/astronaut/.astroarch"

pacman -Syu base-devel go zsh plasma-desktop sddm networkmanager xf86-video-dummy \
       network-manager-applet networkmanager-qt chromium xorg alacritty \
       cmake cfitsio fftw gsl libjpeg-turbo libnova libtheora libusb boost \
       libraw libgphoto2 libftdi libdc1394 libavc1394 \
       ffmpeg gpsd breeze-icons hicolor-icon-theme knewstuff \
       knotifyconfig kplotting qt5-datavis3d qt5-quickcontrols \
       qt5-websockets qtkeychain stellarsolver xf86-video-fbdev \
       extra-cmake-modules kf5 eigen inetutils xplanet plasma-nm \
       dhcp dnsmasq --noconfirm

# Allow wheelers to sudo
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers

# Run now the build script
bash /home/astronaut/.astroarch/build.sh
