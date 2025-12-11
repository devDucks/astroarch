#!/bin/bash

#rm -R /kstars
rm /diskchroot
rm /astroarch_build_chroot.sh
rm /clear-install-astroarch.sh
rm /plasmasystemsettings.sh
rm /update-astroarch.sh
rm /kstars-watchdog.sh
rm /plasmasystemsettings.sh.desktop
rm /update-astroarch.sh.desktop
rm /kstars-watchdog.desktop
rm /home/astronaut/.cache/update-astroarch.sh
rm /home/astronaut/.cache/kstars-watchdog.sh
rm /home/astronaut/.cache/plasmasystemsettings.sh
rm /home/astronaut/.config/autostart/plasmasystemsettings.sh.desktop
rm /home/astronaut/.config/autostart/update-astroarch.sh.desktop
rm /home/astronaut/.config/autostart/kstars-watchdog.desktop

systemctl disable clear-install-astroarch.timer
systemctl disable astroarch-onboarding.timer

