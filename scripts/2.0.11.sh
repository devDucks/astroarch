#!/usr/bin/env bash

# Invoke 2.0.10. It and the scripts before it set up the X11 desktop, XRDP and
# the X11 kiosk: a Wayland system (a new image, or after the migration) skips them
if [ -n "$(pacman -Qq plasma-x11-session xrdp xorgxrdp 2> /dev/null)" ]; then
    bash /home/astronaut/.astroarch/scripts/2.0.10.sh
fi

# Shared data folder for astronaut and astronaut-kiosk
sudo groupadd -f astro
sudo usermod -aG astro astronaut
id astronaut-kiosk > /dev/null 2>&1 && sudo usermod -aG astro astronaut-kiosk
sudo cp -f /home/astronaut/.astroarch/configs/astro-data.conf /etc/tmpfiles.d/astro-data.conf
sudo systemd-tmpfiles --create /etc/tmpfiles.d/astro-data.conf

# ~/astro-data symlink in both homes, leaving alone an astro-data the user
# already has. The kiosk one runs as kiosk, astronaut may not read its home
if [ ! -e /home/astronaut/astro-data ] && [ ! -L /home/astronaut/astro-data ]; then
    ln -sn /srv/astro-data /home/astronaut/astro-data
fi
if id astronaut-kiosk > /dev/null 2>&1; then
    sudo -u astronaut-kiosk bash -c '[ -e ~/astro-data ] || [ -L ~/astro-data ] || ln -sn /srv/astro-data ~/astro-data'
fi
