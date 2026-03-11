export PATH=/usr/share/GSC/bin:$HOME/bin:/usr/local/bin:$PATH
export ZSH="$HOME/.oh-my-zsh"
export LC_CTYPE=en_US.UTF-8
export SYSTEMD_TIMEDATED_NTP_SERVICES=chronyd.service

ZSH_THEME="af-magic"
ZSH_CUSTOM=$HOME/.astroarch

EXTRA_ZSH=$HOME/extra.zsh

zstyle ':omz:update' mode disabled

ENABLE_CORRECTION="false"
HIST_STAMPS="yyyy-mm-dd"

plugins=(git archlinux)

# Find all plugins and append them to plugins
for dir in $HOME/.astroarch/plugins/**/*.plugin.zsh; do
    split=(${(s:/:)dir})
    last=$split[-1]
    name=(${(s:.:)last})
    plugins+=($name[1])
done;

source $ZSH/oh-my-zsh.sh

EDITOR=nano
INDI_ROLLBACK_VERSION=2.1.3-1
INDI_LIBS_ROLLBACK_VERSION=2.1.3-1
INDI_DRIVERS_ROLLBACK_VERSION=2.1.3-1
KSTARS_ROLLBACK_VERSION=3.7.6-2

# Alias section
alias update-astromonitor='wget -O - https://raw.githubusercontent.com/MattBlack85/astro_monitor/main/install.sh | sh'
alias astro-rollback-full='astro-rollback-indi && astro-rollback-kstars'
alias apt=xyz
alias apt-get=xyz

# Run aa_motd.sh
bash /home/astronaut/.astroarch/scripts/aa_motd.sh

function use-astro-bleeding-edge()
{
    sudo pacman -Sy --noconfirm && yes | LC_ALL=en_US.UTF-8 sudo pacman -S kstars-git libindi-git indi-3rdparty-drivers-git indi-3rdparty-libs-git --noconfirm
}

function use-astro-stable()
{
    sudo pacman -Sy --noconfirm && yes | LC_ALL=en_US.UTF-8 sudo pacman -S kstars libindi indi-3rdparty-drivers indi-3rdparty-libs --noconfirm
}


