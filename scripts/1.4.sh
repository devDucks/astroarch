#!/usr/bin/env bash

# Check for rsync installation
check_rsync=$(pacman -Q | grep -c ^rsync\ .*)
if [ $check_rsync -lt 0 ]; then
    sudo pacman -S rsync --noconfirm
    echo "rsync installed"
fi

# Copy first time or Update if there are new/different icons
sudo rsync -avz --ignore-existing --checksum /home/astronaut/.astroarch/assets/icons/* /usr/share/webapps/novnc/app/images/icons/
