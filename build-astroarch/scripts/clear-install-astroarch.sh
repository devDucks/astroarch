#!/bin/bash

rm /home/astronaut/.config/autostart/plasmasystemsettings.sh.desktop
rm /home/astronaut/.config/autostart/update-astroarch.sh.desktop
rm -R /kstars
rm /diskchroot
rm /astroarch_build_chroot.sh
rm /.zshrc2
rm /clear-install-astroarch.service
rm /clear-install-astroarch.timer
rm /clear-install-astroarch.sh

rm /home/astronaut/.zshrc
ln -s /home/astronaut/.astroarch/configs/.zshrc /home/astronaut/.zshrc
