#!/usr/bin/env bash
# Installs the back end of the Control Center's Kiosk page, as root: the helper at the
# path its polkit action names (root-owned, outside the repo), the polkit action, the
# PHD2 sync units of the shared profiles and the units that let the main user's data
# backup read the kiosk settings (kiosk-group-read.sh, always on). Run by
# astroarch_build.sh and by the migrations: run it again in a migration whenever
# astroarch-kiosk-setup.sh or the policy changes.
set -e

REPO="$(dirname "$(readlink -f "$0")")/.."

install -Dm755 "$REPO/scripts/astroarch-kiosk-setup.sh" /usr/lib/astroarch/astroarch-kiosk-setup
install -Dm644 "$REPO/configs/kiosk/org.astroarch.kiosk.policy" /usr/share/polkit-1/actions/org.astroarch.kiosk.policy
# No rule: the helper asks for the password like the other admin actions. Test systems
# had a rule that allowed it without one
rm -f /etc/polkit-1/rules.d/45-astroarch-kiosk-setup.rules
for unit in astroarch-kiosk-phd2-sync.path astroarch-kiosk-phd2-sync.service \
            astroarch-kiosk-group-read.path astroarch-kiosk-group-read.service; do
    ln -sfn "$REPO/systemd/$unit" "/etc/systemd/user/$unit"
done
# Enabled for the kiosk user (wants links in its home, as the build does for its units).
# Its first run also opens the files the kiosk wrote before (0600 KDE config files)
if KIOSK_HOME=$(getent passwd astronaut-kiosk | cut -d: -f6) && [ -d "$KIOSK_HOME" ]; then
    for unit in astroarch-kiosk-group-read.path astroarch-kiosk-group-read.service; do
        runuser -u astronaut-kiosk -- mkdir -p "$KIOSK_HOME/.config/systemd/user/default.target.wants"
        runuser -u astronaut-kiosk -- ln -sfn "/etc/systemd/user/$unit" "$KIOSK_HOME/.config/systemd/user/default.target.wants/$unit"
    done
    # On a running system, now (nothing to do in the image build)
    systemctl --user -M astronaut-kiosk@ daemon-reload 2>/dev/null \
        && systemctl --user -M astronaut-kiosk@ start astroarch-kiosk-group-read.path astroarch-kiosk-group-read.service 2>/dev/null || true
fi
