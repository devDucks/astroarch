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
sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
chown astronaut:astronaut .oh-my-zsh/
# copy a zsh config for astronaut

# Configure lightDM for autologin
#sed -i 's/#autologin-user=/autologin-user=astronaut/g' /etc/lightdm/lightdm.conf
#sed -i 's/#autologin-user-timeout=0/autologin-user-timeout=0/g' /etc/lightdm/lightdm.conf
#sed -i 's/#autologin-session=/autologin-session=lxqt/g' /etc/lightdm/lightdm.conf
#sed -i 's/#autologin-guest=false/autologin-guest=false/g' /etc/lightdm/lightdm.conf
#groupadd -r autologin
#gpasswd -a astronaut autologin
su astronaut -c "yay -S --noremovemake --nodiffmenu --answerclean 4 gsc"
su astronaut -c "yay -S realvnc-vnc-server novnc"

# Symlink now files
ln -s /home/astronaut/.astroarch/systemd/autologin.conf /etc/sddm.conf.d/autologin.conf
ln -s /home/astronaut/.astroarch/systemd/novnc.service /etc/systemd/system/multi-user.target.wants/novnc.service

# Enable now all services
systemctl enable sddm.service novnc.service vncserver-x11-serviced.service
