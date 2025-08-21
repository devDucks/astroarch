#!/usr/bin/env bash

# First run 2.0.1.sh to be sure that old changes will be applied
bash /home/astronaut/.astroarch/scripts/2.0.1.sh

# Disable wifi powervaving permanently
sudo cp /home/astronaut/.astroarch/configs/81-wifi-powersave.rules /etc/udev/rules.d/81-wifi-powersave.rules
