#!/usr/bin/env bash

# DEPRECATED: replaced by the Kiosk page of the AstroArch Control Center
# (astroarch-control-center --page kiosk, back end scripts/astroarch-kiosk-setup.sh).
# Kept for one release for systems without the Control Center, then removed with
# desktop/astroarch-config-kiosk.desktop

# File paths
MENU_FILE="/home/astronaut-kiosk/.config/menus/plasma-applications.menu"

DESKTOP_DIR="/home/astronaut-kiosk/Desktop"

# Apps start as systemd user units of the kiosk session (astroarch-kiosk-app@<app>)
UNIT_DIR="$HOME/.config/systemd/user"
declare -A UNIT_APP
UNIT_APP["kstars &"]=kstars
UNIT_APP["pgrep -x kstars"]=kstars
UNIT_APP["phd2 &"]=phd2
UNIT_APP['pgrep -x "phd2.bin"']=phd2
UNIT_APP["AstroDMx-Capture/bin/AstroDMx-Capture &"]=astrodmx
UNIT_APP["pgrep -f AstroDMx-Capture"]=astrodmx
UNIT_APP["xgps &"]=xgps
UNIT_APP["pgrep -x xgps"]=xgps

# Auto launch = unit enabled with the session; watchdog = Restart=always drop-in
unit_state() {
    local pattern="$1"
    local unit="astroarch-kiosk-app@${UNIT_APP[$pattern]}.service"

    if [[ "$pattern" == pgrep* ]]; then
        [ -f "$UNIT_DIR/$unit.d/watchdog.conf" ] && echo "Enabled" || echo "Disabled"
    else
        systemctl --user is-enabled --quiet "$unit" && echo "Enabled" || echo "Disabled"
    fi
}

set_unit_state() {
    local state="$1"
    local pattern="$2"
    local unit="astroarch-kiosk-app@${UNIT_APP[$pattern]}.service"

    if [[ "$pattern" == pgrep* ]]; then
        if [ "$state" = "on" ]; then
            mkdir -p "$UNIT_DIR/$unit.d"
            printf '[Service]\nRestart=always\n' > "$UNIT_DIR/$unit.d/watchdog.conf"
            # As with the X11 watchdog loop, a watched app is started even without auto launch
            systemctl --user enable --quiet "$unit"
        else
            rm -f "$UNIT_DIR/$unit.d/watchdog.conf"
        fi
    elif [ "$state" = "on" ]; then
        systemctl --user enable --quiet "$unit"
    else
        systemctl --user disable --quiet "$unit"
    fi
    systemctl --user daemon-reload
}

declare -A DESKTOP_APPS
DESKTOP_APPS['APPS\["/usr/share/applications/org.kde.kstars.desktop"\]']="/usr/share/applications/org.kde.kstars.desktop|Kstars"
DESKTOP_APPS['APPS\["/usr/share/applications/phd2.desktop"\]']="/usr/share/applications/phd2.desktop|PHD2"
DESKTOP_APPS['APPS\["/usr/share/applications/astrodmx_capture.desktop"\]']="/usr/share/applications/astrodmx_capture.desktop|AstroDMx Capture"
DESKTOP_APPS['APPS\["/usr/share/applications/xgps.desktop"\]']="/usr/share/applications/xgps.desktop|xgps"

desktop_icon_state() {
    local key="$1"
    local data="${DESKTOP_APPS[$key]}"
    [ -z "$data" ] && return 1

    local src="${data%%|*}"
    local name="${data##*|}"
    local dest="$DESKTOP_DIR/$name"

    [ -L "$dest" ] && echo "Enabled" || echo "Disabled"
}

set_desktop_icon() {
    local state="$1"
    local key="$2"

    local data="${DESKTOP_APPS[$key]}"
    [ -z "$data" ] && return 1

    local src="${data%%|*}"
    local name="${data##*|}"
    local dest="$DESKTOP_DIR/$name"

    if [ "$state" = "on" ]; then
        ln -snf "$src" "$dest"
    else
        rm -f "$dest"
    fi
}


# The units belong to the kiosk user manager
if [ "$(id -un)" != "astronaut-kiosk" ]; then
    kdialog --error "Run this from the kiosk session (user astronaut-kiosk)"
    exit 1
fi

# Verify that the files exist

if [ ! -f "$MENU_FILE" ]; then
    kdialog --error "File $MENU_FILE not found!"
    exit 1
fi

