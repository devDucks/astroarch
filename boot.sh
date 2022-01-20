pacman-key --init && pacman-key --populate archlinuxarm
pacman -Syu --noconfirm
pacman -S wget sudo git --noconfirm

# create user astro with home, add it to wheel, install oh-my-zsh and set the default shell to zsh
useradd -G wheel -m astronaut
passwd astronaut

git clone https://github.com/MattBlack85/astroarch.git /home/astronaut/.astroarch

pacman -Syu base-devel go zsh lxqt sddm networkmanager xf86-video-dummy \
       networkmanager-applet networkmanager-qt chromium xorg alacritty \
       cmake cfitsio fftw gsl libjpeg-turbo libnova libtheora libusb boost \
       libraw libgphoto2 libftdi libdc1394 libavc1394 \
       ffmpeg gpsd breeze-icons hicolor-icon-theme knewstuff \
       knotifyconfig kplotting qt5-datavis3d qt5-quickcontrols \
       qt5-websockets qtkeychain stellarsolver \
       extra-cmake-modules kf5 eigen --noconfirm

# Allow wheelers to sudo
sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g' /etc/sudoers
