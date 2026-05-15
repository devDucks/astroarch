#!/bin/bash
export LC_ALL=C

# --- 1. INITIALIZATION ---
CONFIG_FILE="$HOME/.backup_dest"
DEFAULT_DEST="$HOME/backup"

# Detect GUI or SSH session
is_gui() { [[ -n "$DISPLAY" && -z "$SSH_CLIENT" ]]; }

# Update specific keys in the config file
update_config() { sed -i "s|^$1=.*|$1=\"$2\"|" "$CONFIG_FILE"; }

ask_valid_dest() {
    local PROMPT="$1"
    local DEFAULT="$2"
    local PATH_OK=false

    while [ "$PATH_OK" = false ]; do
        if is_gui; then
            DEST_PATH=$(kdialog --inputbox "$PROMPT" "$DEFAULT")
            [ -z "$DEST_PATH" ] && exit 0
        else
            read -p "$PROMPT (or Enter to quit): " DEST_PATH
            [ -z "$DEST_PATH" ] && exit 0
        fi

        [[ "$DEST_PATH" != */backup ]] && DEST_PATH="${DEST_PATH%/}/backup"

        if mkdir -p "$DEST_PATH" 2>/dev/null; then
            PATH_OK=true
        else
            MSG_PERM="⚠️ Cannot create \"$DEST_PATH\": permission denied."
            if is_gui; then
                kdialog --title "Permission Denied" --error "$MSG_PERM"
            else
                echo -e "$MSG_PERM"
            fi
        fi
    done
}

# --- CLEANING FEATURE ---
cleanup_canceled_backup() {
    local DEST="$1"
    # Deletes the corrupted folder (requires sudo because rsync preserves root permissions)
    if [[ "$DEST" == */backup ]] && [[ "$DEST" != "/backup" ]]; then
        sudo rm -rf "$DEST"
        rm -f "$CONFIG_FILE"
        MSG="⚠️ Backup canceled. Folder and config removed."
    else
        MSG="⚠️ Backup canceled. Folder NOT removed (security check failed)."
    fi
    if is_gui; then
        kdialog --title "Backup Aborted" --msgbox "$MSG"
    else
        echo -e "\e[31m$MSG\e[0m"
    fi
    exit 0
}

# ADAPTIVE CONFIRMATION FUNCTION
ask_confirmation() {
    local QUESTION="$1"
    if is_gui; then
        CHOICE=$(kdialog --combobox "$QUESTION" "Yes" "Yes, do not ask again" "No" "No, do not ask again" --default "Yes")
        case "$CHOICE" in
            "Yes, do not ask again") update_config "AUTO_CHOICE" "Yes"; AUTO_CHOICE="Yes" ;;
            "No") exit 0 ;;
            "No, do not ask again") update_config "AUTO_CHOICE" "Never"; exit 0 ;;
            "Yes") ;; # Continue
            *) exit 0 ;;
        esac
    else
        read -p "$QUESTION (y/n) " r; [[ ! "$r" =~ ^[Yy]$ ]] && exit 0
    fi
}

if [ ! -f "$CONFIG_FILE" ]; then
    # FIRST TIME INSTALLATION
    if is_gui; then
       kdialog --title "Backup Assistant" --msgbox "
                        <html>
                        <h2 style='color: #1d65af;'>This is your first backup</h2>
                        <p>Please select a folder. If the folder location does not have enough space, you will be asked to choose a different location.
                        <b>Note:</b> If the location is on the same drive, a <b>minimum of 64 GB</b> is required.</p>
                        <hr>
                        <p>You can choose from several options:</p>
                        <ul>
                        <li><b>Perform a backup:</b> (Yes)</li>
                        <li><b>Set up automatic backups:</b> (Yes, do not ask again)</li>
                        <li><b>Do not perform:</b> (No)</li>
                        <li><b>Cancel permanently:</b> (No, do not ask again)</li>
                        </ul>
                        <hr>
                        <p><small><i>To change default settings, edit: <code>\$HOME/.backup_dest</code> and set <code>AUTO_CHOICE=\"ask\"</code></i></small></p>
                        <p>Please note: if you cancel the backup while it is in progress, the backup folder and the configuration file will be deleted</p>
                        <p><b>The backup will take some time...</b></p>
                        </html>" 600 500
    fi

    # ask_valid_dest handles everything: prompt, validation, mkdir
    ask_valid_dest "First backup. Choose storage location:" "$DEFAULT_DEST"
    FIRST_BACKUP="yes"
    AUTO_CHOICE="Ask"

    cat << EOF > "$CONFIG_FILE"
