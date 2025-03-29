#!/bin/bash


rm -R /kstars
rm /diskchroot
rm /astroarch_build_chroot.sh
rm /home/astronaut/.config/autostart/plasmasystemsettings.sh.desktop
rm /home/astronaut/.config/autostart/update-astroarch.sh.desktop
rm /home/astronaut/.zshrc
ln -s /home/astronaut/.astroarch/configs/.zshrc /home/astronaut/.zshrc
rm -R /home/astronaut/.astroarch/sc74.github.io
rm /home/astronaut/.config/autostart/AstroArch-onboarding.desktop

systemctl disable clear-install-astroarch.timer
systemctl disable astroarch-onboarding.timer

