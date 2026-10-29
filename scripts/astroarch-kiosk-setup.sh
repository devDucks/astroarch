#!/usr/bin/env bash
# astroarch-kiosk-setup: the profiles of the kiosk desktop (shared with the main user or
# its own) and the apps it opens. The back end of the Kiosk page of the AstroArch
# Control Center, which runs as either user:
#
#   status profiles   (any user, read-only) one line:
#                     shared | separate | separate own | mixed
#                     ("own": the kiosk has KStars, INDI or PHD2 settings of its own)
#   status apps       (any user, read-only) one line, a JSON array of the apps of
#                     configs/kiosk/apps.list: id, name, installed, desktop, menu, start, watch
#   apply [--profiles shared|separate] [--app ID=FLAGS]...    (root, through pkexec)
#                     FLAGS: the options to turn on, comma separated, the others are
#                     turned off: desktop (icon), menu, start (with the kiosk), watch
#                     (reopen when it closes). Apps not named are left as they are.
#
# Installed as /usr/lib/astroarch/astroarch-kiosk-setup, the path that the polkit action
# org.astroarch.kiosk.setup names: re-install it when this file changes.
#
# Shared profiles: in the kiosk home, links to the main user's KStars data and settings,
# INDI driver settings and PHD2 dark library. PHD2 replaces ~/.PHDGuidingV2 at every
# save, which would turn a link into a file of its own: that file is a copy, kept in
# step by astroarch-kiosk-phd2-sync.path in the kiosk user manager. What the kiosk had
# before is moved aside, never deleted, and put back when the profiles are separated
# again. KStars or PHD2 must be closed in the kiosk to switch.
#
# Exit codes: 0 done, 2 wrong arguments, 3 users not found, 4 KStars or PHD2 open in
# the kiosk (nothing changed), 5 some changes failed (said on stderr)

set -u
export LC_ALL=C

# Only root can set these (pkexec starts the helper with a clean environment): for tests
KIOSK_USER=${ASTROARCH_KIOSK_USER:-astronaut-kiosk}
MAIN_USER=${ASTROARCH_MAIN_USER:-$(getent passwd 1000 | cut -d: -f1)}

# Shared as links, relative to the homes
SHARED_LINKS=(.local/share/kstars .config/kstarsrc .indi .phd2)
# Shared as a copy kept in step (see above)
SYNCED_FILES=(.PHDGuidingV2)
SYNC_UNITS=(astroarch-kiosk-phd2-sync.path astroarch-kiosk-phd2-sync.service)
# Apps that must be closed in the kiosk to switch the profiles
PROFILE_APPS=(kstars phd2.bin)

TMPFILES=/etc/tmpfiles.d/astroarch-kiosk-profiles.conf
OVERRIDE_MARK="X-AstroArch-Kiosk=shared-profiles"

MAIN_HOME=$(getent passwd "$MAIN_USER" | cut -d: -f6)
KIOSK_HOME=$(getent passwd "$KIOSK_USER" | cut -d: -f6)
if [[ -z $MAIN_HOME || -z $KIOSK_HOME ]]; then
    echo "Users $MAIN_USER and $KIOSK_USER not found" >&2
    exit 3
fi
MAIN_GROUP=$(id -gn "$MAIN_USER")

REPO=$MAIN_HOME/.astroarch
APPS_LIST=$REPO/configs/kiosk/apps.list
APP_SCRIPT=$REPO/scripts/astroarch-kiosk-app.sh
MENU_FILE=$KIOSK_HOME/.config/menus/plasma-applications.menu
UNIT_DIR=$KIOSK_HOME/.config/systemd/user
DESKTOP_DIR=$KIOSK_HOME/Desktop
OVERRIDE_DIR=$KIOSK_HOME/.local/share/applications
ASIDE_PARENT=$KIOSK_HOME/.local/share/astroarch

FAILED=0
fail() {
    echo "$*" >&2
    FAILED=1
}

# Run from / : the users may not enter the caller's folder
cd / || exit 3
as_kiosk() { runuser -u "$KIOSK_USER" -- "$@"; }
as_main() { runuser -u "$MAIN_USER" -- "$@"; }

