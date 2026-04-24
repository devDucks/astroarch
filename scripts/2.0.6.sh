#!/usr/bin/env bash

# Add drift file for chrony
sudo sed -i '$a\driftfile /var/lib/chrony/drift' /etc/chrony.conf

# Xrdp
#Set AutoAddDevices to disabled to avoid device management conflicts between different sessions
sudo sed -i -E '/AutoAddDevices/ s/^([[:space:]]*)#/\1/' /etc/X11/xrdp/xorg.conf
# Disables the display's power management features
sudo sed -i 's/Option "DPMS"/& "false"/' /etc/X11/xrdp/xorg.conf
# Disabling compression can speed up local connections on low-power devices
sudo sed -i 's|bitmap_compression=true|bitmap_compression=false|g' /etc/xrdp/xrdp.ini
sudo sed -i 's|bulk_compression=true|bulk_compression=false|g' /etc/xrdp/xrdp.ini
# Improve xrdp & network
sudo cp /home/astronaut/.astroarch/configs/99-sysctl.conf /etc/sysctl.d

# NetworkManager WiFi Power Saving
sudo ln -s /home/astronaut/.astroarch/configs/default-wifi-powersave-off.conf /etc/NetworkManager/conf.d

# Add base-devel and rsync package
sudo pacman -Sy base-devel rsync --noconfirm

## Add the kiosk session ##
USERNAME="astronaut-kiosk"
if ! id "$USERNAME" &>/dev/null; then
# Add user astronaut-kiosk
sudo useradd -G wheel -m astronaut-kiosk
echo "astronaut-kiosk:astro" | sudo chpasswd
sudo usermod -aG uucp,sys,network,power,audio,input,lp,storage,video,users,astronaut astronaut-kiosk
sudo usermod -aG astronaut-kiosk astronaut
sudo chmod -R 770 /home/astronaut-kiosk
sudo -u astronaut-kiosk  LC_ALL=C.UTF-8 xdg-user-dirs-update --force
sudo mkdir -p /home/astronaut-kiosk/.local/{bin,share,state}

# New Xrdp launcher for astronaut and astronaut-kiosk sessions
sudo cp /home/astronaut/.astroarch/configs/kiosk/45-allow-shutdown-xrdp.rules /etc/polkit-1/rules.d/
sudo cp /home/astronaut/.astroarch/configs/startwm.sh /home/astronaut-kiosk/
sudo cp /home/astronaut/.astroarch/configs/kiosk/.xinitrc /home/astronaut-kiosk/

# Copy wallpapers
sudo -u astronaut-kiosk mkdir -p /home/astronaut-kiosk/Pictures/wallpapers
sudo cp /home/astronaut/.astroarch/configs/kiosk/astroarch-kiosk.png /home/astronaut-kiosk/Pictures/wallpapers/

# Config plasma
sudo cp /home/astronaut/.astroarch/configs/kiosk/00-init-layout.sh /home/astronaut-kiosk/.local/bin/

# Add menu
sudo cp -r /home/astronaut/.astroarch/configs/kiosk/menus /home/astronaut-kiosk/.config/

# Adjusting user rights for group access
sudo chmod -R 770 /home/astronaut-kiosk
sudo chown -R astronaut-kiosk:astronaut-kiosk /home/astronaut-kiosk
sudo chmod -R 770 /home/astronaut

# Minimal desktop
sudo ln -snf /home/astronaut/.astroarch/desktop/astroarch-config-kiosk.desktop /home/astronaut-kiosk/Desktop/
sudo ln -snf /home/astronaut/.astroarch/desktop/org.kde.konsole.desktop /home/astronaut-kiosk/Desktop/Konsole

fi

