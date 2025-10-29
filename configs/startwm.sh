#!/usr/bin/env bash
STATUS="$(systemctl is-active x0vncserver-xrdp.service)"
if [ "${STATUS}" = "active" ]; then
    exit 1
else
    systemctl --user -M astronaut@ enable x0vncserver-xrdp
fi

systemctl --user -M astronaut@ start x0vncserver-xrdp && exec dbus-run-session -- startplasma-x11