is_active() {
    local file="$1"
    local pattern="$2"

    if [[ -n "${DESKTOP_APPS[$pattern]}" ]]; then
        desktop_icon_state "$pattern"
        return
    fi

    if [[ -n "${UNIT_APP[$pattern]}" ]]; then
        unit_state "$pattern"
        return
    fi

    if [[ "$file" == *.menu ]]; then
        if grep -E "^[[:space:]]*<Filename>$pattern</Filename>" "$file" >/dev/null 2>&1; then
            echo "Enabled"
        else
            echo "Disabled"
        fi
    else
        local line=$(grep "$pattern" "$file" 2>/dev/null | head -1)
        if [ -n "$line" ] && ! echo "$line" | grep -q "^[[:space:]]*#"; then
            echo "Enabled"
        else
            echo "Disabled"
        fi
    fi
}

set_state_bash() {
    local state="$1"
    local pattern="$2"

    if [[ -n "${DESKTOP_APPS[$pattern]}" ]]; then
        set_desktop_icon "$state" "$pattern"
        return
    fi

    if [[ -n "${UNIT_APP[$pattern]}" ]]; then
        set_unit_state "$state" "$pattern"
    fi
}

set_state_xml() {
    local state="$1"
    local pattern="$2"

    if [ "$state" = "on" ]; then
        sed -i "s|<!--[[:space:]]*\(<Filename>$pattern</Filename>\)[[:space:]]*-->|\1|g" "$MENU_FILE"
    else
        sed -i "s|^\([[:space:]]*\)\(<Filename>$pattern</Filename>\)|\1<!-- \2 -->|g" "$MENU_FILE"
    fi
}

get_all_states() {
    # KStars
    KS_DESK=$(is_active "" 'APPS\["/usr/share/applications/org.kde.kstars.desktop"\]')
    KS_MENU=$(is_active "$MENU_FILE" "org.kde.kstars.desktop")
    KS_START=$(is_active "" "kstars &")
    KS_WATCH=$(is_active "" "pgrep -x kstars")

    # PHD2
    PH_DESK=$(is_active "" 'APPS\["/usr/share/applications/phd2.desktop"\]')
    PH_MENU=$(is_active "$MENU_FILE" "phd2.desktop")
    PH_START=$(is_active "" "phd2 &")
    PH_WATCH=$(is_active "" 'pgrep -x "phd2.bin"')

    # AstroDMx
    AD_DESK=$(is_active "" 'APPS\["/usr/share/applications/astrodmx_capture.desktop"\]')
    AD_MENU=$(is_active "$MENU_FILE" "astrodmx_capture.desktop")
    AD_START=$(is_active "" "AstroDMx-Capture/bin/AstroDMx-Capture &")
    AD_WATCH=$(is_active "" "pgrep -f AstroDMx-Capture")

    # xgps
    XG_DESK=$(is_active "" 'APPS\["/usr/share/applications/xgps.desktop"\]')
    XG_MENU=$(is_active "$MENU_FILE" "xgps.desktop")
    XG_START=$(is_active "" "xgps &")
    XG_WATCH=$(is_active "" "pgrep -x xgps")
}

show_current_state() {
    get_all_states

    kdialog --title "Current configuration status" --msgbox "
╔═══════════════════════════════════════════════════════╗
║               CURRENT CONFIGURATION
╠═══════════════════════════════════════════════════════╣
║
║  📦 KStars
║    • Desktop icon:        $KS_DESK
║    • Applications Menu:   $KS_MENU
║    • Auto launch:         $KS_START
║    • Watchdog:            $KS_WATCH
║═══════════════════════════════════════════════════════╣
║  📦 PHD2
║    • Desktop icon         $PH_DESK
║    • Applications Menu:   $PH_MENU
║    • Auto launch          $PH_START
║    • Watchdog:            $PH_WATCH
║═══════════════════════════════════════════════════════╣
║  📦 AstroDMx Capture
║    • Desktop icon:        $AD_DESK
║    • Applications Menu:   $AD_MENU
║    • Auto launch:         $AD_START
║    • Watchdog:            $AD_WATCH
║═══════════════════════════════════════════════════════╣
║  📦 xgps
║    • Desktop icon:        $XG_DESK
║    • Applications Menu:   $XG_MENU
║    • Auto launch:         $XG_START
║    • Watchdog:            $XG_WATCH
║
╚═══════════════════════════════════════════════════════╝
"
}

