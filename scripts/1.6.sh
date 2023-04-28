#!/usr/bin/env bash

# First run 1.5.sh to be sure that old changes will be applied
bash /home/astronaut/.astroarch/scripts/1.5.sh

# Now apply the patches for 1.6
check_indiui=$(pacman -Q | grep -c indiserver-ui)

if [ $check_indiui -eq 0 ]; then
    sudo pacman -S indiserver-ui --noconfirm
        echo "indiserver-ui installed"
fi

check_astrodmx=$(pacman -Q | grep -c astro_dmx)

if [ $astrodmx -eq 0 ]; then
    sudo pacman -S astro_dmx --noconfirm
    echo "AstroDMx installed"
    ln -s /usr/share/applications/astrodmx_capture.desktop /home/astronaut/Desktop/AstroDMx_capture
fi
