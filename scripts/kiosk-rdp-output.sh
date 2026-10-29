#!/bin/bash
# Kiosk: KRdp (AdditionalDisplay) gives each RDP client an output sized to its window, placed at 0,0
# over the fixed Virtual-0. While such an output exists, turn Virtual-0 off so the kiosk desktop
# moves to the client output and follows its size. KWin turns Virtual-0 back on when the client leaves.

_fix_outputs() {
    local json
    json=$(kscreen-doctor -j 2>/dev/null) || return 0
    jq -e '.outputs[] | select(.name | contains("krdpserver"))' <<< "$json" > /dev/null || return 0
    jq -e '.outputs[] | select(.name == "Virtual-0" and .enabled)' <<< "$json" > /dev/null || return 0
    kscreen-doctor output.Virtual-0.disable > /dev/null 2>&1
}

_fix_outputs
# kscreen-console monitor prints lines whenever the outputs change. Under systemd Qt sends
# them to the journal instead, so force them onto stderr and into the pipe
QT_FORCE_STDERR_LOGGING=1 kscreen-console monitor 2>&1 | while read -r _; do
    _fix_outputs
done
