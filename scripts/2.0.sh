#!/usr/bin/env bash

# First run 1.9.3.sh to be sure that old changes will be applied
bash /home/astronaut/.astroarch/scripts/1.9.3.sh

if [ ! -f /home/astronaut/Desktop/update-astroarch ]; then
    echo "===================="
    echo "Update astroarch script not found... Installing"
    su astronaut -c "cp /home/astronaut/.astroarch/desktop/update-astroarch.desktop /home/astronaut/Desktop/update-astroarch"
    sudo chmod +x /home/astronaut/Desktop/update-astroarch
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

if [ ! -f /home/astronaut/Desktop/AstroArch-Tweak-Tool ]; then
    echo "===================="
    echo "AstroArch Tweak Tool script not found... Installing"
    su astronaut -c "cp /home/astronaut/.astroarch/desktop/astroarch-tweak-tool.desktop /home/astronaut/Desktop/AstroArch-Tweak-Tool"
    sudo chmod +x /home/astronaut/Desktop/AstroArch-Tweak-Tool
    echo "AstroArch Tweak Tool installed"
    echo "===================="
fi
