#!/bin/bash
# Start one of the kiosk apps by its short name, for astroarch-kiosk-app@<name>.service
case "$1" in
    kstars) exec kstars ;;
    phd2) exec phd2 ;;
    astrodmx) exec /opt/AstroDMx-Capture/bin/AstroDMx-Capture ;;
    xgps) exec xgps ;;
    *) echo "Unknown kiosk app: $1 (kstars, phd2, astrodmx, xgps)" >&2; exit 1 ;;
esac
