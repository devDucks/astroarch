#!/usr/bin/env bash

# Invoke 2.0.9
bash /home/astronaut/.astroarch/scripts/2.0.9.sh

# Pre-launch of the Kiosk session
sudo sed -i '1s/^/auth sufficient pam_succeed_if.so user = astronaut-kiosk\n/' /etc/pam.d/xrdp-sesman
sudo cp -f /home/astronaut/.astroarch/systemd/xrdp-autostart-kiosk.service /etc/systemd/system/xrdp-autostart-kiosk.service
sudo ln -sf /etc/systemd/system/xrdp-autostart-kiosk.service /etc/systemd/system/multi-user.target.wants/xrdp-autostart-kiosk.service
sudo systemctl enable xrdp-autostart-kiosk.service

# Give astronaut-kiosk rwx on the astronaut home through ACLs
sudo bash /home/astronaut/.astroarch/scripts/kiosk-home-acl.sh

# Let the kiosk run update-astroarch, as astronaut
if [ -d /home/astronaut-kiosk/Desktop ]; then
    sudo -u astronaut-kiosk ln -snf /home/astronaut/.astroarch/desktop/update-astroarch-kiosk.desktop /home/astronaut-kiosk/Desktop/update-astroarch
fi

# Undo the chmod -R 770 on the astronaut home done by 2.0.6 and 2.0.7:
# sshd refuses keys with a group writable ~ or ~/.ssh, zsh compaudit warns on
# group writable fpath dirs, and git sees every tracked file as executable
sudo chmod go-w /home/astronaut
for dir in .astroarch .oh-my-zsh .ssh .gnupg; do
    [ -d /home/astronaut/$dir ] && sudo chmod -R go-w /home/astronaut/$dir
done
cd /home/astronaut/.astroarch
git ls-files -s | while IFS=$'\t' read -r meta file; do
    [[ $meta == 100644* && -x $file ]] && chmod a-x "$file"
done
cd - > /dev/null 2>&1
