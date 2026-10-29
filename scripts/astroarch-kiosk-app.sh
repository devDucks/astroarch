#!/bin/bash
# Start one of the kiosk apps of configs/kiosk/apps.list by its id, for
# astroarch-kiosk-app@<id>.service

APPS_LIST="$(dirname "$(readlink -f "$0")")/../configs/kiosk/apps.list"

line=$(grep -v '^[[:space:]]*#' "$APPS_LIST" | awk -F'|' -v id="$1" '$1 == id { print; exit }')
IFS='|' read -r _ name _ command process <<< "$line"
if [ -z "$command" ]; then
    echo "Unknown kiosk app: $1 (see $APPS_LIST)" >&2
    exit 1
fi

read -ra argv <<< "$command"
exec "${argv[@]}"
