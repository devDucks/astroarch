#!/bin/bash

RESET_BRCMFMAC="/home/astronaut/.astroarch/scripts/reset-brcmfmac.sh"
CONN_NAME=astroarch-hotspot
SSID=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8)

IS_ACTIVE=$(nmcli -t -f NAME,DEVICE,STATE connection show --active | grep "^${CONN_NAME}:wlan0:activated$")

if [ -n "$IS_ACTIVE" ]; then
    exist 0
fi

sleep 3
nmcli device set wlan0 managed no
sleep 1
nmcli connection add type wifi ifname wlan0 con-name $CONN_NAME autoconnect yes ssid AstroArch-$SSID
nmcli connection modify $CONN_NAME connection.autoconnect-priority -100;
nmcli connection modify $CONN_NAME 802-11-wireless.mode ap ipv4.method shared
nmcli connection modify $CONN_NAME wifi-sec.key-mgmt wpa-psk;
nmcli connection modify $CONN_NAME wifi-sec.psk "astronomy"
nmcli connection modify $CONN_NAME ipv6.method "disabled"
nmcli device set wlan0 managed yes
sleep 1
nmcli connection up $CONN_NAME

# Détection de l'erreur -52
if dmesg | grep "brcmf.*-52"; then
    /bin/zsh "$RESET_BRCMFMAC"
fi