DEST_PATH="$DEST_PATH"
FIRST_BACKUP="$FIRST_BACKUP"
AUTO_CHOICE="$AUTO_CHOICE"
EOF
else
    # EXISTING CONFIGURATION
    source "$CONFIG_FILE"

    # --- CASE: MISSING DIRECTORY ---
    if [ ! -d "$DEST_PATH" ]; then
        if is_gui; then
            kdialog --title "Destination Missing" --warningcontinuecancel "The location \"$DEST_PATH\" was not found." --continue-label "Change location" --cancel-label "Quit" || exit 0
            DEST_PATH=$(kdialog --inputbox "New location:" "$DEST_PATH")
            [ -z "$DEST_PATH" ] && exit 0
            ask_confirmation "Directory changed. Choose confirmation mode:"
        else
            echo "⚠️ The location \"$DEST_PATH\" was not found."
            read -p "New path (or Enter to quit): " DEST_PATH
            [ -z "$DEST_PATH" ] && exit 0
            ask_confirmation "New confirmation mode:"
        fi

        ask_valid_dest "New location:" "$DEST_PATH"
        update_config "DEST_PATH" "$DEST_PATH"
        update_config "AUTO_CHOICE" "$AUTO_CHOICE"
        SKIP_FINAL_PROMPT="true"
    fi
fi

# --- 2. AUTHENTICATION ---
if ! sudo -n true 2>/dev/null; then
    if is_gui; then
        PASS=$(kdialog --title "Authentication" --password "Enter your user password:")
        [ -z "$PASS" ] && exit 1
        echo "$PASS" | sudo -S -v &>/dev/null
        [ $? -ne 0 ] && kdialog --error "Incorrect password." && exit 1
        unset PASS
    else
        sudo -v || exit 1
    fi
fi
( while true; do sudo -n -v; sleep 60; kill -0 "$$" || exit; done 2>/dev/null ) &

# --- 3. DISK SPACE VALIDATION LOOP ---
VALID_SPACE=false
while [ "$VALID_SPACE" = false ]; do
    if ! mkdir -p "$DEST_PATH" 2>/dev/null; then
        MSG_PERM="⚠️ Cannot create folder \"$DEST_PATH\".\nPermission denied."
        if is_gui; then
            kdialog --title "Permission Denied" --warningcontinuecancel "$MSG_PERM" \
                --continue-label "Choose another location" --cancel-label "Abort" || exit 0
            DEST_PATH=$(kdialog --inputbox "New location:" "$DEFAULT_DEST")
            [ -z "$DEST_PATH" ] && exit 0
        else
            echo -e "$MSG_PERM"
            read -p "New path (or Enter to quit): " DEST_PATH
            [ -z "$DEST_PATH" ] && exit 0
        fi
        update_config "DEST_PATH" "$DEST_PATH"
        continue
    fi
    ABS_DEST=$(realpath "$DEST_PATH")
    EXCLUSIONS=(--exclude='/dev/*' --exclude='/proc/*' --exclude='/sys/*' --exclude='/tmp/*' --exclude='/run/*' --exclude='/mnt/*' --exclude='/media/*' --exclude='/lost+found/' --exclude='/boot/*' --exclude='*/thinclient_drives' --exclude='*/.gvfs' --exclude="$ABS_DEST")

    echo "Analyzing space on $ABS_DEST..."
    ROOT_SIZE=$(sudo -n env LC_ALL=C rsync -aAXHvx --delete --dry-run --stats "${EXCLUSIONS[@]}" / "$ABS_DEST" | grep "Total transferred file size" | awk '{print $5}' | tr -d ',.')
    [ -z "$ROOT_SIZE" ] && ROOT_SIZE=0
    AVAILABLE_SIZE=$(LC_ALL=C df --output=avail -B1 "$ABS_DEST" | tail -1 | tr -d ' ')

    TRANS_HUMAN=$(numfmt --to=iec-i --suffix=B $ROOT_SIZE)
    AVAIL_HUMAN=$(numfmt --to=iec-i --suffix=B $AVAILABLE_SIZE)

    if [ "$AVAILABLE_SIZE" -lt "$ROOT_SIZE" ]; then
        MSG_ERR="⚠️ Insufficient space on $ABS_DEST !\nRequired: $TRANS_HUMAN\nFree: $AVAIL_HUMAN"
        if is_gui; then
            kdialog --title "Insufficient Space" --warningcontinuecancel "$MSG_ERR" --continue-label "Change destination" --cancel-label "Abort" || exit 0
            DEST_PATH=$(kdialog --inputbox "New location:" "$DEFAULT_DEST")
            [ -z "$DEST_PATH" ] && exit 0
        else
            echo -e "$MSG_ERR"
            read -p "New path (or Enter to quit): " DEST_PATH
            [ -z "$DEST_PATH" ] && exit 0
        fi
        update_config "DEST_PATH" "$DEST_PATH"
    else
        VALID_SPACE=true
    fi
