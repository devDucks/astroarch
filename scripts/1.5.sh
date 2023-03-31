# First run 1.4.sh to be sure that old changes will be applied
bash /home/astronaut/.astroarch/scripts/1.4.sh

# Apply changes for 1.5
sudo pacman -Fy
sudo pacman -R alacritty
sudo pacman -S konsole
