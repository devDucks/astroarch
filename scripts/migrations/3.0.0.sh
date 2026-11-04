#!/usr/bin/env bash

# The migrations of AstroArch, run by astroarch-updates: every script here that has not
# completed yet runs once, in version order (astroarch-updates status lists the runs).
# A script does not call the one before it, and is written so that it can run again
# without harm: on a system that starts using astroarch-updates, the scripts here that it
# already applied (through scripts/<version>.sh) run once more.
# This one is scripts/3.0.0.sh without its call to 2.0.11.sh: a system on 3.0.0 has run it.

# A login session for the kiosk user, so that password windows open in the kiosk. The
# image build and the Wayland migration add it; this is for systems already on Wayland
if id astronaut-kiosk > /dev/null 2>&1 && [ -z "$(pacman -Qq plasma-x11-session 2> /dev/null)" ]; then
    sudo install -m644 /home/astronaut/.astroarch/systemd/astroarch-kiosk-login.service /etc/systemd/system/
    sudo systemctl enable --now astroarch-kiosk-login.service
fi

# Network and disk tuning (BBR with fq, larger TCP receive buffers, larger write cache)
sudo install -m644 /home/astronaut/.astroarch/configs/99-sysctl.conf /etc/sysctl.d/99-sysctl.conf
sudo sysctl --system > /dev/null

# The back end of the Control Center's Kiosk page (helper, polkit action and rule,
# PHD2 sync and settings-read units). The image build and the Wayland migration run it;
# this is for systems already on Wayland
if id astronaut-kiosk > /dev/null 2>&1 && [ -z "$(pacman -Qq plasma-x11-session 2> /dev/null)" ]; then
    sudo bash /home/astronaut/.astroarch/scripts/install-kiosk-setup.sh
fi
