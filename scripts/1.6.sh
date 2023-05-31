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

if [ $check_astrodmx -eq 0 ]; then
    sudo pacman -S astro_dmx --noconfirm
    echo "AstroDMx installed"
fi

check_astromonitor=$(pacman -Q | grep -c astromonitor)

if [ $check_astromonitor -eq 0 ]; then
    sudo pacman -S astromonitor --noconfirm
    echo "astromonitor installed"
    if [ -f /usr/local/bin/astromonitor ]; then
	echo "Dropping legacy astromonitor"
	sudo rm /usr/local/bin/astromonitor
    fi
fi

check_i2c=$(pacman -Q | grep -c i2c-tools)

if [ $check_i2c -eq 0 ]; then
    sudo pacman -S i2c-tools --noconfirm
    sudo sh -c "echo i2c-dev > /etc/modules-load.d/raspberrypi.conf"
    echo "i2c-tools installed"
fi

dtcheck=$(cat /boot/config.txt | grep -c dtparam=i2c_arm=on)
dtoverlaycheck=$(cat /boot/config.txt | grep -c dtoverlay=i2c-rtc)

if [ $dtcheck -eq 0 ]; then
    sudo sh -c "echo dtparam=i2c_arm=on >> /boot/config.txt"
fi

if [ $dtoverlaycheck -eq 0 ]; then
    sudo sh -c "echo dtoverlay=i2c-rtc >> /boot/config.txt"
fi

# libssl 1.1
check_libssl=$(pacman -Q | grep -c openssl-1.1)

if [ $check_libssl -eq 0 ]; then
    sudo pacman -S openssl-1.1 --noconfirm
    echo "libssl 1.1 installed"
fi
