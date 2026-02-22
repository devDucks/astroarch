#!/bin/bash

CONN_NAME=astroarch-hotspot
SSID=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8)

# Short pause to ensure that the Wi-Fi driver is fully awake
sleep 2

nmcli connection add type wifi ifname wlan0 con-name $CONN_NAME autoconnect yes ssid AstroArch-$SSID
nmcli connection modify $CONN_NAME connection.autoconnect-priority -100;
nmcli connection modify $CONN_NAME 802-11-wireless.mode ap ipv4.method shared
nmcli connection modify $CONN_NAME wifi-sec.key-mgmt wpa-psk;
nmcli connection modify $CONN_NAME wifi-sec.psk "astronomy"
nmcli connection modify $CONN_NAME ipv6.method "disabled"

# Force the launch of the hotspot
nmcli connection up $CONN_NAME
