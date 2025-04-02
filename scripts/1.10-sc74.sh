#!/usr/bin/env bash

# clone git repo sc74
mkdir -p /home/astronaut/.astroarch/sc74
cd /home/astronaut/.astroarch/sc74
git clone -b 1.10 --single-branch https://github.com/sc74/astroarch.git /home/astronaut/.astroarch/sc74

# Update files for the driver vc4-kms-v3d #106
sudo cp /home/astronaut/.astroarch/sc74/configs/cmdline.txt /boot
sudo cp /home/astronaut/.astroarch/sc74/configs/config.txt /boot
sudo cp /home/astronaut/.astroarch/sc74/configs/xorg.conf /etc/X11/
sudo cp /home/astronaut/.astroarch/sc74/configs/99-v3d.conf /etc/X11/xorg.conf.d
sudo cp /home/astronaut/.astroarch/sc74/configs/kwinrc /home/astronaut/.config

# Delete repo sc74
sudo rm -Rf /home/astronaut/.astroarch/sc74

# DisableDownloadTimeout in pacman.conf
if [ $(grep -c DisableDownloadTimeout /etc/pacman.conf) -eq 0 ]; then
    sudo sed -i '/ParallelDownloads=5/aDisableDownloadTimeout' /etc/pacman.conf
fi

# Add some packages
sudo pacman -S spectacle nano

# Printer
sudo pacman -S cups cups-pdf
sudo systemctl enable cups.service

# Set local Hostname resolution
sudo pacman -S nss-mdns
sudo sed -i 's|hosts: mymachines |&mdns_minimal [NOTFOUND=return] |g' /etc/nsswitch.conf

########################################################################################
# This section allows you to install some packages from a GitHub repo. If the packages are on your site with a repo, install the packages in the packages section. Then copy the services to /etc/systemd/system and enable them

# Onboarding

# Repository sc74.github.io
git clone https://github.com/sc74/sc74.github.io.git /home/astronaut/.astroarch/sc74.github.io
sudo sed -i 's|\[astromatto\]|\[sc74\]\nSigLevel = Optional TrustAll\nServer = file:///home/astronaut/.astroarch/sc74.github.io/aarch64\n\n\[astromatto\]|' /etc/pacman.conf
yes | LC_ALL=en_US.UTF-8 sudo pacman -Syu --noconfirm
# Install package astroarch-onboarding
yes | LC_ALL=en_US.UTF-8 sudo pacman -S astroarch-onboarding --noconfirm --ask 4
sudo cp /home/astronaut/.astroarch/build-astroarch/systemd/astroarch-onboarding.service /etc/systemd/system/
sudo systemctl enable astroarch-onboarding.service

# Install some packages
sudo pacman -S rustdesk-bin indi-pylibcamera libcamera-rpi python-libcamera-rpi libcamera-ipa-rpi libcamera-docs-rpi libcamera-tools-rpi  \
		gst-plugin-libcamera-rpi python-pycamera2 rpicam-apps --noconfirm --ask 4
# Delete repo sc74
sudo sed -i -e '/\[sc74\]/,+2d' /etc/pacman.conf


# delete repo sc74.github.io
sudo rm -Rf /home/astronaut/.astroarch/sc74.github.io

########################################################################################

echo "Reboot system now"
read -p "Press enter to continue"
reboot
