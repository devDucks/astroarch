#!/usr/bin/bash
# AstroArch - Plasma X11 -> Plasma Wayland (KDE 6.8)
#
# Safe to re-run by hand:  bash wayland-migration.sh

ASTRO_HOME=/home/astronaut
REPO="$ASTRO_HOME/.astroarch"
RUN_DIR=/run/astroarch-wayland
UNIT=astroarch-wayland-migration
LOG=/var/log/astroarch-wayland-migration.log
STATE=/var/lib/astroarch/wayland-migration
ICON="$REPO/assets/icons/novnc-icon.svg"

# ===========================================================================
# LAUNCHER
# ===========================================================================
launcher() {
    if systemctl is-active --quiet "$UNIT"; then
        echo "❌ The migration is already running. Do NOT power off the machine."
        return 1
    fi
    if pgrep -x pacman > /dev/null; then
        echo "❌ pacman is already running, try again later."
        return 1
    fi
    local avail_kb
    avail_kb=$(df --output=avail -k / | tail -n1 | tr -d ' ')
    if [ "$avail_kb" -lt 3000000 ]; then
        echo "❌ Not enough free space on / (need ~3 GB, have $((avail_kb / 1024)) MB)."
        return 1
    fi

    # Ask for the sudo password NOW, while a terminal is still available
    sudo -v || return 1

    cat <<'EOF'

╔══════════════════════════════════════════════════════════════════╗
║   ASTROARCH: SWITCH TO THE WAYLAND DESKTOP (KDE Plasma 6.8)      ║
╠══════════════════════════════════════════════════════════════════╣
║  The desktop is going to CLOSE and the system will REBOOT        ║
║  automatically when the update is finished.                      ║
║                                                                  ║
║  >>> DO NOT POWER OFF OR UNPLUG THE MACHINE <<<                  ║
║  Just wait. This can take 10 to 30 minutes.                      ║
║  Progress is shown on the HDMI screen (console).                 ║
║  Remote desktop (VNC/RDP) will be disconnected.                  ║
╚══════════════════════════════════════════════════════════════════╝

EOF

    notify-send --app-name 'AstroArch' --icon="$ICON" -u critical -t 20000 \
        'AstroArch update' 'The desktop will close and the system will reboot. DO NOT power off, just wait.' 2> /dev/null

    trap 'echo; echo "Cancelled, nothing was changed."; exit 130' INT
    local i
    for i in 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1; do
        printf "\rStarting in %2ds  (Ctrl+C to cancel) " "$i"
        sleep 1
    done
    echo
    trap - INT

    # Copy to RAM and detach from the user session
    sudo install -d -m 0700 "$RUN_DIR" || return 1
    sudo install -m 0700 "$0" "$RUN_DIR/wayland-migration.sh" || return 1
    sudo systemd-run \
        --unit="$UNIT" \
        --description="AstroArch X11 -> Wayland migration" \
        --collect \
        /usr/bin/bash "$RUN_DIR/wayland-migration.sh" --detached || return 1

    echo "Migration started. Log: $LOG"
    echo "The desktop will close in a few seconds. DO NOT POWER OFF."

    # Block here so update-astroarch does not go on with its own pacman run.
    # The migration stops SDDM, which ends this session (and this script).
    while systemctl is-active --quiet "$UNIT"; do
        sleep 2
    done

    # Still alive and the unit is gone: the migration ended without reboot.
    echo "❌ The migration stopped without rebooting. See $LOG"
    return 1
}

