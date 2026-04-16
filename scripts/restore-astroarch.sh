#!/bin/bash

# --- 1. CONFIGURATION AND TESTS ---
CONFIG_FILE="$HOME/.backup_dest"

is_gui() {
    [[ -n "$DISPLAY" && -z "$SSH_CLIENT" && -z "$SSH_TTY" ]]
}

# Fix for xRDP/Sudo MIT-MAGIC-COOKIE
if is_gui; then
    xhost +local:root > /dev/null 2>&1
    export XAUTHORITY=$HOME/.Xauthority
fi

# Function to ask for a new path
ask_new_path() {
    local REASON="$1"
    if is_gui; then
        DEST_PATH=$(kdialog --getexistingdirectory "$HOME" --title "$REASON - Choose backup folder:")
    else
        echo -e "\e[33m⚠️  $REASON\e[0m"
        read -p "Enter backup folder path: " DEST_PATH
    fi

    if [ -n "$DEST_PATH" ]; then
        echo "DEST_PATH=\"$DEST_PATH\"" > "$CONFIG_FILE"
        echo "FIRST_BACKUP=\"no\"" >> "$CONFIG_FILE"
        echo "AUTO_CHOICE=\"Ask\"" >> "$CONFIG_FILE"
    else
        exit 1
    fi
}

# Check config and path
if [ ! -f "$CONFIG_FILE" ]; then
    ask_new_path "Configuration file missing"
else
    source "$CONFIG_FILE"
    if [ ! -d "$DEST_PATH" ]; then
        ask_new_path "Saved destination not found"
    fi
fi

ABS_DEST=$(realpath "$DEST_PATH")

# --- 2. CONFIRMATIONS ---
if is_gui; then
    kdialog --warningcontinuecancel "WARNING: System restore will overwrite EVERYTHING from: $ABS_DEST\n\nProceed?" --title "System Restore" || exit 0
else
    echo -e "\e[31m⚠️  WARNING: System restore from $ABS_DEST. This will overwrite EVERYTHING.\e[0m"
    read -p "Continue? (y/N): " res; [[ ! "$res" =~ ^[yY]$ ]] && exit 0
fi

# --- 3. AUTHENTICATION ---
if ! sudo -n true 2>/dev/null; then
    if is_gui; then
        PASS=$(kdialog --title "Authentication" --password "Enter password:")
        [ -z "$PASS" ] && exit 1
        echo "$PASS" | sudo -S -v &>/dev/null
        [ $? -ne 0 ] && kdialog --error "Incorrect password." && exit 1
        unset PASS
    else
        sudo -v || exit 1
    fi
fi
( while true; do sudo -n -v; sleep 60; kill -0 "$$" || exit; done 2>/dev/null ) &

# --- 4. EXECUTION ---
EXCLUSIONS=(--exclude='/dev/*' --exclude='/proc/*' --exclude='/sys/*' --exclude='/tmp/*' --exclude='/run/*' --exclude='/mnt/*' --exclude='/media/*' --exclude='/lost+found/' --exclude='/boot/*' --exclude='*/thinclient_drives' --exclude='*/.gvfs' --exclude="$ABS_DEST")

if is_gui; then
    # --- DBUS METHOD FOR KDE ---
    # We send the notification via GDBus to retrieve its unique ID
    NOTIFY_ID=$(gdbus call --session --dest org.freedesktop.Notifications \
        --object-path /org/freedesktop/Notifications \
        --method org.freedesktop.Notifications.Notify \
        "AstroArch" 0 "/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" \
        "System Restore" "Restoration in progress... DO NOT interrupt." \
        [] '{"urgency": <byte 1>}' 0 | sed 's/(uint32 \([0-9]*\),)/\1/')

    # Run rsync (blocking)
    sudo rsync -aAXxh -x --delete "${EXCLUSIONS[@]}" "$ABS_DEST/" /
    RSYNC_RESULT=$?

    # FORCED CLOSURE using the retrieved ID
    if [ -n "$NOTIFY_ID" ]; then
        gdbus call --session --dest org.freedesktop.Notifications \
            --object-path /org/freedesktop/Notifications \
            --method org.freedesktop.Notifications.CloseNotification "$NOTIFY_ID" >/dev/null
    fi

    if [ $RSYNC_RESULT -eq 0 ]; then
        # SUCCESS
        for i in {10..1}; do
            notify-send "Restore Complete" "✅ Finished. Rebooting in $i seconds..." \
                --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" \
                -t 1000 --hint=int:transient:1
            sleep 1
        done
        sudo reboot
    else
        # ERROR
        notify-send "Restore FAILED" "❌ Error code: $RSYNC_RESULT." --icon="dialog-error" --urgency=critical -t 0
        kdialog --error "Restoration failed."
        exit 1
    fi
else
    # CONSOLE MODE
    echo -e "\e[32m🚀 Restoration in progress...\e[0m"
    sudo rsync -aAXxh -x --delete --info=progress2 "${EXCLUSIONS[@]}" "$ABS_DEST/" /
    RSYNC_RESULT=$?

    if [ $RSYNC_RESULT -eq 0 ]; then
        echo -e "\n\e[32m✅ Restore complete.\e[0m"
        for i in {10..1}; do
            echo -ne "Rebooting in $i seconds... \r"
            sleep 1
        done
        #sudo reboot
    else
        echo -e "\n\e[31m❌ ERROR: Restoration failed.\e[0m"
        exit 1
    fi
fi
