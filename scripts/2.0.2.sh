#!/usr/bin/env bash

# Disable wifi powervaving permanently
sudo cp /home/astronaut/.astroarch/configs/81-wifi-powersave.rules /etc/udev/rules.d/81-wifi-powersave.rules
