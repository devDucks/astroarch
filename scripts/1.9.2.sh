#!/usr/bin/env bash

# This will fix WiFi access
if [ ! -f /etc/modprobe.d/brcmfmac.conf ]; then
    sudo bash -c "echo \"options brcmfmac feature_disable=0x82000\" > /etc/modprobe.d/brcmfmac.conf"
    echo "PLEASE REMEMBER TO REBOOT TO MAKE THE WIFI WORKING"
fi

# This will fix the problem with qhyccd.so.20
if [ -L /usr/lib/libqhyccd.so.20 ]; then
    sudo unlink /usr/lib/libqhyccd.so.20
fi
