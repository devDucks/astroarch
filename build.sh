# Install yay
cd /home/astronaut
su astronaut -c "git clone https://aur.archlinux.org/yay.git"
cd yay/
su astronaut -c "makepkg -s"
pacman -U yay*.tar.xz --noconfirm
cd .. && rm -rf yay/

# install oh-my-zsh and set the default shell to zsh
chsh -s /usr/bin/zsh astronaut
rm /home/astronaut/.bash*
cd /home/astronaut
ZSH=/home/astronaut/.oh-my-zsh sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
chown astronaut:astronaut .oh-my-zsh/
# copy a zsh config for astronaut
ln -s /home/astronaut/.astroarch/configs/.zshrc /home/astronaut/.zshrc

su astronaut -c "yay -S --noremovemake --nodiffmenu --answerclean 4 gsc"
su astronaut -c "yay -S novnc"

# make a dir to store sddm config
mkdir /etc/sddm.conf.d

# Create the hotspot and set autoconnect to true
nmcli device wifi hotspot ifname wlan0 ssid AstroArch password "astronomy"
sed -i 's/autoconnect=false/autoconnect=true/g' /etc/NetworkManager/system-connections/Hotspot.nmconnection

# Create Xauthority for x11vnc
su astronaut -c "touch /home/astronaut/.Xauthority"

# Remove default systemd services that we will override
rm /usr/lib/systemd/system/x11vnc.service

# Symlink now files
ln -s /home/astronaut/.astroarch/systemd/autologin.conf /etc/sddm.conf.d/autologin.conf
ln -s /home/astronaut/.astroarch/systemd/novnc.service /etc/systemd/system/multi-user.target.wants/novnc.service
ln -s /home/astronaut/.astroarch/systemd/x11vnc.service /usr/lib/systemd/system/x11vnc.service

# Enable now all services
systemctl enable sddm.service novnc.service dhcpcd.service NetworkManager.service x11vnc.service
