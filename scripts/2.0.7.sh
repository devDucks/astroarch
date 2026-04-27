#!/usr/bin/env bash

# Invoke 2.0.6
bash /home/astronaut/.astroarch/scripts/2.0.6.sh

# Remove if duplicate due to the execution of 2.0.5.sh & 2.0.6.sh
sudo sed -i '/driftfile \/var\/lib\/chrony\/drift/ { x; s/^$/1/; t keep; d; :keep g; }' /etc/chrony.conf
awk '!seen[$0]++ || !/refclock SHM 0 offset 0.5 delay 0.2 refid NMEA/' /etc/chrony.conf | sudo tee /etc/chrony.conf.tmp > /dev/null && sudo mv /etc/chrony.conf.tmp /etc/chrony.conf

# Removal of duplicates caused by 2.0.6.sh in /etc/X11/xrdp/xorg.conf
sudo sed -i 's/^\([[:space:]]*Option[[:space:]]*"DPMS"\).*/\1 "false"/' /etc/X11/xrdp/xorg.conf

# If the `id` command in 2.0.6.sh didn't work, reinstall astronaut-kiosk using the `getent` command
if ! getent passwd "astronaut-kiosk" > /dev/null 2>&1; then
# Add user astronaut-kiosk
sudo useradd -G wheel -m astronaut-kiosk
echo "astronaut-kiosk:astro" | sudo chpasswd
sudo usermod -aG uucp,sys,network,power,audio,input,lp,storage,video,users,astronaut astronaut-kiosk
sudo usermod -aG astronaut-kiosk astronaut
sudo chmod -R 770 /home/astronaut-kiosk
sudo -u astronaut-kiosk LC_ALL=C.UTF-8 xdg-user-dirs-update --force
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
sudo ln -snf /home/astronaut/.astroarch/desktop/astroarch-config-kiosk.desktop /home/astronaut-kiosk/Desktop/Astroarch-config-Kiosk
sudo ln -snf /home/astronaut/.astroarch/desktop/org.kde.konsole.desktop /home/astronaut-kiosk/Desktop/Konsole

fi