# Lines of apps.list as "id|name|desktop file|command|process", checked: they are
# read as root from a file of the main user
apps() {
    grep -v '^[[:space:]]*#' "$APPS_LIST" 2>/dev/null \
        | grep -E '^[a-z0-9-]+\|[^|"\\]+\|[A-Za-z0-9._-]+\.desktop\|[^|]+\|[A-Za-z0-9._-]*$'
}

# ---------------------------------------------------------------------- profiles

is_shared_link() {
    [[ -L $KIOSK_HOME/$1 && $(readlink "$KIOSK_HOME/$1") == "$MAIN_HOME/$1" ]]
}

sync_enabled() {
    [[ -L $UNIT_DIR/default.target.wants/${SYNC_UNITS[0]} ]]
}

# The kiosk has settings of its own (not links): what moving them aside would keep
has_own_profiles() {
    local p
    for p in .config/kstarsrc .local/share/kstars/userdb.sqlite .PHDGuidingV2; do
        [[ -s $KIOSK_HOME/$p && ! -L $KIOSK_HOME/$p ]] && ! is_shared_link "$p" && return 0
    done
    [[ -d $KIOSK_HOME/.indi && ! -L $KIOSK_HOME/.indi && -n $(ls -A "$KIOSK_HOME/.indi" 2>/dev/null) ]]
}

