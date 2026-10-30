#!/usr/bin/env bash
# kiosk-group-read.sh: run as the kiosk user by astroarch-kiosk-group-read.path (after
# each change in its home or ~/.config) and .service (when its user manager starts).
#
# The main user backs up the kiosk's settings (Control Center, Data backup) and reads
# them through the kiosk's group, which only the main user is in. The kiosk session
# already has umask 022, but KDE writes its config files 0600 whatever the umask, and
# a default ACL would be masked by that same chmod. So the kiosk's own files are
# opened here to the group: read only, never write. Secrets stay private.
set -u
cd "$HOME" || exit 1

PRIVATE=(.ssh .gnupg .Xauthority .cache .local/state .local/share/kwalletd
         .local/share/krdpserver .local/share/xrdp .config/kwalletrc .config/krdpserverrc)
prune=()
for p in "${PRIVATE[@]}"; do
    prune+=(-path "./$p" -o)
done

# Folders the owner can enter: the group too; files the owner can read: the group too
find . -xdev \( "${prune[@]}" -false \) -prune -o -user "$(id -u)" \
    \( -type d -perm -u=rx ! -perm -g=rx -exec chmod g+rx {} + \) -o \
    \( -type f -perm -u=r ! -perm -g=r -exec chmod g+r {} + \)
exit 0
