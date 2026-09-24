#!/usr/bin/env bash

# Give astronaut-kiosk access to the astronaut home through the shared
# "astronaut" group, run as root. Not ACLs: the build runs inside Docker
# (overlay2), which does not support POSIX ACLs ("Operation not supported").
#
# astroarch_build.sh already puts astronaut-kiosk in the astronaut group and
# astronaut in the astronaut-kiosk group, and astronaut's files are already
# group-owned "astronaut" (its own user-private group), so only the
# permission bits need setting here, no chgrp.
#
# X (not x) keeps file exec bits as they are, so a recursive grant doesn't
# mark every tracked file in ~/.astroarch as executable and break git pull.
#
# These must not be group/other writable: zsh compaudit checks the fpath
# dirs (oh-my-zsh and ZSH_CUSTOM=~/.astroarch), sshd StrictModes checks ~
# and ~/.ssh, gpg checks ~/.gnupg
KIOSK_EXCLUDE=(.astroarch .oh-my-zsh .ssh .gnupg)

set -e

ASTRO_HOME=/home/astronaut
KIOSK_USER=astronaut-kiosk

id "$KIOSK_USER" >/dev/null 2>&1 || exit 0

# The home itself: enter and list only, sshd refuses keys if ~ is writable
chmod g+rx "$ASTRO_HOME"

shopt -s nullglob dotglob
for entry in "$ASTRO_HOME"/*; do
    name=$(basename "$entry")
    # Symlinks point into the repo or system paths, leave their targets alone
    [[ -L "$entry" ]] && continue
    [[ " ${KIOSK_EXCLUDE[*]} " == *" $name "* ]] && continue
    chmod -R g+rwX "$entry"
done

# The kiosk desktop runs scripts and uses icons from the repo: read only.
# New files pulled in later by git keep group-read from the default umask,
# so this does not need to be re-run after every update-astroarch.
chmod -R g+rX "$ASTRO_HOME/.astroarch"