profiles_state() {
    local p linked=0 total=$((${#SHARED_LINKS[@]} + 1))
    for p in "${SHARED_LINKS[@]}"; do
        is_shared_link "$p" && linked=$((linked + 1))
    done
    sync_enabled && linked=$((linked + 1))
    # Shared, but the group rights were not set: apply again
    ((linked == total)) && [[ ! -f $TMPFILES ]] && linked=$((linked - 1))
    if ((linked == total)); then
        echo shared
    elif ((linked == 0)); then
        has_own_profiles && echo "separate own" || echo separate
    else
        echo mixed
    fi
}

# Newest folder of profiles moved aside, if any
latest_aside() {
    ls -1dt "$ASIDE_PARENT"/kiosk-profiles-* 2>/dev/null | head -n1
}

# Files the main user and the kiosk both write stay writable by both: group rw, new
# files keep the group (setgid folders) and get group rw whatever the umask of the app
# (default ACL, from a tmpfiles.d file so that it is also set at boot on an image built
# where ACLs are not supported)
open_to_group() {
    local p target lines=()
    for p in "${SHARED_LINKS[@]}" "${SYNCED_FILES[@]}"; do
        target=$MAIN_HOME/$p
        # Never through a link (the kiosk can write in ~/.config and ~/.local), and as
        # the owner: root changes nothing the main user could not
        [[ -e $target && ! -L $target ]] || continue
        # What the kiosk wrote there is the kiosk's, already group writable (default ACL)
        as_main find "$target" -user "$MAIN_USER" ! -type l -exec chmod g+rwX {} + \
            || fail "Cannot open $target to the group"
        if [[ -d $target ]]; then
            as_main find "$target" -user "$MAIN_USER" -type d -exec chmod g+s {} + \
                || fail "Cannot set the group of new files in $target"
            lines+=("A+ $target - - - - default:group::rwx,default:mask::rwx")
        elif [[ $p == .config/kstarsrc ]]; then
            # KConfig saves kstarsrc with a lock file next to it. Never the home itself:
            # sshd and zsh refuse a group-writable home
            as_main chmod g+rwx "$MAIN_HOME/.config" || fail "Cannot open $MAIN_HOME/.config to the group"
        fi
    done
    {
        echo "# Written by astroarch-kiosk-setup while the kiosk shares the profiles of $MAIN_USER:"
        echo "# what either user writes in them stays writable by both"
        printf '%s\n' "${lines[@]}"
    } > "$TMPFILES"
    # Not supported in a container build: the file applies at the next boot
    systemd-tmpfiles --create "$TMPFILES" 2>/dev/null || true
}

# One run of the PHD2 sync, as the kiosk user
run_sync() {
    runuser -u "$KIOSK_USER" -- env HOME="$KIOSK_HOME" ASTROARCH_MAIN_USER="$MAIN_USER" \
        "$REPO/scripts/kiosk-phd2-sync.sh" || fail "Cannot bring the PHD2 settings in step"
}

enable_sync() {
    local unit
    as_kiosk mkdir -p "$UNIT_DIR/default.target.wants" || fail "Cannot create $UNIT_DIR"
    for unit in "${SYNC_UNITS[@]}"; do
        as_kiosk ln -sfn "/etc/systemd/user/$unit" "$UNIT_DIR/default.target.wants/$unit" \
            || fail "Cannot enable $unit"
    done
}

disable_sync() {
    local unit
    for unit in "${SYNC_UNITS[@]}"; do
        rm -f "$UNIT_DIR/default.target.wants/$unit"
    done
    systemctl --user -M "$KIOSK_USER@" stop "${SYNC_UNITS[@]}" 2>/dev/null
}

share_profiles() {
    local p k m aside=""
    # The links give the kiosk the rights of the main user's group
    if ! id -nG "$KIOSK_USER" | tr ' ' '\n' | grep -qx "$MAIN_GROUP"; then
        fail "$KIOSK_USER is not in the group $MAIN_GROUP"
        return
    fi
    # Something to link to: an empty file or folder when the main user has none yet
    for p in "${SHARED_LINKS[@]}" "${SYNCED_FILES[@]}"; do
        m=$MAIN_HOME/$p
        [[ -e $m ]] && continue
        as_main mkdir -p "$(dirname "$m")" || fail "Cannot create $(dirname "$m")"
        case $p in
            .config/kstarsrc | .PHDGuidingV2) as_main touch "$m" ;;
            *) as_main mkdir -p "$m" ;;
        esac || fail "Cannot create $m"
    done
    open_to_group
    for p in "${SHARED_LINKS[@]}" "${SYNCED_FILES[@]}"; do
        k=$KIOSK_HOME/$p
        m=$MAIN_HOME/$p
        is_shared_link "$p" && continue
        case " ${SYNCED_FILES[*]} " in
            *" $p "*)
                # Already shared: bring both copies in step, nothing to move aside
                if sync_enabled && [[ -f $k && ! -L $k ]]; then
                    run_sync
                    continue
                fi
                [[ -f $k && ! -L $k ]] && cmp -s "$k" "$m" && continue ;;
        esac
        # What the kiosk had is moved aside, kept until the profiles are separated again
        if [[ -e $k || -L $k ]]; then
            if [[ -z $aside ]]; then
                aside=$ASIDE_PARENT/kiosk-profiles-$(date +%F)
                [[ -e $aside ]] && aside=$aside-$(date +%H%M%S)
            fi
            as_kiosk mkdir -p "$aside/$(dirname "$p")" && as_kiosk mv "$k" "$aside/$p" \
                || { fail "Cannot move $k aside"; continue; }
        fi
        as_kiosk mkdir -p "$(dirname "$k")" || fail "Cannot create $(dirname "$k")"
        case " ${SYNCED_FILES[*]} " in
            *" $p "*) as_kiosk cp --preserve=timestamps "$m" "$k" ;;
            *) as_kiosk ln -s "$m" "$k" ;;
        esac || fail "Cannot share $p"
    done
    enable_sync
    [[ -n $aside ]] && echo "ASIDE:$aside"
}

