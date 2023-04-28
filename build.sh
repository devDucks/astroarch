# install oh-my-zsh and set the default shell to zsh
chsh -s /usr/bin/zsh astronaut
rm /home/astronaut/.bash*
cd /home/astronaut
ZSH=/home/astronaut/.oh-my-zsh sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
chown astronaut:astronaut .oh-my-zsh/

# Set the samba pass
ln -s /home/astronaut/.astroarch/configs/smb.conf /etc/samba/smb.conf
systemctl start smb
(echo astro; echo astro) | smbpasswd -s -a astronaut
systemctl stop smb

# Link a zsh config for astronaut
ln -s /home/astronaut/.astroarch/configs/.zshrc /home/astronaut/.zshrc

# prepare folder for user services
su astronaut -c "mkdir -p /home/astronaut/.config/systemd/user/default.target.wants"

# make a dir to store sddm config
mkdir /etc/sddm.conf.d

# Start NetworkManager and sleep to create the hotspot
systemctl start NetworkManager
sleep 5

# Create the hotspot and set autoconnect to true
nmcli device wifi hotspot ifname wlan0 ssid AstroArch password "astronomy"
nmcli connection modify Hotspot connection.autoconnect-priority -100
nmcli connection modify Hotspot connection.autoconnect true

# Create Xauthority for x11vnc
su astronaut -c "touch /home/astronaut/.Xauthority"

# Remove eventually existing systemd configs we are going to substitute
rm /usr/lib/systemd/system/novnc.service

# Symlink now files
ln -s /home/astronaut/.astroarch/systemd/autologin.conf /etc/sddm.conf.d/autologin.conf
ln -s /home/astronaut/.astroarch/systemd/novnc.service /usr/lib/systemd/system/novnc.service
ln -s /home/astronaut/.astroarch/systemd/x11vnc.service /home/astronaut/.config/systemd/user/default.target.wants/x11vnc.service
ln -s /home/astronaut/.astroarch/systemd/x11vnc.service /home/astronaut/.config/systemd/user
ln -s /home/astronaut/.astroarch/configs/20-headless.conf /usr/share/X11/xorg.conf.d/20-headless.conf
ln -s /home/astronaut/.astroarch/systemd/resize_once.service /etc/systemd/system/resize_once.service
ln -s /home/astronaut/.astroarch/configs/.astroarch.version /home/astronaut/.astroarch.version

# Enable oneshot script to set the bubble nebula wallpaper
su astronaut -c "cp /home/astronaut/.astroarch/systemd/change_wallpaper_once.service /home/astronaut/.config/systemd/user"
su astronaut -c "ln -s /home/astronaut/.config/systemd/user/change_wallpaper_once.service /home/astronaut/.config/systemd/user/default.target.wants/change_wallpaper_once.service"

# Copy the config for kwinrc
su astronaut -c "cp /home/astronaut/.astroarch/configs/kwinrc /home/astronaut/.config"

# Enable now all services
systemctl enable sddm.service novnc.service dhcpcd.service NetworkManager.service avahi-daemon.service nmb.service smb.service systemd-timesyncd.service

# Take sudoers to the original state
sed -i 's/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers

# Link wallpaper
su astronaut -c "mkdir -p /home/astronaut/Pictures"
su astronaut -c "cp /home/astronaut/.astroarch/wallpapers/bubble.jpg /home/astronaut/Pictures/bubble.jpg"

# Copy desktop icons
su astronaut -c "mkdir -p /home/astronaut/Desktop"
su astronaut -c "cp /home/astronaut/.astroarch/desktop/org.kde.konsole.desktop /home/astronaut/Desktop"
su astronaut -c "cp /home/astronaut/.astroarch/desktop/org.kde.kstars.desktop /home/astronaut/Desktop"
su astronaut -c "cp /home/astronaut/.astroarch/desktop/phd2.desktop /home/astronaut/Desktop"
su astronaut -c "ln -s /usr/share/applications/astrodmx_capture.desktop /home/astronaut/Desktop/AstroDMx_capture"

# Make the icons executable so there will be no ! on the first boot
chmod +x /home/astronaut/Desktop/*

# Remove actual novnc icons
rm -r /usr/share/webapps/novnc/app/images/icons/*
# Copy custom novnc icons folder
cp -r /home/astronaut/.astroarch/assets/icons/* /usr/share/webapps/novnc/app/images/icons

# config hostnames
echo "astroarch" > /etc/hostname
echo "127.0.0.1          localhost" >> /etc/hosts
echo "127.0.1.1          astroarch" >> /etc/hosts

# Copy the screensaver config, by default it is off
su astronaut -c "cp /home/astronaut/.astroarch/configs/kscreenlockerrc /home/astronaut/.config/kscreenlockerrc"

# Reboot and enjoy now
reboot
