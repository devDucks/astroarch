#!/usr/bin/env bash

# First run 1.6.sh to be sure that old changes will be applied
bash /home/astronaut/.astroarch/scripts/1.6.sh

# Now apply the patches for 1.7
check_kate=$(pacman -Q | grep -c kate)

if [ $check_kate -eq 0 ]; then
    echo "===================="
    echo "Kate not found... Installing"
    sudo pacman -S kate --noconfirm
    echo "Kate installed"
    echo"===================="

    check_gedit=$(pacman -Q | grep -c gedit)
    if [ $check_gedit -eq 1 ]; then
	echo "===================="
	echo "Found gedit, removing..."
	sudo pacman -Rcs gedit --noconfirm
	echo "gedit removed"
	echo "===================="
    fi
fi

check_ntp=$(pacman -Q | grep -c ntp)
if [ $check_ntp -eq 0 ]; then
    echo "===================="
    echo "NTP not found, installing..."
    echo "Disabling tymesyncd"
    sudo systemctl disable --now systemd-timesyncd
    echo "Installing NTP..."
    sudo pacman -S ntp --noconfirm
    sudo systemctl enable --now ntpd
    echo "NTP installed and enabled"
    echo "===================="
fi

check_arandr=$(pacman -Q | grep -c arandr)
if [ $check_arandr -eq 0 ]; then
    echo "===================="
    echo "Installing arandr!"
    sudo pacman -S arandr --noconfirm
    echo "Arandr installed"
    echo "===================="
fi

check_neofetch=$(pacman -Q | grep -c neofetch)
if [ $check_neofetch -eq 0 ]; then
    echo "===================="
    echo "Installing neofetch!"
    sudo pacman -S neofetch --noconfirm
    echo "neofetch installed"
    echo "===================="
fi

check_pacman_contrib=$(pacman -Q | grep -c pacman-contrib)
if [ $check_pacman_contrib -eq 0 ]; then
    echo "===================="
    echo "Installing pacman-contrib!"
    sudo pacman -S pacman-contrib --noconfirm
    echo "pacman-contrib installed"
    echo "===================="
fi

check_kwallet=$(ls /home/astronaut/.config | grep -c kwalletrc)
if [ $check_kwallet -eq 0 ]; then
    echo "===================="
    echo "Disabling kwallet!"
    echo $'[Wallet]\nEnabled=false' > /home/astronaut/.config/kwalletrc
    echo "Kwallet disabled!"
    echo "===================="
fi