separate_profiles() {
    local p k aside
    # Kiosk PHD2 changes not copied yet reach the main user first
    sync_enabled && run_sync
    disable_sync
    rm -f "$TMPFILES"
    for p in "${SHARED_LINKS[@]}"; do
        is_shared_link "$p" && { rm -f "$KIOSK_HOME/$p" || fail "Cannot remove the link $KIOSK_HOME/$p"; }
    done
    aside=$(latest_aside)
    for p in "${SYNCED_FILES[@]}"; do
        k=$KIOSK_HOME/$p
        # The copy of the main user's file goes (the main user keeps it), or makes room
        # for the kiosk's own file moved aside
        if [[ -n $aside && -e $aside/$p ]] || cmp -s "$k" "$MAIN_HOME/$p"; then
            rm -f "$k"
        fi
    done
    # Back what the kiosk had before sharing
    if [[ -n $aside ]]; then
        for p in "${SHARED_LINKS[@]}" "${SYNCED_FILES[@]}"; do
            k=$KIOSK_HOME/$p
            [[ -e $aside/$p || -L $aside/$p ]] || continue
            [[ -e $k || -L $k ]] && continue
            as_kiosk mkdir -p "$(dirname "$k")" && as_kiosk mv "$aside/$p" "$k" || fail "Cannot put back $k"
        done
        find "$aside" -depth -type d -empty -delete 2>/dev/null
        [[ -e $aside ]] && echo "KEPT:$aside"
    fi
    # Starting afresh: plate solving still finds the index files of the main user
    k=$KIOSK_HOME/.local/share/kstars
    if [[ ! -e $k/astrometry && -d $MAIN_HOME/.local/share/kstars/astrometry ]]; then
        as_kiosk mkdir -p "$k" && as_kiosk ln -s "$MAIN_HOME/.local/share/kstars/astrometry" "$k/astrometry" \
            || fail "Cannot link the plate-solving index files"
    fi
}

# ---------------------------------------------------------------------- apps

desktop_icon() {
    local desktop=$1 f
    for f in "$DESKTOP_DIR"/*; do
        [[ -L $f && $(readlink "$f") == */"$desktop" ]] && { echo "$f"; return 0; }
    done
    return 1
}

has_desktop_icon() { desktop_icon "$1" > /dev/null; }

in_menu() {
    grep -qE "^[[:space:]]*<Filename>$1</Filename>" "$MENU_FILE" 2>/dev/null
}

app_unit() { echo "astroarch-kiosk-app@$1.service"; }

json_bool() { "$@" && echo true || echo false; }

apps_state() {
    local id name desktop command process sep="" unit
    printf '['
    while IFS='|' read -r id name desktop command process; do
        unit=$(app_unit "$id")
        printf '%s{"id":"%s","name":"%s","installed":%s,"desktop":%s,"menu":%s,"start":%s,"watch":%s,"shared":%s}' \
            "$sep" "$id" "$name" \
            "$(json_bool test -f "/usr/share/applications/$desktop")" \
            "$(json_bool has_desktop_icon "$desktop")" \
            "$(json_bool in_menu "$desktop")" \
            "$(json_bool test -L "$UNIT_DIR/plasma-workspace.target.wants/$unit")" \
            "$(json_bool test -f "$UNIT_DIR/$unit.d/watchdog.conf")" \
            "$([[ -n $process ]] && echo true || echo false)"
        sep=,
    done < <(apps)
    printf ']\n'
}

# KStars and PHD2 open from the menus and desktop icons of both users through
# astroarch-kiosk-app.sh while the profiles are shared: it checks the other desktop
# first. A copy of their .desktop file in ~/.local/share/applications with another
# Exec, same name, so the menu takes it. A copy the user made is left alone
#   write_overrides as_kiosk|as_main DIR
write_overrides() {
    local run=$1 dir=$2 id name desktop command process
    $run mkdir -p "$dir" || { fail "Cannot create $dir"; return; }
    while IFS='|' read -r id name desktop command process; do
        [[ -n $process && -f /usr/share/applications/$desktop ]] || continue
        [[ -e $dir/$desktop ]] && ! grep -qx "$OVERRIDE_MARK" "$dir/$desktop" && continue
        # The Exec of the [Desktop Entry] only, its field codes (%U) kept
        sed -e "/^\[Desktop Entry\]/,/^\[/s|^Exec=[^ ]*|Exec=$APP_SCRIPT --ask $id|" -e '/^DBusActivatable=/d' -e '/^TryExec=/d' \
            -e "0,/^\[Desktop Entry\]/s||[Desktop Entry]\n$OVERRIDE_MARK|" \
            "/usr/share/applications/$desktop" | $run tee "$dir/$desktop" > /dev/null \
            || fail "Cannot write $dir/$desktop"
    done < <(apps)
}

