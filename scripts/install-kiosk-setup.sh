#!/usr/bin/env bash
# Installs the back end of the Control Center's Kiosk page, as root: the helper at the
# path its polkit action names (root-owned, outside the repo), the polkit action and
# rule, and the PHD2 sync units of the shared profiles. Run by astroarch_build.sh and
# by the migrations: run it again in a migration whenever astroarch-kiosk-setup.sh,
# the policy or the rule changes.
set -e

REPO="$(dirname "$(readlink -f "$0")")/.."

install -Dm755 "$REPO/scripts/astroarch-kiosk-setup.sh" /usr/lib/astroarch/astroarch-kiosk-setup
install -Dm644 "$REPO/configs/kiosk/org.astroarch.kiosk.policy" /usr/share/polkit-1/actions/org.astroarch.kiosk.policy
install -Dm644 "$REPO/configs/kiosk/45-astroarch-kiosk-setup.rules" /etc/polkit-1/rules.d/45-astroarch-kiosk-setup.rules
for unit in astroarch-kiosk-phd2-sync.path astroarch-kiosk-phd2-sync.service; do
    ln -sfn "$REPO/systemd/$unit" "/etc/systemd/user/$unit"
done
