#!/usr/bin/env bash
# Keeps the PHD2 settings of the kiosk the same as the main user's while the kiosk
# shares the main user's profiles (astroarch-kiosk-setup). Run as the kiosk user by
# astroarch-kiosk-phd2-sync.path whenever either file changes.
#
# PHD2 replaces ~/.PHDGuidingV2 at every save, so it cannot be a link like the other
# shared profiles: each user has a file and the newer one is copied over the other.

# The main user is the kiosk user's name without "-kiosk", not "uid 1000"
KIOSK_USER=${ASTROARCH_KIOSK_USER:-astronaut-kiosk}
MAIN_HOME=$(getent passwd "${ASTROARCH_MAIN_USER:-${KIOSK_USER%-kiosk}}" | cut -d: -f6)
main=$MAIN_HOME/.PHDGuidingV2
own=$HOME/.PHDGuidingV2

[ -f "$main" ] || exit 0
[ -f "$own" ] && cmp -s "$main" "$own" && exit 0

if [ ! -f "$own" ] || [ "$main" -nt "$own" ]; then
    # A whole new file, as PHD2 writes it: PHD2 never reads half a copy
    tmp=$(mktemp "$own.XXXXXX") || exit 1
    cp "$main" "$tmp" && chmod 660 "$tmp" && touch -r "$main" "$tmp" && mv -f "$tmp" "$own" || { rm -f "$tmp"; exit 1; }
else
    # The kiosk cannot create files in the main home: it writes over the file, which
    # stays the main user's (group writable, see astroarch-kiosk-setup)
    cat "$own" > "$main" && touch -r "$main" "$own"
fi
