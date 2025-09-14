#!/bin/bash

#rm -R /kstars
rm /diskchroot
rm /astroarch_build_chroot.sh
rm /clear-install-astroarch.sh
rm /plasmasystemsettings.sh
rm /update-astroarch.sh
rm /plasmasystemsettings.sh.desktop
rm /update-astroarch.sh.desktop
rm /home/astronaut/.cache/update-astroarch.sh
rm /home/astronaut/.cache/plasmasystemsettings.sh
rm /home/astronaut/.config/autostart/plasmasystemsettings.sh.desktop
rm /home/astronaut/.config/autostart/AstroArch-onboarding-x11.desktop
rm /home/astronaut/.config/autostart/AstroArch-onboarding-xrdp.desktop

systemctl disable clear-install-astroarch.timer

