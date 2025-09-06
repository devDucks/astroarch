#!/usr/bin/env bash

bash /home/astronaut/.astroarch/scripts/2.0.2.sh

# Enable X11Forwarding in ssh
sudo sed -i -E 's/^[#]?X11Forwarding.*/X11Forwarding yes/' /etc/ssh/sshd_config

# Xrdp
paru -Sy xrdp xorgxrdp --noconfirm
chmod +x /home/astronaut/.astroarch/configs/startwm.sh
sudo mv /etc/xrdp/startwm.sh /etc/xrdp/startwm.sh-old
sudo ln -sfn /home/astronaut/.astroarch/configs/startwm.sh /etc/xrdp/startwm.sh
sudo ln -sfn /home/astronaut/.astroarch/configs/Xwrapper.config /etc/xrdp/Xwrapper.config
sudo cp /home/astronaut/.astroarch/configs/50-udiskie.rules /etc/polkit-1/rules.d/50-udiskie.rules
sudo cp /home/astronaut/.astroarch/configs/50-networkmanager.rules /etc/polkit-1/rules.d/50-networkmanager.rules
sudo systemctl enable --now xrdp xrdp-sesman

# Disable do not disturb mode
if [ ! -f /home/astronaut/.config/plasmanotifyrc ]; then
cat <<EOF >/home/astronaut/.config/plasmanotifyrc
[DoNotDisturb]
WhenFullscreen=false
WhenScreensMirrored=false
EOF
else
sed -i '$a\\[DoNotDisturb]\nWhenFullscreen=false\nWhenScreensMirrored=false' /home/astronaut/.config/plasmanotifyrc
fi



