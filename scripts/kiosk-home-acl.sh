#!/usr/bin/env bash

# Give astronaut-kiosk rwx on the astronaut home through ACLs, run as root.
# Group permissions are not used on purpose:
#  - a default ACL is inherited by new files, a umask 022 group bit is not
#  - the owner exec bit is never touched, so git sees no mode changes
set -e

ASTRO_HOME=/home/astronaut
KIOSK_USER=astronaut-kiosk

# These must not be writable by anyone else: zsh compaudit checks the fpath
# dirs (oh-my-zsh and ZSH_CUSTOM=~/.astroarch), sshd StrictModes checks ~/.ssh,
# gpg checks ~/.gnupg
KIOSK_EXCLUDE=(.astroarch .oh-my-zsh .ssh .gnupg)

id "$KIOSK_USER" >/dev/null 2>&1 || exit 0

# The home itself: enter and list only, sshd refuses keys if ~ is writable
setfacl -m u:$KIOSK_USER:rX "$ASTRO_HOME"

shopt -s nullglob dotglob
for entry in "$ASTRO_HOME"/*; do
    name=$(basename "$entry")
    # Symlinks point into the repo or system paths, leave their targets alone
    [[ -L "$entry" ]] && continue
    [[ " ${KIOSK_EXCLUDE[*]} " == *" $name "* ]] && continue
    if [[ -d "$entry" ]]; then
        setfacl -R -P -m u:$KIOSK_USER:rwX,d:u:$KIOSK_USER:rwX "$entry"
    else
        setfacl -m u:$KIOSK_USER:rw "$entry"
    fi
done

# The kiosk desktop runs scripts and uses icons from the repo: read only
setfacl -R -P -m u:$KIOSK_USER:rX "$ASTRO_HOME/.astroarch"
find "$ASTRO_HOME/.astroarch" -type d -exec setfacl -m d:u:$KIOSK_USER:rX {} +
