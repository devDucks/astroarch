#!/usr/bin/env bash

# Invoke 2.0.9
bash /home/astronaut/.astroarch/scripts/2.0.9.sh

# Install astroarch-bridge for the astronaut and astronaut-kiosk users
sudo pacman -Sy astroarch-bridge --noconfirm

# Pre-launch of the Kiosk session
sudo sed -i '1s/^/auth sufficient pam_succeed_if.so user = astronaut-kiosk\n/' /etc/pam.d/xrdp-sesman
sudo cp -f /home/astronaut/.astroarch/systemd/xrdp-autostart-kiosk.service /etc/systemd/system/xrdp-autostart-kiosk.service
sudo ln -sf /etc/systemd/system/xrdp-autostart-kiosk.service /etc/systemd/system/multi-user.target.wants/xrdp-autostart-kiosk.service
sudo systemctl enable xrdp-autostart-kiosk.service
