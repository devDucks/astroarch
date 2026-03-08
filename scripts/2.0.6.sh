#!/usr/bin/env bash

# Add drift file for chrony
sudo sed -i '$a\driftfile /var/lib/chrony/drift' /etc/chrony.conf

# Xrdp
#Set AutoAddDevices to disabled to avoid device management conflicts between different sessions
sudo sed -i -E '/AutoAddDevices/ s/^([[:space:]]*)#/\1/' /etc/X11/xrdp/xorg.conf
# Disables the display's power management features
sudo sed -i 's/Option "DPMS"/& "false"/' /etc/X11/xrdp/xorg.conf
# Disabling compression can speed up local connections on low-power devices
sudo sed -i 's|bitmap_compression=true|bitmap_compression=false|g' /etc/xrdp/xrdp.ini
sudo sed -i 's|bulk_compression=true|bulk_compression=false|g' /etc/xrdp/xrdp.ini
# Improve xrdp & network
sudo cp /home/astronaut/.astroarch/configs/99-sysctl.conf /etc/sysctl.d

# NetworkManager WiFi Power Saving
sudo ln -s /home/astronaut/.astroarch/configs/default-wifi-powersave-on.conf /etc/NetworkManager/conf.d

