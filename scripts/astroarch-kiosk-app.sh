#!/bin/bash
# Start one of the kiosk apps of configs/kiosk/apps.list by its id: for
# astroarch-kiosk-app@<id>.service, and with --ask for the menus and desktop icons of
# KStars and PHD2, on both desktops, while the kiosk shares the main user's profiles.
#
# Shared profiles (astroarch-kiosk-setup): the same app open on both desktops would
# save the same settings from two places and fight for the same equipment, so it is
# opened on one desktop at a time. With --ask the desktop says so and stops; started
# with the kiosk session (the unit), it waits until the app is closed on the main desktop.

REPO="$(dirname "$(readlink -f "$0")")/.."
APPS_LIST="$REPO/configs/kiosk/apps.list"
KIOSK_USER=${ASTROARCH_KIOSK_USER:-astronaut-kiosk}
# The main user is the kiosk user's name without "-kiosk", not "uid 1000"
MAIN_USER=${ASTROARCH_MAIN_USER:-${KIOSK_USER%-kiosk}}
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

# Shared: the kiosk's KStars data is a link to the main user's
if [ "$(id -un)" = "$MAIN_USER" ]; then
    other=$KIOSK_USER
    where="the kiosk desktop"
    kiosk_home=$(getent passwd "$KIOSK_USER" | cut -d: -f6)
    [ -n "$kiosk_home" ] && [ "$(readlink "$kiosk_home/.local/share/kstars")" = "$HOME/.local/share/kstars" ] && shared=1
else
    other=$MAIN_USER
    where="the main desktop"
    [ -L "$HOME/.local/share/kstars" ] && shared=1
fi

if [ -n "$process" ] && [ -n "$shared" ] && pgrep -u "$other" -x "$process" > /dev/null; then
    if [ "$ask" = 1 ]; then
        printf -v text '%s is open on %s.\n\nBoth desktops use the same profiles: close %s there first, then open it here.' \
            "$name" "$where" "$name"
        kdialog --title "$name" --sorry "$text"
        exit 1
    fi
    notify-send --app-name 'AstroArch' --icon="$ICON" -t 10000 "$name" \
        "$name is open on $where: it opens here once it is closed there."
    while pgrep -u "$other" -x "$process" > /dev/null; do
        sleep 10
    done
fi

read -ra argv <<< "$command"
# Files given by the menu (%U) follow the command
exec "${argv[@]}" "$@"
