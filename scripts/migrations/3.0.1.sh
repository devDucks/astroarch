#!/usr/bin/env bash

# Run once by astroarch-updates, like every script here, and written so that it can run
# again without harm.
# Cleanup for systems updated from 2.0.x: the 3.0 image no longer has these (#321, #322).
# And the astro-data folder in Dolphin, for systems already on 3.0.
# Stops at the first failed step, so that update-astroarch reverts and runs it again next time
set -e
REPO=/home/astronaut/.astroarch

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

# The shared data folder /srv/astro-data with its telescope and moon icon, in the Places
# panel of Dolphin and of the file dialogs and on the folder itself. The image build and
# the Wayland migration add it.
# The icons, in hicolor so that every user and theme finds them
sudo mkdir -p /usr/share/icons/hicolor/scalable/places
sudo ln -sfn "$REPO/assets/icons/astroarch-astro-data.svg" /usr/share/icons/hicolor/scalable/places/astroarch-astro-data.svg
sudo ln -sfn "$REPO/assets/icons/astroarch-astro-data-folder.svg" /usr/share/icons/hicolor/scalable/places/astroarch-astro-data-folder.svg
sudo gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor

# The folder icon: tmpfiles writes /srv/astro-data/.directory only if it is missing, so an
# icon the user chose stays
if [ -d /srv/astro-data ]; then
    sudo cp -f "$REPO/configs/astro-data.conf" /etc/tmpfiles.d/astro-data.conf
    sudo systemd-tmpfiles --create /etc/tmpfiles.d/astro-data.conf
fi

# The place, added at each user's next login (once: a place the user removes stays removed)
sudo ln -sfn "$REPO/configs/astroarch-astro-data-place.desktop" /etc/xdg/autostart/astroarch-astro-data-place.desktop
# and now for the user running the update, when the desktop is open
if [ -n "$WAYLAND_DISPLAY" ] && [ -d /srv/astro-data ]; then
    bash "$REPO/scripts/astro-data-place.sh" || true
fi

# The NAS shares of the Control Center's data backup: unmounted at shutdown only after the
# user sessions (and a backup still running in them) are stopped. Without this order the
# unmount failed while a backup ran, the network went down and the shutdown waited for the
# server forever. New shares get it from astroarch-tools; this fixes the ones already added
if grep -q '^# astroarch-backup nas ' /etc/fstab; then
    sudo sed -i '/^# astroarch-backup nas /{n;/x-systemd\.before=remote-fs\.target/!s/x-systemd\.automount/&,x-systemd.before=remote-fs.target/}' /etc/fstab
    sudo systemctl daemon-reload
fi
