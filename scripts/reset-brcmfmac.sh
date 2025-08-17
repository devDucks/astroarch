#!/bin/zsh

sudo systemctl stop wpa_supplicant
sudo systemctl stop NetworkManager
sudo systemctl stop x0vncserver
sudo killall wpa_supplicant
sudo rfkill unblock all
sudo modprobe -r brcmfmac_wcc
sudo modprobe -r brcmfmac
sudo modprobe brcmfmac
sudo systemctl start wpa_supplicant
sudo systemctl start NetworkManager
sudo systemctl start x0vncserver
sudo /home/astronaut/.astroarch/scripts/create_ap.sh
echo "brcmfmac wifi driver is reset. Your Raspberry must be restarted"
read -p "Press enter to continue"
reboot
