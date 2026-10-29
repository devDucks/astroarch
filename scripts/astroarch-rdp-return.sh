#!/bin/bash
# KRdp's RemoteAccess mode hands the HDMI seat to the login screen and leaves the desktop session
# locked on disconnect: on a headless Pi nobody can log back in, and VNC/noVNC lose the desktop.
# When no RDP client is connected, give the seat back to the autologin user and unlock the session.
AUTOLOGIN_USER=$(sed -n 's/^User=//p' /etc/plasmalogin.conf.d/autologin.conf | head -1)
RDP_PORT=3389

while true; do
    sleep 5
    ss -Htn state established "( sport = :$RDP_PORT )" | grep -q . && continue
    SESSION=$(loginctl list-sessions --no-legend | awk -v u="$AUTOLOGIN_USER" '$3==u && $4=="seat0" {print $1; exit}')
    [ -n "$SESSION" ] || continue
    [ "$(loginctl show-session "$SESSION" -p Active --value)" = "no" ] || continue
    loginctl activate "$SESSION" && loginctl unlock-session "$SESSION" && echo "Gave seat0 back to session $SESSION"
done
