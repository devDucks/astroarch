#!/bin/bash
# Start one of the kiosk apps of configs/kiosk/apps.list by its id: for
# astroarch-kiosk-app@<id>.service, and with --ask for the kiosk menu and desktop
# icons of KStars and PHD2 while the kiosk shares the main user's profiles.
#
# Shared profiles (astroarch-kiosk-setup): the same app open on both desktops would
# save the same settings from two places and fight for the same equipment, so it is
# opened on one desktop only. With --ask the kiosk says so and stops; started with the
# session (the unit), it waits until the app is closed on the main desktop.

REPO="$(dirname "$(readlink -f "$0")")/.."
APPS_LIST="$REPO/configs/kiosk/apps.list"
MAIN_USER=${ASTROARCH_MAIN_USER:-$(getent passwd 1000 | cut -d: -f1)}
ICON="$REPO/assets/icons/novnc-icon.svg"

ask=0
if [ "$1" = --ask ]; then
    ask=1
    shift
fi

line=$(grep -v '^[[:space:]]*#' "$APPS_LIST" | awk -F'|' -v id="$1" '$1 == id { print; exit }')
shift
IFS='|' read -r _ name _ command process <<< "$line"
if [ -z "$command" ]; then
    echo "Unknown kiosk app (see $APPS_LIST)" >&2
    exit 1
fi

# The kiosk shares the profiles when its KStars data is a link to the main user's
if [ -n "$process" ] && [ "$(id -un)" != "$MAIN_USER" ] && [ -L "$HOME/.local/share/kstars" ] \
    && pgrep -u "$MAIN_USER" -x "$process" > /dev/null; then
    if [ "$ask" = 1 ]; then
        kdialog --title "$name" --sorry "$name is open on the main desktop.\n\nThe kiosk uses the same profiles: close $name there first, then open it here."
        exit 1
    fi
    notify-send --app-name 'AstroArch' --icon="$ICON" -t 10000 "$name" \
        "$name is open on the main desktop: it opens here once it is closed there."
    while pgrep -u "$MAIN_USER" -x "$process" > /dev/null; do
        sleep 10
    done
fi

read -ra argv <<< "$command"
# Files given by the menu (%U) follow the command
exec "${argv[@]}" "$@"