#   remove_overrides DIR
remove_overrides() {
    local f
    for f in "$1"/*.desktop; do
        grep -qx "$OVERRIDE_MARK" "$f" 2>/dev/null && rm -f "$f"
    done
}

# Desktop icons of the apps point to the copy of the .desktop file when there is one
#   relink_icons as_kiosk|as_main DESKTOP_DIR OVERRIDE_DIR
relink_icons() {
    local run=$1 ddir=$2 odir=$3 icon link id name desktop command process target
    for icon in "$ddir"/*; do
        [[ -L $icon ]] || continue
        link=$(readlink "$icon")
        while IFS='|' read -r id name desktop command process; do
            [[ $link == "/usr/share/applications/$desktop" || $link == "$odir/$desktop" ]] || continue
            target=/usr/share/applications/$desktop
            grep -qx "$OVERRIDE_MARK" "$odir/$desktop" 2>/dev/null && target=$odir/$desktop
            [[ $link == "$target" ]] || $run ln -sfn "$target" "$icon" || fail "Cannot update the icon $icon"
        done < <(apps)
    done
}

set_menu() {
    local desktop=$1 on=$2 d=${1//./\\.}
    [[ -f $MENU_FILE ]] || { fail "No kiosk menu file ($MENU_FILE)"; return; }
    if [[ $on == 1 ]]; then
        if grep -qE "<!--[[:space:]]*<Filename>$d</Filename>[[:space:]]*-->" "$MENU_FILE"; then
            sed -i "s|<!--[[:space:]]*\(<Filename>$d</Filename>\)[[:space:]]*-->|\1|" "$MENU_FILE"
        elif ! in_menu "$desktop"; then
            # An app added to apps.list later: next to Dolphin, in the Include and in the Layout
            sed -i "s|^\([[:space:]]*\)\(<Filename>org\.kde\.dolphin\.desktop</Filename>\)|\1<Filename>$desktop</Filename>\n\1\2|" "$MENU_FILE"
        fi
    else
        sed -i "s|^\([[:space:]]*\)\(<Filename>$d</Filename>\)|\1<!-- \2 -->|" "$MENU_FILE"
    fi || fail "Cannot change the kiosk menu"
}

set_app() {
    local id=$1 flags=",$2," line name desktop command process unit icon target
    line=$(apps | awk -F'|' -v id="$id" '$1 == id { print; exit }')
    if [[ -z $line ]]; then
        fail "Unknown kiosk app: $id"
        return
    fi
    IFS='|' read -r _ name desktop command process <<< "$line"
    unit=$(app_unit "$id")

    # Desktop icon
    icon=$(desktop_icon "$desktop")
    if [[ $flags == *,desktop,* ]]; then
        if [[ -z $icon ]]; then
            target=/usr/share/applications/$desktop
            grep -qx "$OVERRIDE_MARK" "$OVERRIDE_DIR/$desktop" 2>/dev/null && target=$OVERRIDE_DIR/$desktop
            as_kiosk mkdir -p "$DESKTOP_DIR" && as_kiosk ln -sfn "$target" "$DESKTOP_DIR/$name" \
                || fail "Cannot add the $name icon"
        fi
    elif [[ -n $icon ]]; then
        rm -f "$icon" || fail "Cannot remove the $name icon"
    fi

    # Menu
    if [[ $flags == *,menu,* ]]; then set_menu "$desktop" 1; else set_menu "$desktop" 0; fi

    # Start with the kiosk session; reopen when closed (a watched app is started too)
    if [[ $flags == *,start,* || $flags == *,watch,* ]]; then
        as_kiosk mkdir -p "$UNIT_DIR/plasma-workspace.target.wants" \
            && as_kiosk ln -sfn /etc/systemd/user/astroarch-kiosk-app@.service "$UNIT_DIR/plasma-workspace.target.wants/$unit" \
            || fail "Cannot start $name with the kiosk"
    else
        rm -f "$UNIT_DIR/plasma-workspace.target.wants/$unit"
    fi
    if [[ $flags == *,watch,* ]]; then
        as_kiosk mkdir -p "$UNIT_DIR/$unit.d" \
            && printf '[Service]\nRestart=always\n' | as_kiosk tee "$UNIT_DIR/$unit.d/watchdog.conf" > /dev/null \
            || fail "Cannot reopen $name when it closes"
    else
        rm -f "$UNIT_DIR/$unit.d/watchdog.conf"
    fi
}

# ---------------------------------------------------------------------- main

usage() {
    sed -n '/^#   status profiles/,/^#                     (reopen/p' "$0" | sed 's/^#//' >&2
    exit 2
}

case ${1:-} in
    status)
        case ${2:-} in
            profiles) profiles_state ;;
            apps) apps_state ;;
            *) usage ;;
        esac
        exit 0 ;;
    apply) shift ;;
    *) usage ;;
esac

[[ $EUID -eq 0 ]] || { echo "apply must run as root" >&2; exit 2; }

profiles=""
app_args=()
while (($#)); do
    case $1 in
        --profiles)
            [[ ${2:-} == shared || ${2:-} == separate ]] || usage
            profiles=$2
            shift 2 ;;
        --app)
            [[ ${2:-} =~ ^[a-z0-9-]+=(desktop|menu|start|watch)?(,(desktop|menu|start|watch))*$ ]] || usage
            app_args+=("$2")
            shift 2 ;;
        *) usage ;;
    esac
done

if [[ -n $profiles ]]; then
    for p in "${PROFILE_APPS[@]}"; do
        if pgrep -u "$KIOSK_USER" -x "$p" > /dev/null; then
            echo "BUSY:$p"
            echo "Close KStars and PHD2 in the kiosk first" >&2
            exit 4
        fi
    done
    # Reopened by their watchdog in the middle of the switch: stopped meanwhile
    restart=()
    for id in kstars phd2; do
        unit=$(app_unit "$id")
        if systemctl --user -M "$KIOSK_USER@" is-active --quiet "$unit" 2>/dev/null \
            || [[ $(systemctl --user -M "$KIOSK_USER@" show -P SubState "$unit" 2>/dev/null) == auto-restart ]]; then
            restart+=("$unit")
        fi
    done
    ((${#restart[@]})) && systemctl --user -M "$KIOSK_USER@" stop "${restart[@]}" 2>/dev/null
    if [[ $profiles == shared ]]; then
        share_profiles
        write_overrides as_kiosk "$OVERRIDE_DIR"
        write_overrides as_main "$MAIN_HOME/.local/share/applications"
    else
        separate_profiles
        remove_overrides "$OVERRIDE_DIR"
        remove_overrides "$MAIN_HOME/.local/share/applications"
    fi
    relink_icons as_kiosk "$DESKTOP_DIR" "$OVERRIDE_DIR"
    relink_icons as_main "$MAIN_HOME/Desktop" "$MAIN_HOME/.local/share/applications"
    systemd-run --user -M "$MAIN_USER@" --collect -q kbuildsycoca6 > /dev/null 2>&1
    ((${#restart[@]})) && systemctl --user -M "$KIOSK_USER@" start --no-block "${restart[@]}" 2>/dev/null
fi

for a in "${app_args[@]}"; do
    set_app "${a%%=*}" "${a#*=}"
done

# The kiosk user manager reads the units again; the menu is rebuilt in the kiosk session.
# Not running (no kiosk session yet): both happen when it starts
systemctl --user -M "$KIOSK_USER@" daemon-reload 2>/dev/null
if [[ $profiles == shared ]]; then
    systemctl --user -M "$KIOSK_USER@" start "${SYNC_UNITS[@]}" 2>/dev/null
fi
systemd-run --user -M "$KIOSK_USER@" --collect -q kbuildsycoca6 > /dev/null 2>&1

((FAILED)) && exit 5
exit 0
