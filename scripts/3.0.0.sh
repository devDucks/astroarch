#!/usr/bin/env bash

# Invoke 2.0.11
bash /home/astronaut/.astroarch/scripts/2.0.11.sh

# A login session for the kiosk user, so that password windows open in the kiosk. The
# image build and the Wayland migration add it; this is for systems already on Wayland
if id astronaut-kiosk > /dev/null 2>&1 && [ -z "$(pacman -Qq plasma-x11-session 2> /dev/null)" ]; then
    sudo install -m644 /home/astronaut/.astroarch/systemd/astroarch-kiosk-login.service /etc/systemd/system/
    sudo systemctl enable --now astroarch-kiosk-login.service
fi
