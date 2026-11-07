#!/bin/bash
# astroarch-prefill.sh [system|network]
#
# Applies the optional setup file of the boot partition (/boot/astroarch-setup.txt,
# template in configs/astroarch-setup.txt) at the first boot. Run as root by two units:
#
#   system   astroarch-prefill.service, early (before logind, so before the desktop,
#            the kiosk and every user manager): reads and checks the whole file, applies
#            hostname, time zone, language, keyboard, Wi-Fi country and passwords, removes
#            every password from the file at once, and hands the Wi-Fi network and the
#            hotspot password to the second unit through /run (RAM only)
#   network  astroarch-prefill-network.service, after create_ap.service has made the
#            field hotspot: sets the hotspot password, saves the home Wi-Fi and joins it
#
# Each setting is applied on its own: one that fails does not stop the others. What was
# applied is listed, without values, in /var/lib/astroarch/prefill-applied (read by the
# AstroArch Control Center, which shows those steps as "Set before first boot") and in a
# note added at the end of the setup file. Passwords are never logged nor kept.
#
# Testing: PREFILL_DRY_RUN=1 prints the commands that change the system instead of
# running them (no root needed); PREFILL_FILE, PREFILL_RECORD and PREFILL_RUN_DIR move
# the files it reads and writes, e.g. to /var/tmp.

set -u
export LC_ALL=C

SETUP_FILE=${PREFILL_FILE:-/boot/astroarch-setup.txt}
RECORD=${PREFILL_RECORD:-/var/lib/astroarch/prefill-applied}
RUN_DIR=${PREFILL_RUN_DIR:-/run/astroarch-prefill}
DRY_RUN=${PREFILL_DRY_RUN:-0}
# The main user of the image (uid 1000, "astronaut") and its kiosk user
MAIN_USER=${PREFILL_USER:-$(id -nu 1000 2>/dev/null)}
KIOSK_USER=$MAIN_USER-kiosk
# Made by scripts/create_ap.sh
HOTSPOT_CONNECTION=astroarch-hotspot

KNOWN_KEYS=" hostname wifi_ssid wifi_password wifi_country language keyboard keyboard_variant timezone password hotspot_password "

declare -A VALUE=()
declare -a LINES=()
declare -a NOTE=()          # lines of the note added to the setup file
declare -a SECRETS=()       # values never printed, even in dry-run
APPLIED=""                  # items applied, one per line
REASON=""                   # why the last item was not applied

log() {
    echo "astroarch-prefill: $*" >&2
}

# Runs a command that changes the system; in dry-run prints it, secrets masked
run() {
    if [[ $DRY_RUN == 1 ]]; then
        local arg out=()
        for arg in "$@"; do
            for secret in "${SECRETS[@]}"; do
                [[ $arg == "$secret" ]] && arg="<secret>"
            done
            out+=("$arg")
        done
        echo "DRY-RUN: ${out[*]}" >&2
        return 0
    fi
    "$@"
}

# Same, for a command reading a secret on its standard input (kept out of the
# command line, which other processes can read)
run_stdin() {
    if [[ $DRY_RUN == 1 ]]; then
        cat >/dev/null
        echo "DRY-RUN: $* <secret on stdin>" >&2
        return 0
    fi
    "$@"
}

# Writes CONTENT to a system FILE
write_file() {
    if [[ $DRY_RUN == 1 ]]; then
        echo "DRY-RUN: write $1: $2" >&2
        return 0
    fi
    printf '%s\n' "$2" > "$1"
}

# ------------------------------------------------------------------ setup file

