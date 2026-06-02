#!/usr/bin/env bash
CURRENT_USER="${USER:-${LOGNAME}}"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"

case "${CURRENT_USER}" in
    astronaut)
    STATUS="$(systemctl is-active x0vncserver-xrdp.service)"
    if [ "${STATUS}" = "active" ]; then
        exit 1
    else
        systemctl --user -M astronaut@ enable x0vncserver-xrdp
    fi
    if command -v vncconfig &>/dev/null; then
    vncconfig -nowin &
    fi
    systemctl --user -M astronaut@ start x0vncserver-xrdp && exec dbus-run-session -- startplasma-x11
    ;;

    astronaut-kiosk)
    if command -v vncconfig &>/dev/null; then
    vncconfig -nowin &
    fi
    exec dbus-run-session -- /home/astronaut-kiosk/.xinitrc
    ;;
esac
