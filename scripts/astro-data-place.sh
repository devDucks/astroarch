#!/bin/bash
# Add the shared data folder /srv/astro-data to the Places panel of Dolphin and of
# the file dialogs, next to Home and Desktop. Run at every login by
# /etc/xdg/autostart/astroarch-astro-data-place.desktop, for astronaut and
# astronaut-kiosk, but it adds the place only once: a place the user removes stays removed.

DATA_DIR=/srv/astro-data
PLACES="${XDG_DATA_HOME:-$HOME/.local/share}/user-places.xbel"
DONE_FLAG="${XDG_STATE_HOME:-$HOME/.local/state}/astroarch/astro-data-place.done"

[ -d "$DATA_DIR" ] || exit 0
[ -e "$DONE_FLAG" ] && exit 0

_has_place() {
    grep -q "<bookmark href=\"file://$DATA_DIR\">" "$PLACES"
}

# Put the place after the Desktop one (after Home if there is none), else at the end
_add_place() {
    local tmp
    tmp=$(mktemp "$PLACES.XXXXXX") || return 1
    awk -v desktop="file://$(xdg-user-dir DESKTOP 2> /dev/null)" -v home="file://$HOME" \
        -v dir="$DATA_DIR" -v id="$(date +%s)/astro-data" '
        function place() {
            print " <bookmark href=\"file://" dir "\">"
            print "  <title>astro-data</title>"
            print "  <info>"
            print "   <metadata owner=\"http://freedesktop.org\">"
            print "    <bookmark:icon name=\"astroarch-astro-data\"/>"
            print "   </metadata>"
            print "   <metadata owner=\"http://www.kde.org\">"
            print "    <ID>" id "</ID>"
            print "   </metadata>"
            print "  </info>"
            print " </bookmark>"
        }
        { line[NR] = $0 }
        END {
            for (i = 1; i <= NR && !start; i++)
                if (index(line[i], "<bookmark href=\"" desktop "\">")) start = i
            for (i = 1; i <= NR && !start; i++)
                if (index(line[i], "<bookmark href=\"" home "\">")) start = i
            for (i = start; start && i <= NR && !end; i++)
                if (line[i] ~ /^ *<\/bookmark>/) end = i
            for (i = 1; i <= NR; i++) {
                if (!end && line[i] ~ /^<\/xbel>/) place()
                print line[i]
                if (i == end) place()
            }
        }' "$PLACES" > "$tmp" && chmod --reference="$PLACES" "$tmp" && mv "$tmp" "$PLACES"
    local rc=$?
    rm -f "$tmp"
    return $rc
}

# Plasma writes the default places at the first login: wait for them
for _ in $(seq 60); do
    [ -s "$PLACES" ] && break
    sleep 1
done
[ -s "$PLACES" ] || exit 0

# Plasma or Dolphin may save their own copy right after the login and drop the
# new place: check again a little later
for _ in 1 2 3; do
    _has_place || _add_place || exit 1
    sleep 5
    if _has_place; then
        mkdir -p "$(dirname "$DONE_FLAG")" && touch "$DONE_FLAG"
        exit 0
    fi
done
exit 1
