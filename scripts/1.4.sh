#!/usr/bin/env bash

# Check for rsync installation
check_rsync=$(pacman -Q | grep -c rsync)
if [ $check_rsync -eq 0 ]; then
    sudo pacman -Su rsync --noconfirm
    echo "rsync installed"
fi

# Copy first time or Update if there are new/different icons
sudo rm -r /usr/share/webapps/novnc/app/images/icons/*
sudo rsync -avz --ignore-existing --checksum /home/astronaut/.astroarch/assets/icons/* /usr/share/webapps/novnc/app/images/icons/