done

# --- 4. FIRST BACKUP LOGIC AND CHOICE ---
if [ "$(ls -A "$ABS_DEST" 2>/dev/null)" ]; then
    [[ "$FIRST_BACKUP" == "yes" ]] && update_config "FIRST_BACKUP" "no" && FIRST_BACKUP="no"
else
    [[ "$FIRST_BACKUP" == "no" ]] && update_config "FIRST_BACKUP" "yes" && FIRST_BACKUP="yes"
fi

[[ "$AUTO_CHOICE" == "Never" ]] && exit 0
if [[ "$AUTO_CHOICE" == "Ask" && "$SKIP_FINAL_PROMPT" != "true" ]]; then
    ask_confirmation "Start backup?"
fi

if [[ "$FIRST_BACKUP" == "yes" ]]; then
    MSG="Note: First full backup to $ABS_DEST ($TRANS_HUMAN)."
    if is_gui; then kdialog --msgbox "$MSG"; else echo -e "$MSG"; fi
fi

# --- 5. EXECUTION ---
if is_gui; then

    # --- D-Bus session detection ---
    # If DBUS_SESSION_BUS_ADDRESS is not set (e.g. launched from Calamares at session start
    # before the bus is ready), build the standard systemd socket path for user astronaut.
    if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
        USER_ID=$(id -u astronaut 2>/dev/null || id -u)
        export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${USER_ID}/bus"
    fi

    # Wait until the D-Bus socket is actually available (max 30s).
    # This handles the race condition where Calamares autostart launches
    # before the KDE session bus is fully initialised.
    DBUS_SOCKET=$(echo "$DBUS_SESSION_BUS_ADDRESS" | sed 's|unix:path=||')
    WAIT=0
    while [ ! -S "$DBUS_SOCKET" ] && [ "$WAIT" -lt 30 ]; do
        sleep 1
        ((WAIT++))
    done

    if [ ! -S "$DBUS_SOCKET" ]; then
        # Fallback: D-Bus still not available after 30s → run in terminal mode
        echo "⚠️ D-Bus session bus not available after 30s. Falling back to terminal mode."
        sudo -n rsync -aAXHxh --delete --no-inc-recursive --info=progress2 "${EXCLUSIONS[@]}" / "$ABS_DEST"
    else
        dbus_ref=$(kdialog --progressbar "Initializing backup..." 100)
        sudo -n rsync -aAXHxh --delete --no-inc-recursive --info=progress2 "${EXCLUSIONS[@]}" / "$ABS_DEST" 2>/dev/null | \
        stdbuf -oL tr '\r' '\n' | grep --line-buffered -oP '[0-9]+(?=%)' | \
        while read -r percent; do
            ((count++))
            if (( count % 5 == 0 )); then
                # IF CANCELED BY THE USER
                if ! qdbus6 $dbus_ref >/dev/null 2>&1; then
                    sudo pkill -f "rsync.*$ABS_DEST"
                    cleanup_canceled_backup "$ABS_DEST"
                fi
                qdbus6 $dbus_ref setLabelText "Copying: $percent% of $TRANS_HUMAN"
                qdbus6 $dbus_ref Set "" value "$percent"
            fi
        done
        qdbus6 $dbus_ref close 2>/dev/null
        notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 "✅ Backup completed."
    fi
else
    sudo -n rsync -aAXHxh --delete --no-inc-recursive --info=progress2 "${EXCLUSIONS[@]}" / "$ABS_DEST"
fi

update_config "FIRST_BACKUP" "no"
