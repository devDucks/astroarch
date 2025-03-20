#!/bin/bash

lookandfeeltool -a org.kde.breezedark.desktop

kwriteconfig6 --file "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" --group 'Containments' --group '1' --group 'Wallpaper' --group 'org.kde.slideshow' --group 'General' --key 'SlidePaths' "/home/astronaut/Pictures/wallpapers/"

kwriteconfig6 --file "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" --group 'Containments' --group '1' --key 'wallpaperplugin' "org.kde.slideshow"

systemctl restart --user plasma-plasmashell
