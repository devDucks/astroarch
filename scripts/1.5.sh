#!/usr/bin/env bash

# Apply changes for 1.5
sudo pacman -Sy

# Check for alacritty installation
check_alacritty=$(pacman -Q | grep -c alacritty)

if [ $check_alacritty -gt 0 ]; then
    sudo pacman -R alacritty --noconfirm
    echo "alacritty removed"
fi

# Check for konsole installation
check_konsole=$(pacman -Q | grep -c konsole)

if [ $check_konsole -eq 0 ]; then
    sudo pacman -S konsole --noconfirm
        echo "konsole installed"
fi

# Add Konsole icon to desktop and remove Alacritty one
if [ ! -f /home/astronaut/Desktop/org.kde.konsole.desktop ]; then
    su astronaut -c "cp /home/astronaut/.astroarch/desktop/org.kde.konsole.desktop /home/astronaut/Desktop/"
    echo "link for konsole added to Desktop"
fi

if [ -f /home/astronaut/Desktop/Alacritty.desktop ]; then
    rm /home/astronaut/Desktop/Alacritty.desktop
    echo "link for alacritty removed from Desktop"
fi

# Make the icons executable so there will be no ! on the first boot
if [ ! -x /home/astronaut/Desktop/org.kde.konsole.desktop ]; then
    chmod +x /home/astronaut/Desktop/org.kde.konsole.desktop
fi

exit 0