configure_element() {
    local app_name="$1"
    local desk_pattern_bash="$2"
    local menu_pattern_xml="$3"
    local start_pattern_bash="$4"
    local watch_pattern_bash="$5"

    # Get the current status
    local desk_state=$(is_active "" "$desk_pattern_bash")
    local menu_state=$(is_active "$MENU_FILE" "$menu_pattern_xml")
    local start_state=$(is_active "" "$start_pattern_bash")
    local watch_state=$(is_active "" "$watch_pattern_bash")

    # Create options for radiolist
    local desk_current="off"; [ "$desk_state" = "Enabled" ] && desk_current="on"
    local menu_current="off"; [ "$menu_state" = "Enabled" ] && menu_current="on"
    local start_current="off"; [ "$start_state" = "Enabled" ] && start_current="on"
    local watch_current="off"; [ "$watch_state" = "Enabled" ] && watch_current="on"

    # Interface for configuration
    RESULT=$(kdialog --title "Configuration of $app_name" \
        --separate-output \
        --checklist "Current status and configuration :" \
        "desk" "Desktop icon (currently: $desk_state)" $desk_current \
        "menu" "Applications menu (currently: $menu_state)" $menu_current \
        "start" "Automatic launch (currently: $start_state)" $start_current \
        "watch" "Watchdog - Auto restart (currently: $watch_state)" $watch_current)

    if [ $? -ne 0 ]; then
        return
    fi

    if echo "$RESULT" | grep -q "^desk$"; then
        set_state_bash "on" "$desk_pattern_bash"
    else
        set_state_bash "off" "$desk_pattern_bash"
    fi

    if echo "$RESULT" | grep -q "^menu$"; then
        set_state_xml "on" "$menu_pattern_xml"
    else
        set_state_xml "off" "$menu_pattern_xml"
    fi

    if echo "$RESULT" | grep -q "^start$"; then
        set_state_bash "on" "$start_pattern_bash"
    else
        set_state_bash "off" "$start_pattern_bash"
    fi

    if echo "$RESULT" | grep -q "^watch$"; then
        set_state_bash "on" "$watch_pattern_bash"
    else
        set_state_bash "off" "$watch_pattern_bash"
    fi

    kdialog --msgbox "$app_name configuration updated!"
}

while true; do
    CHOICE=$(kdialog --title "AstroArch Kiosk Configuration" \
        --menu "What do you want to do?" \
        "state" "📊 Display the current configuration status" \
        "kstars" "⭐ Configure KStars" \
        "phd2" "🔭 Configure PHD2" \
        "astrodmx" "📷 Configure AstroDMx Capture" \
        "xgps" "🛰️  Configure xgps" \
        "astromonitor" "🌠 Retrieve your kstars configuration" \
        "backup" "💾 Create a manual backup" \
        "rebuild" "🔄 Rebuild the menu cache" \
        "quit" "❌ Exit")

    if [ $? -ne 0 ] || [ "$CHOICE" = "quit" ]; then
        break
    fi

    case "$CHOICE" in
        state)
            show_current_state
            ;;
        kstars)
            configure_element "KStars" \
                'APPS\["/usr/share/applications/org.kde.kstars.desktop"\]' \
                "org.kde.kstars.desktop" \
                "kstars &" \
                "pgrep -x kstars"
            ;;
        phd2)
            configure_element "PHD2" \
                'APPS\["/usr/share/applications/phd2.desktop"\]' \
                "phd2.desktop" \
                "phd2 &" \
                'pgrep -x "phd2.bin"'
            ;;
        astrodmx)
            configure_element "AstroDMx Capture" \
                'APPS\["/usr/share/applications/astrodmx_capture.desktop"\]' \
                "astrodmx_capture.desktop" \
                "AstroDMx-Capture/bin/AstroDMx-Capture &" \
                "pgrep -f AstroDMx-Capture"
            ;;
        xgps)
            configure_element "xgps" \
                'APPS\["/usr/share/applications/xgps.desktop"\]' \
                "xgps.desktop" \
                "xgps &" \
                "pgrep -x xgps"
            ;;
        backup)
            TIMESTAMP=$(date +%Y%m%d_%H%M%S)
            cp "$MENU_FILE" "${MENU_FILE}.backup.${TIMESTAMP}"
            kdialog --msgbox "Backup created successfully !\n\nTimestamp: $TIMESTAMP"
            ;;
        rebuild)
            kbuildsycoca6 > /dev/null 2>&1
            kdialog --msgbox "Menu cache rebuilt!\n\nRestart the session to see the changes"
            ;;
    esac
done

# Message de sortie
kdialog --msgbox "Restart the session now to apply the changes"