# ===========================================================================
# MIGRATION (detached, root)
# ===========================================================================
migration() {
    local BK="$STATE/backup-$(date +%F_%H-%M)"
    local FAILED=()

    mkdir -p "$STATE" "$BK"

    # Progress on the HDMI console (tty1) + log file + journal
    if [ -w /dev/tty1 ]; then
        exec > >(tee -a "$LOG" /dev/tty1) 2>&1
    else
        exec >> "$LOG" 2>&1
    fi

    log()       { echo "[$(date +%T)] $*"; }
    step_fail() { FAILED+=("$1"); log "!! FAILED: $1"; }

    # Move to the backup dir (keeps the path), then delete
    trash() {
        local f
        for f in "$@"; do
            if [ -e "$f" ] || [ -L "$f" ]; then
                if cp -a --parents "$f" "$BK/" 2> /dev/null; then
                    rm -rf "$f"
                    log "removed $f"
                else
                    step_fail "backup of $f (left in place)"
                fi
            fi
        done
    }

    cat <<'EOF'

==================================================================
  ASTROARCH: SWITCHING TO THE WAYLAND DESKTOP (KDE Plasma 6.8)
  DO NOT POWER OFF OR UNPLUG THE MACHINE - JUST WAIT.
  The system will reboot by itself when this is finished.
==================================================================

EOF
    wall "AstroArch: Wayland migration in progress. DO NOT power off, the system will reboot by itself." 2> /dev/null
    log "Backup of removed files: $BK"

    # -----------------------------------------------------------------------
    # 1. Stop the graphical session
    # -----------------------------------------------------------------------
    log "Stopping the graphical session"
    systemctl stop sddm.service plasmalogin.service 2> /dev/null
    for u in astronaut astronaut-kiosk; do
        loginctl terminate-user "$u" 2> /dev/null
    done
    chvt 1 2> /dev/null
    setterm --blank 0 --powerdown 0 < /dev/tty1 > /dev/tty1 2> /dev/null

    # -----------------------------------------------------------------------
    # 2. Stop and disable old X11 VNC / XRDP services
    #    (BEFORE deleting their unit files)
    # -----------------------------------------------------------------------
    log "Disabling X11 VNC and XRDP services"
    for u in x0vncserver xrdp xrdp-sesman xrdp-autostart-kiosk; do
        systemctl disable --now "$u.service" 2> /dev/null
    done
    systemctl --global disable x0vncserver-xrdp.service 2> /dev/null

    trash /etc/systemd/system/x0vncserver.service \
          /etc/systemd/user/x0vncserver-xrdp.service \
          /etc/systemd/system/xrdp-autostart-kiosk.service
    find /etc/systemd -xtype l \( -name 'x0vncserver*' -o -name 'xrdp*' \) -print -delete
    systemctl daemon-reload

    # -----------------------------------------------------------------------
    # 3. Remove X11 session + XRDP packages (xorgxrdp depends on xrdp)
    # -----------------------------------------------------------------------
    # Tell the pacman hook of PR #278 (astroarch-keep-x11-session) that this
    # system is going to Wayland, otherwise it aborts the removal below.
    mkdir -p /etc/astroarch && touch /etc/astroarch/wayland

    local PKGS=() p
    for p in plasma-x11-session xorgxrdp xrdp; do
        pacman -Qq "$p" > /dev/null 2>&1 && PKGS+=("$p")
    done
    if [ ${#PKGS[@]} -gt 0 ]; then
        log "Removing packages: ${PKGS[*]}"
        pacman -Rns --noconfirm "${PKGS[@]}" || step_fail "pacman -Rns ${PKGS[*]}"
    fi

    # The xrdp system user is named "xrdp" ("xrdp daemon" is its comment).
    # No -r: its home is "/".
    if id xrdp > /dev/null 2>&1; then
        userdel xrdp || step_fail "userdel xrdp"
    fi

    # -----------------------------------------------------------------------
    # 4. Remove leftover X11 / XRDP files (astronaut, astronaut-kiosk, system)
    # -----------------------------------------------------------------------
    log "Removing leftover X11/XRDP files"
    trash /etc/sddm.conf.d/kde_settings.conf \
          /etc/X11/xorg.conf \
          /etc/X11/xorg.conf.d/99-v3d.conf \
          /etc/xrdp \
          /etc/pam.d/xrdp-sesman \
          /etc/pam.d/xrdp-sesman.pacsave \
          "$ASTRO_HOME/.config/autostart/AstroArch-onboarding-x11.desktop" \
          "$ASTRO_HOME/.config/autostart/AstroArch-onboarding-xrdp.desktop"

    # astronaut-kiosk: the xrdp session launcher, its X11 startup files,
    # the xrdp shutdown polkit rule and the xrdp session logs
    # (the globs stay literal, and are skipped, when nothing matches)
    trash /etc/polkit-1/rules.d/45-allow-shutdown-xrdp.rules \
          /home/astronaut-kiosk/startwm.sh \
          /home/astronaut-kiosk/.xinitrc \
          /home/astronaut-kiosk/.xorgxrdp.*.log \
          /home/astronaut-kiosk/.xsession-errors*

    # -----------------------------------------------------------------------
    # 5. SDDM Wayland config, kept as a FALLBACK: done BEFORE the upgrade so
    #    that, if the upgrade fails, SDDM can be restarted with a sane config.
    #    The switch to Plasma Login Manager is done after the upgrade (6b).
    # -----------------------------------------------------------------------
    log "Configuring SDDM for Wayland (fallback)"
    mkdir -p /etc/sddm.conf.d
    ln -sfn "$REPO/configs/plasma-wayland.conf" /etc/sddm.conf.d/plasma-wayland.conf
    ln -sfn "$REPO/configs/autologin.conf"      /etc/sddm.conf.d/autologin.conf
    local f
    for f in /etc/sddm.conf /etc/sddm.conf.d/*; do
        [ -e "$f" ] && grep -qE '^[[:space:]]*DisplayServer[[:space:]]*=[[:space:]]*x11' "$f" \
            && log "WARNING: $f still sets DisplayServer=x11"
    done

    # -----------------------------------------------------------------------
    # 6. Upgrade (Plasma 6.8) + install plasma-login-manager, in ONE transaction
    # -----------------------------------------------------------------------
    log "Upgrading the system, this is the long part. DO NOT POWER OFF."
    local upgrade_ok=0 try
    for try in 1 2 3; do
        if pacman -Sy --noconfirm archlinux-keyring && pacman -Su --noconfirm plasma-login-manager; then
            upgrade_ok=1
            break
        fi
        log "pacman failed (attempt $try/3), retrying in 15s"
        sleep 15
    done

    if [ "$upgrade_ok" -ne 1 ] \
        || [ ! -e /usr/share/wayland-sessions/plasma.desktop ] \
        || [ ! -e /usr/lib/systemd/system/plasmalogin.service ]; then
        log "CRITICAL: upgrade failed, or Wayland session / plasma-login-manager missing."
        log "Not rebooting. Restarting the display manager. See $LOG"
        touch "$STATE/FAILED"
        systemctl start sddm.service
        return 1
    fi
    log "Installed: $(pacman -Q plasma-desktop 2> /dev/null)"

    # -----------------------------------------------------------------------
    # 6b. Switch the display manager: SDDM -> Plasma Login Manager
    #     (the SDDM package and its dormant config are kept for a rollback)
    # -----------------------------------------------------------------------
    log "Switching display manager: sddm -> plasmalogin"
    mkdir -p /etc/plasmalogin.conf.d
    ln -sfn "$REPO/configs/autologin.conf" /etc/plasmalogin.conf.d/autologin.conf

    # Both units own display-manager.service: --force moves it to plasmalogin.
    # plasmalogin first, so a power cut in between never leaves no display manager
    if systemctl enable --force plasmalogin.service; then
        systemctl disable sddm.service
        log "plasmalogin.service enabled, sddm.service disabled"
    else
        step_fail "enable plasmalogin.service (sddm kept)"
    fi

    # Never dim, turn off or suspend: with nobody at the Pi, VNC and RDP
    # would stop getting frames
    install -m644 "$REPO/configs/powerdevilrc" /etc/xdg/powerdevilrc

    systemctl daemon-reload

    # -----------------------------------------------------------------------
    # 8. Done: reboot
    # -----------------------------------------------------------------------
    if [ ${#FAILED[@]} -gt 0 ]; then
        log "Finished with non-critical problems:"
        printf '   - %s\n' "${FAILED[@]}"
        printf '%s\n' "${FAILED[@]}" > "$STATE/warnings"
    fi

    touch "$STATE/done"
    log "Migration finished. Rebooting in 10 seconds."
    sync
    for i in 10 9 8 7 6 5 4 3 2 1; do
        printf "\rReboot in %2ds " "$i"
        sleep 1
    done
    systemctl reboot
}

# ===========================================================================
case "$1" in
    --detached)
        [ "$(id -u)" -eq 0 ] || { echo "--detached must run as root"; exit 1; }
        migration
        exit $?
        ;;
    *)
        [ "$(id -u)" -ne 0 ] || { echo "Run as the astronaut user, not root"; exit 1; }
        launcher
        exit $?
        ;;
esac
