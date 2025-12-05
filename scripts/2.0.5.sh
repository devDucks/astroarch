#!/usr/bin/env bash

# Synchronize the system time with the GPS if there is no Real Time Clock (RTC) or network connection to the Raspberry Pi
sed -i '$a\refclock SHM 0 offset 0.5 delay 0.2 refid NMEA' /etc/chrony.conf
