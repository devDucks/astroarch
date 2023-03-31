# First run 1.4.sh to be sure that old changes will be applied
bash /home/astronaut/.astroarch/scripts/1.4.sh

# Apply changes for 1.5
sudo pacman -Fy
sudo pacman -R alacritty --noconfirm
sudo pacman -S konsole --noconfirm

# Add Konsole icon to desktop and remove Alacritty one
su astronaut -c "cp /home/astronaut/.astroarch/desktop/org.kde.konsole.desktop /home/astronaut/Desktop"
rm /home/astronaut/Desktop/Alacritty.desktop

# Make the icons executable so there will be no ! on the first boot
chmod +x /home/astronaut/Desktop/org.kde.konsole.desktop
