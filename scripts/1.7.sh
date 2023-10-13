#!/usr/bin/env bash

# First run 1.6.sh to be sure that old changes will be applied
bash /home/astronaut/.astroarch/scripts/1.6.sh

# Now apply the patches for 1.7
check_kate=$(pacman -Q | grep -c kate)

if [ $check_kate -eq 0 ]; then
    echo "====================\nKate not found... Installing"
    sudo pacman -S kate --noconfirm
    echo "Kate installed\n===================="

    check_gedit=$(pacman -Q | grep -c gedit)
    if [ $check_gedit -eq 1 ]; then
	echo "====================\nFound gedit, removing..."
	sudo pacman -Rcs gedit --noconfirm
	echo "gedit removed\n===================="
    fi
fi

check_ntp=$(pacman -Q | grep -c ntp)
if [ $check_ntp -eq 0 ]; then
    echo "====================\nNTP not found"
    echo "Disabling tymesyncd"
    sudo systemctl disable --now systemd-timesyncd
    echo "Installing NTP..."
    sudo pacman -S ntp --noconfirm
    sudo systemctl enable --now ntpd
    echo "NTP installed and enabled\n===================="
fi

check_motd=$(ls /etc/profile.d | grep -c aa_motd)
if [ $check_motd -eq 0 ]; then
    echo "====================\nAdding motd!"
    sudo pacman -S fortune-mod cowsay --noconfirm
    sudo ln -s /home/astronaut/.astroarch/scripts/aa_motd.sh /etc/profile.d/aa_motd.sh
    echo "MOTD added, hope you like it!"
fi

check_arandr=$(pacman -Q | grep -c arandr)
if [ $check_arandr -eq 0 ]; then
    echo "====================\nInstalling arandr!"
    sudo pacman -S arandr --noconfirm
    echo "Arandr installed\n===================="
fi
