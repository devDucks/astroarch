#!/usr/bin/env bash

# First run 1.9.3.sh to be sure that old changes will be applied
bash /home/astronaut/.astroarch/scripts/1.9.3.sh

# Things to do

# check pacman.conf and disable download timeout
timeout=$(cat /etc/pacman.conf | grep -c DisableDownloadTimeout)
if [ $timeout -eq 0 ]; then
    echo "===================="
    echo "Disabling downlaod timeout"
    sed -i 's|ILoveCandy|ILoveCandy\nDisableDownloadTimeout\n|g' /etc/pacman.conf
    echo "Disable"
    echo "===================="
fi

# allow astronaut to sudo with no pass
sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers

# Copy over xorg.conf
cp /home/astronaut/.astroarch/configs/xorg.conf /etc/X11/

# Copy over v3d X config
cp /home/astronaut/.astroarch/configs/99-v3d.conf /etc/X11/xorg.conf.d

# copy over config.txt (remove and cp again? This will drop changes that people did manually)

# Add kdialog, astroarch-onboarding and xbcomp
check_kdialog=$(pacman -Q | grep -c kdialog)

if [ $check_kdialog -eq 0 ]; then
    echo "===================="
    echo "Kdialog not found... Installing"
    sudo pacman -Sy kdialog --noconfirm
    echo "Kdialog installed"
    echo "===================="
fi

check_ckbcomp=$(pacman -Q | grep -c ckbcomp)

if [ $check_ckbcomp -eq 0 ]; then
    echo "===================="
    echo "ckbcomp not found... Installing"
    sudo pacman -Sy ckbcomp --noconfirm
    echo "ckbcomp installed"
    echo "===================="
fi

check_aaonboard=$(pacman -Q | grep -c astroarch-onboarding)

if [ $check_aaonboard -eq 0 ]; then
    echo "===================="
    echo "astroarch-onboarding not found... Installing"
    sudo pacman -Sy astroarch-onboarding --noconfirm
    echo "astroarch-onboarding installed"
    echo "===================="
fi
