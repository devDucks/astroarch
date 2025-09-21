#!/usr/bin/env bash

bash /home/astronaut/.astroarch/scripts/2.0.3.sh

# Install Astroarch-onboarding
# Install package only if not already installed
if ! pacman -Q astroarch-onboarding >/dev/null 2>&1; then
    sudo pacman -S astroarch-onboarding --noconfirm
fi

# Copy desktop file only if it doesn't exist or source is newer
if [ ! -f /home/astronaut/Desktop/AstroArch-onboarding.desktop ]; then
    cp /home/astronaut/.astroarch/desktop/AstroArch-onboarding.desktop /home/astronaut/Desktop/AstroArch-onboarding
fi