# Reads the setup file into LINES (raw, line endings kept) and VALUE (key -> value).
# Never sourced: each line is matched as key=value. Handles a UTF-8 BOM, CRLF line
# endings (Windows editors) and UTF-16 (converted to UTF-8)
read_setup_file() {
    local file=$1 text n=0 line key value
    if [[ $(head -c 2 "$file" | od -An -tx1 | tr -d ' ') == fffe || $(head -c 2 "$file" | od -An -tx1 | tr -d ' ') == feff ]]; then
        text=$(iconv -f UTF-16 -t UTF-8 "$file") || return 1
    else
        text=$(cat "$file") || return 1
    fi
    mapfile -t LINES <<< "$text"
    for line in "${LINES[@]}"; do
        n=$((n + 1))
        line=${line%$'\r'}
        [[ $n == 1 ]] && line=${line#$'\xef\xbb\xbf'}
        [[ $line =~ ^[[:space:]]*(#|\;|$) ]] && continue
        if [[ ! $line =~ ^[[:space:]]*([A-Za-z_]+)[[:space:]]*=(.*)$ ]]; then
            log "line $n not understood, skipped"
            continue
        fi
        key=${BASH_REMATCH[1],,}
        value=${BASH_REMATCH[2]}
        # Surrounding spaces, then surrounding quotes
        value=${value#"${value%%[![:space:]]*}"}
        value=${value%"${value##*[![:space:]]}"}
        if [[ $value =~ ^\"(.*)\"$ || $value =~ ^\'(.*)\'$ ]]; then
            value=${BASH_REMATCH[1]}
        fi
        if [[ $KNOWN_KEYS != *" $key "* ]]; then
            log "line $n: unknown setting \"$key\", skipped"
            continue
        fi
        [[ -n ${VALUE[$key]:-} ]] && log "line $n: \"$key\" set twice, the last one counts"
        VALUE[$key]=$value
    done
    [[ -n ${VALUE[wifi_password]:-} ]] && SECRETS+=("${VALUE[wifi_password]}")
    [[ -n ${VALUE[password]:-} ]] && SECRETS+=("${VALUE[password]}")
    [[ -n ${VALUE[hotspot_password]:-} ]] && SECRETS+=("${VALUE[hotspot_password]}")
    return 0
}

# A key that holds a password, even a misspelled one ("pasword", "wifi_psk", "pwd")
# (a glob: a regex match would overwrite BASH_REMATCH of the caller)
is_secret_key() {
    case ${1,,} in
        *pass* | *pasw* | *paws* | *pwd* | *psk*) return 0 ;;
    esac
    return 1
}

# Rewrites the setup file without any password value, keeping everything else
# (comments, BOM, line endings). The old bytes are first overwritten in place, so the
# passwords do not stay in the free space of the FAT partition. Returns 2 when the file
# holds no password
wipe_passwords() {
    local file=$1 text="" line eol bom i size found=0
    for i in "${!LINES[@]}"; do
        line=${LINES[$i]}
        eol=""
        [[ $line == *$'\r' ]] && eol=$'\r' && line=${line%$'\r'}
        bom=""
        [[ $i == 0 && $line == $'\xef\xbb\xbf'* ]] && bom=$'\xef\xbb\xbf' && line=${line#"$bom"}
        if [[ $line =~ ^([[:space:]]*([A-Za-z_]+)[[:space:]]*=)(.*)$ ]] && is_secret_key "${BASH_REMATCH[2]}" \
            && [[ -n ${BASH_REMATCH[3]//[[:space:]]/} ]]; then
            line=${BASH_REMATCH[1]}
            found=1
        fi
        text+="$bom$line$eol"$'\n'
    done
    [[ $found == 1 ]] || return 2
    size=$(stat -c %s "$file") || return 1
    if [[ $size -gt 0 ]]; then
        dd if=/dev/zero of="$file" bs="$size" count=1 conv=notrunc,fsync status=none || return 1
    fi
    printf '%s' "$text" > "$file" && sync "$file"
}

# Adds the NOTE lines at the end of the setup file, with its line endings
append_note() {
    local file=$1 eol="" line
    [[ ${#NOTE[@]} -gt 0 ]] || return 0
    grep -q $'\r' "$file" 2>/dev/null && eol=$'\r'
    for line in "${NOTE[@]}"; do
        printf '%s%s\n' "$line" "$eol"
    done >> "$file"
    sync "$file"
}

# Records one item as applied (system record, read by the Control Center)
record() {
    APPLIED+="$1"$'\n'
    printf '%s\n' "$1" >> "$RECORD"
}

# Applies one item: apply ITEM FUNCTION
apply() {
    local item=$1
    REASON=""
    if "$2"; then
        record "$item"
        NOTE+=("# Applied: $item${REASON:+ ($REASON)}")
        log "$item: applied${REASON:+ ($REASON)}"
    else
        NOTE+=("# Not applied: $item ($REASON)")
        log "$item: not applied: $REASON"
    fi
}

# ------------------------------------------------------------------ checks

valid_hostname() {
    [[ $1 =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]]
}

# A WPA password: 8 to 63 printable ASCII characters, or 64 hexadecimal digits
valid_wpa_password() {
    [[ $1 =~ ^[\ -~]{8,63}$ || $1 =~ ^[0-9A-Fa-f]{64}$ ]]
}

# Login password: no control characters (no tab, no newline)
valid_user_password() {
    [[ -n $1 && ! $1 =~ [[:cntrl:]] && ${#1} -le 200 ]]
}

# SSID: 1 to 32 bytes, no control characters
valid_ssid() {
    [[ -n $1 && ${#1} -le 32 && ! $1 =~ [[:cntrl:]] ]]
}

# Country code known to the time zone database (also the Wi-Fi regulatory codes)
valid_country() {
    [[ $1 =~ ^[A-Z]{2}$ ]] && grep -q "^$1"$'\t' /usr/share/zoneinfo/iso3166.tab
}

valid_timezone() {
    [[ $1 =~ ^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*$ ]] && timedatectl list-timezones 2>/dev/null | grep -qxF "$1"
}

# Keyboard layout (and variant) known to XKB
valid_keyboard() {
    [[ $1 =~ ^[a-z]{2,8}$ ]] || return 1
    [[ -z $2 || $2 =~ ^[a-z0-9_-]{1,32}$ ]] || return 1
    awk -v l="$1" -v v="$2" '
        /^! layout/ { s = "l"; next }
        /^! variant/ { s = "v"; next }
        /^!/ { s = ""; next }
        s == "l" && $1 == l { fl = 1 }
        s == "v" && $1 == v && $2 == l ":" { fv = 1 }
        END { exit !(fl && (v == "" || fv)) }' /usr/share/X11/xkb/rules/base.lst
}

# ------------------------------------------------------------------ system phase

do_hostname() {
    local name=${VALUE[hostname],,}
    valid_hostname "$name" || { REASON="use lowercase letters, digits and -, up to 63 characters"; return 1; }
    run hostnamectl set-hostname "$name" || { REASON="hostnamectl failed"; return 1; }
    # The line of the image in /etc/hosts (astroarch_build.sh)
    run sed -i -E "s/^(127\.0\.1\.1[[:space:]]+).*/\1$name/" /etc/hosts || true
}

do_timezone() {
    local zone=${VALUE[timezone]}
    valid_timezone "$zone" || { REASON="unknown time zone"; return 1; }
    run timedatectl set-timezone "$zone" || { REASON="timedatectl failed"; return 1; }
}

# As the Language module of astroarch-tools (persist_locale): enable the locale in
# /etc/locale.gen, locale-gen, localectl set-locale
do_language() {
    local code=${VALUE[language]} base variant gen_re target
    if [[ ! $code =~ ^([a-z]{2,3}_[A-Z]{2})(\.(UTF-8|utf8|UTF8|utf-8))?(@[a-z]+)?$ ]]; then
        REASON="write it as it_IT, de_DE, en_GB..."
        return 1
    fi
    base=${BASH_REMATCH[1]}
    variant=${BASH_REMATCH[4]}
    # The name in locale.gen has ".UTF-8" or not: "it_IT.UTF-8 UTF-8", "hi_IN UTF-8"
    gen_re="$base(\.UTF-8)?$variant"
    if ! grep -qE "^$gen_re UTF-8\$" /usr/share/i18n/SUPPORTED; then
        REASON="not a language of this system"
        return 1
    fi
    target=$base.UTF-8$variant
    run sed -i -E "s/^#[[:space:]]*(${gen_re}[[:space:]]+UTF-8)/\1/" /etc/locale.gen || { REASON="locale.gen not changed"; return 1; }
    if [[ $DRY_RUN != 1 ]] && ! grep -qE "^${gen_re}[[:space:]]+UTF-8" /etc/locale.gen; then
        grep -E "^$gen_re UTF-8\$" /usr/share/i18n/SUPPORTED | head -n1 >> /etc/locale.gen
    fi
    run locale-gen >/dev/null || { REASON="locale-gen failed"; return 1; }
    run localectl set-locale "LANG=$target" || { REASON="localectl failed"; return 1; }
}

# localectl set-x11-keymap: KWin reads it (locale1) while the user has chosen no layout
do_keyboard() {
    local layout=${VALUE[keyboard],,} variant=${VALUE[keyboard_variant]:-}
    variant=${variant,,}
    valid_keyboard "$layout" "$variant" || { REASON="unknown keyboard layout or variant"; return 1; }
    if [[ -n $variant ]]; then
        run localectl set-x11-keymap "$layout" "" "$variant"
    else
        run localectl set-x11-keymap "$layout"
    fi || { REASON="localectl failed"; return 1; }
}

# Wi-Fi regulatory domain: now with iw, at every boot through the cfg80211 module
do_wifi_country() {
    local country=${VALUE[wifi_country]^^}
    valid_country "$country" || { REASON="not a two-letter country code"; return 1; }
    write_file /etc/modprobe.d/astroarch-wifi-country.conf "options cfg80211 ieee80211_regdom=$country" \
        || { REASON="cannot write modprobe.d"; return 1; }
    run iw reg set "$country" 2>/dev/null || true
}

# Login password of the main user and of its kiosk user (the kiosk remote desktop asks
# for it), and Samba password of the main user: the image sets all three to the same
# default, a new password left out of one of them would leave that door open
do_password() {
    local password=${VALUE[password]} user
    valid_user_password "$password" || { REASON="no tabs or control characters, up to 200 characters"; return 1; }
    [[ -n $MAIN_USER ]] || { REASON="no main user"; return 1; }
    for user in "$MAIN_USER" "$KIOSK_USER"; do
        id "$user" >/dev/null 2>&1 || continue
        printf '%s:%s\n' "$user" "$password" | run_stdin chpasswd || { REASON="chpasswd failed for $user"; return 1; }
    done
    if command -v smbpasswd >/dev/null; then
        printf '%s\n%s\n' "$password" "$password" | run_stdin smbpasswd -s -a "$MAIN_USER" >/dev/null \
            || { REASON="login changed, shared folders password not changed"; return 1; }
    fi
}

phase_system() {
    local key handoff=""
    if [[ ! -f $SETUP_FILE ]]; then
        log "no $SETUP_FILE, nothing to do"
        return 0
    fi
    if [[ -e $RECORD ]]; then
        log "$RECORD exists: the setup file was already applied"
        return 0
    fi
    read_setup_file "$SETUP_FILE" || { log "cannot read $SETUP_FILE"; return 1; }

    mkdir -p "$(dirname "$RECORD")"
    printf '# Settings of %s applied at the first boot (%s)\n' "$SETUP_FILE" "$(date -Iseconds)" > "$RECORD"
    chmod 644 "$RECORD"
    NOTE+=("# ---- First boot of AstroArch, $(date '+%Y-%m-%d %H:%M') ----")

    # Every password leaves the file before anything else is done
    wipe_passwords "$SETUP_FILE"
    case $? in
        0) NOTE+=("# The passwords were removed from this file.") ;;
        1) log "the passwords could not be removed from $SETUP_FILE" ;;
    esac

    [[ -n ${VALUE[hostname]:-} ]] && apply hostname do_hostname
    [[ -n ${VALUE[timezone]:-} ]] && apply timezone do_timezone
    [[ -n ${VALUE[language]:-} ]] && apply language do_language
    if [[ -n ${VALUE[keyboard]:-} ]]; then
        apply keyboard do_keyboard
    elif [[ -n ${VALUE[keyboard_variant]:-} ]]; then
        NOTE+=("# Not applied: keyboard_variant (no keyboard layout)")
    fi
    [[ -n ${VALUE[wifi_country]:-} ]] && apply wifi_country do_wifi_country
    [[ -n ${VALUE[password]:-} ]] && apply password do_password

    # Wi-Fi and hotspot: checked now, applied once the hotspot exists
    if [[ -n ${VALUE[hotspot_password]:-} ]]; then
        if valid_wpa_password "${VALUE[hotspot_password]}"; then
            handoff+="hotspot_password=${VALUE[hotspot_password]}"$'\n'
        else
            NOTE+=("# Not applied: hotspot_password (8 to 63 characters, letters, digits and symbols)")
            log "hotspot_password: not applied: not a valid Wi-Fi password"
        fi
    fi
    if [[ -n ${VALUE[wifi_ssid]:-} ]]; then
        if ! valid_ssid "${VALUE[wifi_ssid]}"; then
            NOTE+=("# Not applied: wifi (network name of 1 to 32 characters)")
            log "wifi: not applied: not a valid network name"
        elif [[ -n ${VALUE[wifi_password]:-} ]] && ! valid_wpa_password "${VALUE[wifi_password]}"; then
            NOTE+=("# Not applied: wifi (password of 8 to 63 characters)")
            log "wifi: not applied: not a valid Wi-Fi password"
        else
            handoff+="wifi_ssid=${VALUE[wifi_ssid]}"$'\n'"wifi_password=${VALUE[wifi_password]:-}"$'\n'
        fi
    elif [[ -n ${VALUE[wifi_password]:-} ]]; then
        NOTE+=("# Not applied: wifi (password without a network name)")
    fi
    if [[ -n $handoff ]]; then
        # RAM only, root only: gone at the next boot in any case
        (umask 077 && mkdir -p "$RUN_DIR" && printf '%s' "$handoff" > "$RUN_DIR/network") \
            || log "cannot hand the Wi-Fi settings to the network phase"
    fi
    [[ ${#NOTE[@]} == 1 && -z $handoff ]] && NOTE+=("# Nothing was set in this file.")
    handoff=""

    append_note "$SETUP_FILE" || log "cannot add the note to $SETUP_FILE"
    for key in "${!VALUE[@]}"; do VALUE[$key]=""; done
    return 0
}

# ------------------------------------------------------------------ network phase

hotspot_active() {
    nmcli -t -f NAME connection show --active 2>/dev/null | grep -qxF "$HOTSPOT_CONNECTION"
}

do_hotspot_password() {
    local password=${VALUE[hotspot_password]}
    if ! nmcli -t -f NAME connection show 2>/dev/null | grep -qxF "$HOTSPOT_CONNECTION"; then
        REASON="no field hotspot on this system"
        return 1
    fi
    run nmcli connection modify "$HOTSPOT_CONNECTION" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$password" \
        || { REASON="nmcli failed"; return 1; }
    # The new password is used from the next start of the hotspot
    if hotspot_active; then
        run nmcli -w 20 connection up "$HOTSPOT_CONNECTION" >/dev/null || true
    fi
}

# Saved with the default priority (0), above the hotspot (-100): at each boot the home
# network is joined when it is in range, else the hotspot starts
do_wifi() {
    local ssid=${VALUE[wifi_ssid]} password=${VALUE[wifi_password]:-} args
    args=(connection add type wifi con-name "$ssid" ssid "$ssid" connection.autoconnect yes)
    [[ -n $password ]] && args+=(wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$password")
    run nmcli "${args[@]}" >/dev/null || { REASON="nmcli failed"; return 1; }
    # create_ap.sh has just started the hotspot on the same Wi-Fi chip: join the home
    # network now, or start the hotspot again when it is not in range
    if run nmcli -w 45 connection up "$ssid" >/dev/null; then
        REASON="connected"
    else
        REASON="saved; not in range at the first boot, or wrong password"
        hotspot_active || run nmcli -w 20 connection up "$HOTSPOT_CONNECTION" >/dev/null || true
    fi
    return 0
}

phase_network() {
    local file=$RUN_DIR/network line
    [[ -f $file ]] || { log "nothing to apply"; return 0; }
    while IFS= read -r line; do
        VALUE[${line%%=*}]=${line#*=}
    done < "$file"
    [[ -n ${VALUE[wifi_password]:-} ]] && SECRETS+=("${VALUE[wifi_password]}")
    [[ -n ${VALUE[hotspot_password]:-} ]] && SECRETS+=("${VALUE[hotspot_password]}")
    rm -f "$file"
    rmdir "$RUN_DIR" 2>/dev/null

    [[ -n ${VALUE[hotspot_password]:-} ]] && apply hotspot_password do_hotspot_password
    [[ -n ${VALUE[wifi_ssid]:-} ]] && apply wifi do_wifi
    [[ -f $SETUP_FILE ]] && { append_note "$SETUP_FILE" || log "cannot add the note to $SETUP_FILE"; }
    for line in "${!VALUE[@]}"; do VALUE[$line]=""; done
    return 0
}

case ${1:-system} in
    system) phase_system ;;
    network) phase_network ;;
    *) echo "usage: $0 [system|network]" >&2; exit 2 ;;
esac