function astro-rollback-indi()
{
    setopt localoptions rmstarsilent
    mkdir -p ~/.rollback
    cd ~/.rollback
    wget -O indi-3rdparty-drivers-${INDI_DRIVERS_ROLLBACK_VERSION}-aarch64.pkg.tar.xz http://astromatto.com:9000/aarch64/indi-3rdparty-drivers-${INDI_DRIVERS_ROLLBACK_VERSION}-aarch64.pkg.tar.xz
    wget -O libindi-${INDI_ROLLBACK_VERSION}-aarch64.pkg.tar.xz http://astromatto.com:9000/aarch64/libindi-${INDI_ROLLBACK_VERSION}-aarch64.pkg.tar.xz
    wget -O indi-3rdparty-libs-${INDI_LIBS_ROLLBACK_VERSION}-aarch64.pkg.tar.xz http://astromatto.com:9000/aarch64/indi-3rdparty-libs-${INDI_LIBS_ROLLBACK_VERSION}-aarch64.pkg.tar.xz
    sudo pacman -U libindi* indi* --noconfirm
    cd - > /dev/null 2>&1
    rm -rf ~/.rollback/*
}

function astro-rollback-kstars()
{
    setopt localoptions rmstarsilent
    mkdir -p ~/.rollback
    cd ~/.rollback
    wget -O kstars-${KSTARS_ROLLBACK_VERSION}-aarch64.pkg.tar.xz http://astromatto.com:9000/aarch64/kstars-${KSTARS_ROLLBACK_VERSION}-aarch64.pkg.tar.xz
    sudo pacman -U kstars* --noconfirm
    cd - > /dev/null 2>&1
    rm -rf ~/.rollback/*
}

function update-astroarch()
{
    # Store actual version
    OLD_VER=$(cat /home/$USER/.astroarch.version)

    # Store the current commit hash before the pull
    cd /home/$USER/.astroarch
    CURRENT_COMMIT=$(git rev-parse HEAD)

    # Checkout latest changes from git
    cd /home/$USER/.astroarch
    git pull origin main
    cd - > /dev/null 2>&1

    NEW_VER=$(cat /home/$USER/.astroarch/configs/.astroarch.version)

    if [[ "$OLD_VER" != "$NEW_VER" ]]; then
        zsh /home/$USER/.astroarch/scripts/$NEW_VER.sh
        if [[ $? -ne 0 ]]; then
            # Revert to the commit stored before the pull
            cd /home/$USER/.astroarch
            git reset --hard "$CURRENT_COMMIT"
            cd - > /dev/null 2>&1
            notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'Update AstroArch' "Script '$SCRIPT_VER' failed. Reverted to previous state."
        fi
        notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'Update AstroArch' 'All scripts applied successfully'
    fi;

    # Temporary fix for kde-portal duplicated conf
    if [ -f /usr/share/xdg-desktop-portal/kde-portal.conf ]; then
        sudo mv /usr/share/xdg-desktop-portal/kde-portal.conf /usr/share/xdg-desktop-portal/kde-portal.conf.old
    fi;

    # Update the repo content
    sudo pacman -Sy --noconfirm

    # Update always keyring first, than all of the other packages
    sudo pacman -S archlinux-keyring --noconfirm

    # Testing libraries before updating
    # --- Configuration ---
    BACKUP_DIR="$HOME/pacman_backups"
    WATCHLIST_FILE="$HOME/.astroarch/configs/astroarch-maintained-packages-list.txt"
    mkdir -p "$BACKUP_DIR"
    DATE=$(date +%F_%H-%M)

    # --- Loading WATCHLIST ---
    if [[ -f "$WATCHLIST_FILE" ]]; then
        WATCHLIST=( ${(f)"$(grep -v '^#' "$WATCHLIST_FILE" | sed '/^$/d')"} )
        echo "✅ Watchlist loaded : ${#WATCHLIST} packages found"
    else
        echo "❌ Error: File $WATCHLIST_FILE not found"
        return 1
    fi

    # Saving the current state of packages
    mkdir -p "$BACKUP_DIR"
    pacman -Q > "$BACKUP_DIR/full_snapshot_$DATE.txt"

    # Simulation of updates
    updates=$(checkupdates)
    if [ -z "$updates" ]; then
        echo "✅ System already up to date"
        notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'Update AstroArch' "✅ System already up to date"
        return 0
    fi

    upgrading_names=(${(f)"$(echo "$updates" | awk '{print $1}')"})
    found_risk=0
    broken_deps_list=()
    # Analysis of dependencies
    for pkg in $WATCHLIST; do
        if ! pacman -Qi "$pkg" &> /dev/null; then
            echo "⚠️  [Info] $pkg is not installed on the system"
            continue
        fi

        if [[ ${upgrading_names[(i)$pkg]} -le ${#upgrading_names} ]]; then
        echo "🟢 $pkg: Included in the update (Low priority: will be synchronized)"
        else

        deps=(${(f)"$(pactree -u "$pkg" | grep -v "$pkg")"})

        for dep in $deps; do
            # If one of its dependencies is updated
            if [[ ${upgrading_names[(i)$dep]} -le ${#upgrading_names} ]]; then
                new_ver=$(echo "$updates" | grep -w "^$dep" | awk '{print $4}')
                old_ver=$(pacman -Q "$dep" | awk '{print $2}')

                echo "⚠️ RISK: The dependency ‘$dep’ will change ($old_ver -> $new_ver)"
                echo "$pkg: may no longer be able to find its libraries"

                # Store the conflict info for the final summary
                broken_deps_list+=("$pkg depends on $dep ($old_ver -> $new_ver)")
                found_risk=1
            fi
        done
        [[ $found_risk -eq 0 ]] && echo "✅ $pkg : No dependency conflicts detected"
        fi
    done

    if [ $found_risk -eq 1 ]; then
        echo "❗ Warning: Some critical packages have dependencies that will change. The update cannot be performed"
        echo "❌ Dependency Risks:"
        for conflict in $broken_deps_list; do
            echo "- $conflict"
        done

        list_str="${(j:\n:)broken_deps_list}"
        # Save the risks to a log file for history
        local RISK_LOG="$BACKUP_DIR/dependency_risks_$DATE.txt"
        echo "Dependency risks detected on $(date)" > "$RISK_LOG"
        echo "------------------------------------" >> "$RISK_LOG"
        echo "- $list_str" >> "$RISK_LOG"
        echo "⚠️  Dependency risks detected. Details saved to $RISK_LOG"

        notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'Update AstroArch' "! Warning: Some critical packages have dependencies that will change"
        notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 15000 'Update AstroArch' "❌ Dependency Risks: $list_str"
        notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 15000 'Update AstroArch' "⚠️  Dependency risks detected. Details saved to $RISK_LOG"

        # Confirmation request via kdialog
        local PROCEED_UPDATE=1
        # Test : GUI ?
        if [[ -n "$DISPLAY" && -z "$SSH_CLIENT" && -z "$SSH_TTY" ]]; then
            kdialog --title "AstroArch Update - Risk of Addiction" \
                --warningyesno "Warning! The following critical packages will have their dependencies changed:\n\n- $list_str\n\nDo you want to proceed the update anyway?"
            [[ $? -ne 0 ]] && PROCEED_UPDATE=0
        else
            # Terminal mode no GUI
            echo -e "\n⚠️  WARNING: Critical dependencies will change!"
            echo -e "$list_str"
            echo -n "Do you want to proceed the update anyway? (y/N): "
            read -r response
            [[ ! "$response" =~ ^[yY][eE]?[sS]?$ ]] && PROCEED_UPDATE=0
        fi

        # If the user clicks “No”
        if [ $PROCEED_UPDATE -eq 0 ]; then
            echo "❌ Update canceled by user."
            notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'Update AstroArch' "❌ Update canceled by user"
            return 0
        else

        # Now upgrade all system packages, but ask user to choose in case of conflicts/choices
        sudo pacman -Syu --noconfirm

        if [ $? -eq 0 ]; then
        notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'Update AstroArch' "✅ Successful update"
        else
        notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'Update AstroArch' "❌ Update failed"
        fi

        # Reinstall plasma-x11-session, cannot work on 1.9.0 cause of old kwin
        sudo pacman -Sy plasma-x11-session --noconfirm
        fi
    fi
}

function xyz () {
    echo "ATTENTION! The system is going to be infected with a virus now!"
    sleep 1
    echo "This virus is called ArchLinux"
    sleep 0.5
    echo -n "Transfering virus."
    sleep 0.5
    echo -n "."
    sleep 0.5
    echo -n "."
    sleep 0.5
    echo -n "."
    sleep 0.5
    echo -n "."
    echo ""
    sleep 1
    echo "Virus transfered successfully"
    echo "ENJOY YOUR ARCHLINUX SYSTEM AND EMBRACE THE DARK SIDE"
    sleep 1
    echo "That was a joke of course, there is no apt nor apt-get on arch, just pacman!"
}

if [ -f $EXTRA_ZSH ]; then
    source $EXTRA_ZSH
fi
