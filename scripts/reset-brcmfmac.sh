#!/bin/zsh

notify-send --app-name 'AstroArch' \
    --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" \
    -t 15000 'AstroArch WIFI' "❌ The BRCMFMAC Wi-Fi driver is out of service. To perform the repair, your RPI must restart"

CONN_NAME="astroarch-hotspot"

# End of services
systemctl stop NetworkManager wpa_supplicant x0vncserver
killall -9 wpa_supplicant 2>/dev/null

# Delete ALL hotspot connections
for uuid in $(nmcli -g UUID,NAME connection show | grep "$CONN_NAME" | cut -d: -f1); do
    nmcli connection delete uuid "$uuid"
done

rfkill unblock all
modprobe -r brcmfmac_wcc 2>/dev/null
modprobe -r brcmfmac 2>/dev/null
sleep 2
modprobe brcmfmac
sleep 2

# Restarting services
systemctl start wpa_supplicant
systemctl start NetworkManager
systemctl start x0vncserver
sleep 3

reboot
