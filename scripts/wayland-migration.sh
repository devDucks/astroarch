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

# Packages the X11 system loses, and the ones the Wayland setup needs
X11_PKGS="plasma-x11-session xorgxrdp xrdp"
NEW_PKGS="krdp plasma-login-manager flatpak tigervnc jq kscreen"

# Users that get the remote desktop services (krdp + w0vncserver)
SERVICE_USERS="astronaut astronaut-kiosk"

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
    echo "The update is checked and downloaded first, with the desktop still running."
    echo "Then the desktop closes. DO NOT POWER OFF."

    # Block here so update-astroarch does not go on with its own pacman run.
    # The migration stops SDDM, which ends this session (and this script).
    # Show the progress here too, until the migration ends or the session closes
    tail -n 0 -F "$LOG" 2> /dev/null &
    local tail_pid=$!
    # Only a state systemctl really prints ends the wait: when the migration
    # upgrades systemd, systemctl is missing or fails for a moment, and that
    # is not the end of the migration
    while :; do
        case $(systemctl is-active "$UNIT" 2> /dev/null) in
            inactive|failed) break ;;
        esac
        sleep 2
    done
    kill "$tail_pid" 2> /dev/null

    # Still alive and the unit is gone: the migration ended without reboot.
    if tail -n 5 "$LOG" 2> /dev/null | grep -q "NOTHING WAS CHANGED"; then
        echo "❌ The migration stopped before changing anything: the system works as before. See $LOG"
    else
        echo "❌ The migration stopped without rebooting. See $LOG"
    fi
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

    # Run a command as another user, without needing a login session
    as_user() {
        local u=$1
        shift
        runuser -u "$u" -- env HOME="/home/$u" XDG_CONFIG_HOME="/home/$u/.config" "$@"
    }

    # Enable a user unit for one user by creating the "wants" link
    # (what "systemctl --user enable" does, but without a user bus).
    # The unit itself must already be in a unit search path.
    enable_user_unit() {
        local u=$1 path=$2 target=${3:-graphical-session.target}
        local dir="/home/$u/.config/systemd/user/$target.wants"
        as_user "$u" mkdir -p "$dir" \
            && as_user "$u" ln -sfn "$path" "$dir/$(basename "$path")" \
            || step_fail "enable $(basename "$path") for $u"
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
    # 0. Check and download everything BEFORE changing anything. If this
    #    fails, the system is left as it was: desktop, VNC and XRDP working.
    # -----------------------------------------------------------------------
    log "Checking and downloading the update, nothing is changed yet"
    local REMOVE=() p
    for p in $X11_PKGS; do
        pacman -Qq "$p" > /dev/null 2>&1 && REMOVE+=("$p")
    done
    local KEYRINGS="archlinux-keyring"
    pacman -Qq archlinuxarm-keyring > /dev/null 2>&1 && KEYRINGS+=" archlinuxarm-keyring"
    # All of it runs on a copy of the package database, with its own log:
    # the real system is not touched until step 1
    local TMPDB=/var/tmp/astroarch-wayland-db pre_ok=0 why="" try avail_kb gone=""
    local TMPPAC=(--dbpath "$TMPDB" --logfile "$TMPDB.log")
    rm -rf "$TMPDB" "$TMPDB.log"
    # What the removal of step 3 takes away, with the dependencies it leaves
    # unneeded. --print changes nothing, and fails if other installed packages
    # need the X11 ones
    if [ ${#REMOVE[@]} -gt 0 ]; then
        if gone=$(pacman -Rs --print --print-format '%n-%v' --noconfirm "${REMOVE[@]}" 2> /dev/null); then
            gone=$(printf '%s\n' "$gone" | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g')
        else
            why="other installed packages need ${REMOVE[*]}"
        fi
    fi
    if [ -n "$why" ]; then
        :
    elif ! cp -a /var/lib/pacman "$TMPDB"; then
        why="could not copy the package database"
    else
        # Take them out of the copy by hand: pacman -R --dbonly would still run
        # the hooks on the real system (the #278 one would stop it)
        for p in $gone; do
            [ -d "$TMPDB/local/$p" ] && rm -rf "${TMPDB:?}/local/$p" || why="unexpected package entry $p"
        done
    fi
    if [ -z "$why" ]; then
        # The whole upgrade on that database: dependency problems show up here,
        # and every package lands in the cache, so step 6 needs no network
        for try in 1 2 3; do
            pacman "${TMPPAC[@]}" -Syuw --noconfirm $KEYRINGS $NEW_PKGS && { pre_ok=1; break; }
            [ "$try" -lt 3 ] || break
            log "download failed (attempt $try/3), retrying in 15s"
            sleep 15
        done
        [ "$pre_ok" -eq 1 ] || why="the download failed, check the network"
    fi
    if [ "$pre_ok" -eq 1 ]; then
        # pacman -w doesn't check the space the upgrade itself needs
        avail_kb=$(df --output=avail -k / | tail -n1 | tr -d ' ')
        if [ "$avail_kb" -lt 2000000 ]; then
            pre_ok=0
            why="not enough free space on / after the download ($((avail_kb / 1024)) MB, 2 GB needed)"
        # The package databases the download was checked against, swapped in whole
        elif ! { rm -rf /var/lib/pacman/sync.new && cp -a "$TMPDB/sync" /var/lib/pacman/sync.new \
                 && rm -rf /var/lib/pacman/sync.old && mv /var/lib/pacman/sync /var/lib/pacman/sync.old \
                 && mv /var/lib/pacman/sync.new /var/lib/pacman/sync; }; then
            [ -d /var/lib/pacman/sync ] || mv /var/lib/pacman/sync.old /var/lib/pacman/sync
            pre_ok=0
            why="could not update the package databases"
        fi
        rm -rf /var/lib/pacman/sync.new /var/lib/pacman/sync.old
    fi
    rm -rf "$TMPDB" "$TMPDB.log"
    if [ "$pre_ok" -ne 1 ]; then
        log "CRITICAL: $why."
        log "NOTHING WAS CHANGED, the desktop stays as it is. See $LOG"
        touch "$STATE/FAILED"
        wall "AstroArch: the Wayland migration stopped before changing anything ($why). The system works as before." 2> /dev/null
        return 1
    fi
    rm -f "$STATE/FAILED"

    # -----------------------------------------------------------------------
    # 1. Stop the graphical session
    # -----------------------------------------------------------------------
    log "Stopping the graphical session"
    systemctl stop sddm.service plasmalogin.service packagekit.service 2> /dev/null
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
    # What was enabled, and the unit files (disable removes linked ones), in case
    # step 3 fails and this has to be undone
    local WAS_ENABLED=() user_vnc=0 f
    for f in /etc/systemd/system/x0vncserver.service /etc/systemd/user/x0vncserver-xrdp.service \
             /etc/systemd/system/xrdp-autostart-kiosk.service; do
        { [ -e "$f" ] || [ -L "$f" ]; } && cp -a --parents "$f" "$BK/" 2> /dev/null
    done
    for u in x0vncserver xrdp xrdp-sesman xrdp-autostart-kiosk; do
        systemctl is-enabled --quiet "$u.service" 2> /dev/null && WAS_ENABLED+=("$u.service")
        systemctl disable --now "$u.service" 2> /dev/null
    done
    systemctl --global is-enabled --quiet x0vncserver-xrdp.service 2> /dev/null && user_vnc=1
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

    if [ ${#REMOVE[@]} -gt 0 ]; then
        # Nothing else may hold the package database (a pacman still running)
        for i in $(seq 60); do [ -e /var/lib/pacman/db.lck ] || break; sleep 2; done
        log "Removing packages: ${REMOVE[*]}"
        if ! pacman -Rns --noconfirm "${REMOVE[@]}"; then
            # Checked in step 0, so this should not happen. The system is still
            # X11: put back step 2 and the marker for the #278 hook.
            log "CRITICAL: removing ${REMOVE[*]} failed. Putting the X11 remote access back, not rebooting."
            cp -a "$BK/etc/." /etc/ 2> /dev/null
            rm -f /etc/astroarch/wayland
            systemctl daemon-reload
            [ ${#WAS_ENABLED[@]} -eq 0 ] || systemctl enable --now "${WAS_ENABLED[@]}"
            [ "$user_vnc" -eq 0 ] || systemctl --global enable x0vncserver-xrdp.service
            touch "$STATE/FAILED"
            systemctl start sddm.service
            return 1
        fi
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
    # 6. Upgrade (Plasma 6.8) + install what remote access needs, in ONE transaction
    #    (flatpak sets the portal grant; systems from older images may lack it)
    # -----------------------------------------------------------------------
    log "Upgrading the system, this is the long part. DO NOT POWER OFF."
    local upgrade_ok=0 try
    for try in 1 2 3; do
        # No -y: the databases are the ones step 0 downloaded everything for
        if pacman -S --needed --noconfirm $KEYRINGS && pacman -Su --needed --noconfirm $NEW_PKGS; then
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

    # -----------------------------------------------------------------------
    # 7. Remote access user services (only enabled here, NOT started:
    #    the reboot below is the real test that they start by themselves)
    # -----------------------------------------------------------------------
    log "Installing user services for: $SERVICE_USERS"

    # Units shipped in the repo, visible to every user (enabled per user below).
    # VNC runs as app-org.astroarch.vnc.service: the unit name gives w0vncserver
    # the portal app id "org.astroarch.vnc", so only krdp and this id are granted.
    local unit
    for unit in app-org.astroarch.vnc.service astroarch-portal-permissions.service; do
        ln -sfn "$REPO/systemd/$unit" "/etc/systemd/user/$unit"
    done
    ln -sfn "$REPO/desktop/org.astroarch.vnc.desktop" /usr/share/applications/org.astroarch.vnc.desktop

    # krdp starts only after the portal grant (first boot race)
    mkdir -p /etc/systemd/user/app-org.kde.krdpserver.service.d
    ln -sfn "$REPO/systemd/krdp-after-grant.conf" \
        /etc/systemd/user/app-org.kde.krdpserver.service.d/astroarch-grant.conf

    # Leftovers of the previous VNC layout (plain w0vncserver.service + per-user
    # links, portal grant on graphical-session.target): two VNC servers would
    # fight for port 5900.
    rm -f /etc/systemd/user/w0vncserver.service \
          /etc/systemd/user/w0vncserver-kiosk.service \
          /etc/systemd/user/graphical-session.target.wants/w0vncserver.service
    for u in astronaut astronaut-kiosk; do
        rm -f "/home/$u/.config/systemd/user/graphical-session.target.wants/w0vncserver.service" \
              "/home/$u/.config/systemd/user/graphical-session.target.wants/w0vncserver-kiosk.service" \
              "/home/$u/.config/systemd/user/graphical-session.target.wants/astroarch-portal-permissions.service"
    done

    local KRDP_UNIT=/usr/lib/systemd/user/app-org.kde.krdpserver.service
    [ -e "$KRDP_UNIT" ] || step_fail "krdp unit not found"
    [ -x /usr/bin/w0vncserver ] || step_fail "w0vncserver not found (tigervnc too old?)"

    local u
    for u in $SERVICE_USERS; do
        id "$u" > /dev/null 2>&1 && [ -d "/home/$u" ] || continue
        enable_user_unit "$u" /etc/systemd/user/app-org.astroarch.vnc.service plasma-workspace.target
        enable_user_unit "$u" /etc/systemd/user/astroarch-portal-permissions.service plasma-workspace.target
        [ -e "$KRDP_UNIT" ] && enable_user_unit "$u" "$KRDP_UNIT"

        # krdp server certificate (self-signed), as in the KDE/krdp README.
        # The README example uses -days 1; here it is valid 10 years.
        local cdir="/home/$u/.local/share/krdpserver"
        local crt="$cdir/krdp.crt" key="$cdir/krdp.key"
        as_user "$u" mkdir -p "$cdir"
        if [ ! -s "$crt" ] || [ ! -s "$key" ]; then
            as_user "$u" openssl req -nodes -new -x509 -keyout "$key" -out "$crt" \
                -days 3650 -batch -subj "/CN=astroarch" \
                -addext "subjectAltName = DNS:astroarch" \
                || step_fail "krdp certificate for $u"
        fi
        chmod 600 "$key" 2> /dev/null

        as_user "$u" kwriteconfig6 --file krdpserverrc --group General --key Certificate "$crt"
        as_user "$u" kwriteconfig6 --file krdpserverrc --group General --key CertificateKey "$key"
        as_user "$u" kwriteconfig6 --file krdpserverrc --group General --key SystemUserEnabled true
        as_user "$u" kwriteconfig6 --file krdpserverrc --group General --key Autostart true

        # astronaut-kiosk has its own ports: krdp 3390, VNC 5901
        if [ "$u" = astronaut-kiosk ]; then
            as_user "$u" kwriteconfig6 --file krdpserverrc --group General --key ListenPort 3390
            as_user "$u" mkdir -p "/home/$u/.config/systemd/user/app-org.astroarch.vnc.service.d"
            as_user "$u" ln -sfn "$REPO/systemd/kiosk-vnc-port.conf" \
                "/home/$u/.config/systemd/user/app-org.astroarch.vnc.service.d/port.conf" \
                || step_fail "kiosk VNC port drop-in"
        fi
    done

    # Never dim, turn off or suspend: with nobody at the Pi, VNC and RDP
    # would stop getting frames
    install -m644 "$REPO/configs/powerdevilrc" /etc/xdg/powerdevilrc

    # KWin script for every user: bring windows back inside the screen when it shrinks,
    # as when an RDP client window is made smaller
    ln -sfn "$REPO/configs/kwin/astroarch-keep-windows-visible" /usr/share/kwin/scripts/astroarch-keep-windows-visible

    # Kiosk: a headless Plasma session next to the desktop, started at boot by
    # the kiosk user manager (linger below). KWin draws on a virtual output,
    # KRdp gives each RDP client an output sized to its window
    local has_kiosk=0
    id astronaut-kiosk > /dev/null 2>&1 && [ -d /home/astronaut-kiosk ] && has_kiosk=1
    if [ "$has_kiosk" -eq 1 ]; then
        log "Setting up the headless kiosk session"
        # The kiosk units and scripts are links into $REPO: the kiosk user must be
        # able to read it. Only 2.0.10.sh granted that, and update-astroarch runs
        # only the version script of the version it moves to.
        bash "$REPO/scripts/kiosk-home-acl.sh" || step_fail "kiosk access to $ASTRO_HOME"
        local kdir=/home/astronaut-kiosk/.config/systemd/user
        for unit in astroarch-kiosk-session.service astroarch-kiosk-rdp-output.service astroarch-kiosk-layout.service astroarch-kiosk-app@.service; do
            ln -sfn "$REPO/systemd/$unit" "/etc/systemd/user/$unit"
        done
        enable_user_unit astronaut-kiosk /etc/systemd/user/astroarch-kiosk-session.service default.target
        enable_user_unit astronaut-kiosk /etc/systemd/user/astroarch-kiosk-rdp-output.service
        # On X11 .xinitrc ran 00-init-layout.sh at the first kiosk start (skipped if it already did)
        enable_user_unit astronaut-kiosk /etc/systemd/user/astroarch-kiosk-layout.service plasma-workspace.target
        as_user astronaut-kiosk mkdir -p "$kdir/plasma-kwin_wayland.service.d" "$kdir/app-org.kde.krdpserver.service.d" \
            && as_user astronaut-kiosk ln -sfn "$REPO/configs/kiosk/kwin-headless.conf" "$kdir/plasma-kwin_wayland.service.d/headless.conf" \
            && as_user astronaut-kiosk ln -sfn "$REPO/configs/kiosk/krdpserver-kiosk.conf" "$kdir/app-org.kde.krdpserver.service.d/kiosk.conf" \
            || step_fail "headless kiosk session"
        install -m644 "$REPO/configs/kiosk/45-allow-shutdown-kiosk.rules" /etc/polkit-1/rules.d/45-allow-shutdown-kiosk.rules

        # Kiosk apps: keep the automatic launch and watchdog chosen in the old
        # .xinitrc as astroarch-kiosk-app@<app> units. Step 4 moved it to the
        # backup; on a re-run it is in the backup of the first run.
        local xinitrc
        xinitrc=$(ls -1d "$STATE"/backup-*/home/astronaut-kiosk/.xinitrc 2> /dev/null | tail -1)
        # Only those units start apps: Plasma session restore would start a second copy
        as_user astronaut-kiosk kwriteconfig6 --file ksmserverrc --group General --key loginMode emptySession
        _migrate_kiosk_app() {
            local app=$1 start=$2 watch=$3 unit="astroarch-kiosk-app@$1.service"
            if grep -qE "^[[:space:]]*$start" "$xinitrc" || grep -qE "^[[:space:]]*$watch" "$xinitrc"; then
                as_user astronaut-kiosk mkdir -p "$kdir/plasma-workspace.target.wants" \
                    && as_user astronaut-kiosk ln -sfn /etc/systemd/user/astroarch-kiosk-app@.service \
                        "$kdir/plasma-workspace.target.wants/$unit" \
                    || step_fail "kiosk app $app"
            fi
            if grep -qE "^[[:space:]]*$watch" "$xinitrc"; then
                as_user astronaut-kiosk mkdir -p "$kdir/$unit.d" \
                    && printf '[Service]\nRestart=always\n' | as_user astronaut-kiosk tee "$kdir/$unit.d/watchdog.conf" > /dev/null \
                    || step_fail "kiosk app $app watchdog"
            fi
        }
        if [ -n "$xinitrc" ] && [ -f "$xinitrc" ]; then
            _migrate_kiosk_app kstars 'kstars &' 'pgrep -x kstars'
            _migrate_kiosk_app phd2 'phd2 &' 'pgrep -x "phd2.bin"'
            _migrate_kiosk_app astrodmx '/opt/AstroDMx-Capture/bin/AstroDMx-Capture &' 'pgrep -f AstroDMx-Capture'
            _migrate_kiosk_app xgps 'xgps &' 'pgrep -x xgps'
        fi
    fi

    # Keeps the user manager of astronaut and astronaut-kiosk alive (does not start services by itself)
    loginctl enable-linger astronaut
    [ "$has_kiosk" -eq 1 ] && loginctl enable-linger astronaut-kiosk
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
