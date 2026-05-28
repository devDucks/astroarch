#!/usr/bin/env bash

# Invoke 2.0.8
bash /home/astronaut/.astroarch/scripts/2.0.8.sh

# Backup packages
sudo pacman -Sy rsync fakeroot --noconfirm

# Prevents XRDP from creating a second virtual desktop for the same user
sudo sed -i 's/^Policy=.*/Policy=UHQ/' /etc/xrdp/sesman.ini
sudo sed -i '/^\[Xorg\]/a fork=true' /etc/xrdp/xrdp.ini

# XRDP Turn off compression
sudo awk '1; /^tcp_keepalive=true$/ {print "\n; Turn off compression\nrfx_codec=false\njpeg_codec=false"}' /etc/xrdp/xrdp.ini > /tmp/xrdp.ini.tmp && sudo mv /tmp/xrdp.ini.tmp /etc/xrdp/xrdp.ini

