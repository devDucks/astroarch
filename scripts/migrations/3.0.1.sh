#!/usr/bin/env bash

# Run once by astroarch-updates, like every script here, and written so that it can run
# again without harm.
# Cleanup for systems updated from 2.0.x: the 3.0 image no longer has these (#321, #322).

# The Calamares onboarding: the AstroArch Control Center replaced it. Its launchers need
# X11 and no longer start on Wayland, and its package installs two polkit rules
# (49-nopasswd-calamares-vnc/xrdp) that let any program become root without a password.
if pacman -Qq astroarch-onboarding > /dev/null 2>&1; then
    sudo pacman -Rns --noconfirm astroarch-onboarding
fi
rm -f "$HOME/Desktop/AstroArch-onboarding"

# Root login over SSH with a password, left by the base image of the image build
if [ -f /etc/ssh/sshd_config.d/10-root-password.conf ]; then
    sudo rm -f /etc/ssh/sshd_config.d/10-root-password.conf
    sudo systemctl try-reload-or-restart sshd.service
fi
