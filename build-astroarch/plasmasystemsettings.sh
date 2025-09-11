#!/bin/bash

sleep 30

kwriteconfig6 --file "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" --group 'Containments' --group '1' --key 'wallpaperplugin' "org.kde.slideshow"

sleep 1

kwriteconfig6 --file "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" --group 'Containments' --group '1' --group 'Wallpaper' --group 'org.kde.slideshow' --group 'General' --key 'SlidePaths' "/home/astronaut/Pictures/wallpapers/"

sleep 1

lookandfeeltool -a org.kde.breezedark.desktop

sleep 1

systemctl restart --user plasma-plasmashell
