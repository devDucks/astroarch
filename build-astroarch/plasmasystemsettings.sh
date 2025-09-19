#!/bin/bash

notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'Update AstroArch' "Please wait while the configuration is in progress"

sleep 1

kwriteconfig6 --file "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" --group 'Containments' --group '1' --key 'wallpaperplugin' "org.kde.slideshow"

sleep 1

kwriteconfig6 --file "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" --group 'Containments' --group '1' --group 'Wallpaper' --group 'org.kde.slideshow' --group 'General' --key 'SlidePaths' "/home/astronaut/Pictures/wallpapers/"

sleep 1

lookandfeeltool -a org.kde.breezedark.desktop

sleep 1

systemctl restart --user plasma-plasmashell

sleep 1

 notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'Update AstroArch' "Setup complete. Complete your personal setup with AstroArch-onboarding configurator"
