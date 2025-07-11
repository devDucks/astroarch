#!/usr/bin/env bash

# First run 1.9.3.sh to be sure that old changes will be applied
bash /home/astronaut/.astroarch/scripts/1.9.3.sh

# Fix the pesky problem with linux-firmware
sudo pacman -Rdd linux-firmware --noconfirm && sudo pacman -Sy linux-firmware --noconfirm

if [ ! -f /home/astronaut/Desktop/update-astroarch.desktop ]; then
    echo "===================="
    echo "Update astroarch script not found... Installing"
    cp /home/astronaut/.astroarch/desktop/update-astroarch.desktop /home/astronaut/Desktop/
    sudo chmod +x /home/astronaut/Desktop/update-astroarch.desktop
    echo "Update AstroArch script installed"
    echo "===================="
fi

check_plasmasess=$(pacman -Q | grep -c plasma-x11-session)

if [ $check_plasmasess -eq 0 ]; then
    echo "===================="
    echo "Plasma x11 session not found... Installing"
    sudo pacman -Sy plasma-x11-session --noconfirm
    echo "Plasma x11 session  installed"
    echo "===================="
fi

# Copy the new version of 99-v3d new config files
sudo cp /home/astronaut/.astroarch/configs/99-v3d.conf /etc/X11/xorg.conf.d
sudo cp /home/astronaut/.astroarch/configs/xorg.conf /etc/X11/
sudo cp /home/astronaut/.astroarch/configs/config.txt /boot/config.txt
# The following is a one time thing! By defaukt it will be put in the base image at build time
sudo cp /home/astronaut/.astroarch/configs/cmdline.txt /boot/cmdline.txt

if [ ! -f /home/astronaut/Desktop/astroarch-tweak-tool.deskop ]; then
    echo "===================="
    echo "AstroArch Tweak Tool script not found... Installing"
    cp /home/astronaut/.astroarch/desktop/astroarch-tweak-tool.desktop /home/astronaut/Desktop/
    sudo chmod +x /home/astronaut/Desktop/astroarch-tweak-tool.desktop
    sudo pacman -Sy kdialog --noconfirm
    echo "AstroArch Tweak Tool installed"
    echo "===================="
fi

sudo sed -i 's|ILoveCandy|ILoveCandy\nDisableDownloadTimeout\n|g' /etc/pacman.conf
