#!/usr/bin/env bash

# Enable X11Forwarding in ssh
sudo sed -i 's/#X11Forwarding no/X11Forwarding yes/g' /etc/ssh/sshd_config

# Xrdp
paru -Sy xrdp xorgxrdp --noconfirm
chmod +x /home/astronaut/.astroarch/configs/startwm.sh
sudo mv /etc/xrdp/startwm.sh /etc/xrdp/startwm.sh-old
sudo ln -s /home/astronaut/.astroarch/configs/startwm.sh /etc/xrdp/startwm.sh
sudo systemctl enable xrdp
sudo systemctl enable xrdp-sesman
sudo systemctl start xrdp
sudo systemctl start xrdp-sesman


