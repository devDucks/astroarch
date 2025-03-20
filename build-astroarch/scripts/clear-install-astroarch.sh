#!/bin/bash

rm /home/astronaut/.config/autostart/plasmasystemsettings.sh.desktop
rm /home/astronaut/.config/autostart/update-astroarch.sh.desktop
rm -R /kstars
rm /diskchroot

rm /home/astronaut/.zshrc
ln -s /home/astronaut/.astroarch/configs/.zshrc /home/astronaut/.zshrc
