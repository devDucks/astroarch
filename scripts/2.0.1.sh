#!/usr/bin/env bash

# First run 2.0.sh to be sure that old changes will be applied
bash /home/astronaut/.astroarch/scripts/2.0.sh

check_cmdline=$(cat /boot/cmdline.txt | grep -c serial0)

if [ $check_cmdline -eq 1 ]; then
    echo "===================="
    echo "Fixing serial device mounting"
    sudo cp ~/.astroarch/configs/cmdline.txt /boot/cmdline.txt
    sudo cp ~/.astroarch/configs/config.txt /boot/config.txt
    echo "Fixed"
    echo "===================="
fi

sudo pacman -Sy jq --noconfirm

# Update xorg.conf following updates (vnc)
sudo cp /home/astronaut/.astroarch/configs/xorg.conf /etc/X11/
