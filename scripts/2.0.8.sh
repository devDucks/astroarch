#!/usr/bin/env bash

# Invoke 2.0.7
bash /home/astronaut/.astroarch/scripts/2.0.7.sh

# Udev rule to force the brcmfmac driver to keep the name “wlan0” for Wi-Fi
sudo cp -f /home/astronaut/.astroarch/configs/99-brcmfmac.rules /etc/udev/rules.d/99-brcmfmac.rules



