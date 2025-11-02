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

function check_and_update_eeprom()
{
    pi_model=$(cat /proc/device-tree/model 2>/dev/null | awk '{$1=$1};1')
    eeprom_package=""

    if [[ "$pi_model" == *"Raspberry Pi 5"* ]]; then
        eeprom_package="rpi5-eeprom"
        rpi="Pi 5"
    elif [[ "$pi_model" == *"Raspberry Pi 4"* ]]; then
        eeprom_package="rpi4-eeprom"
        rpi="Pi 4"
    else
        return 0
    fi

    if ! pacman -Qs $eeprom_package > /dev/null; then
        sudo pacman -S --noconfirm $eeprom_package
    fi

    eeprom_status=$(sudo rpi-eeprom-update 2>&1)

    if [[ "$eeprom_status" == *"UPDATE AVAILABLE"* ]]; then
        update_message="A new Raspberry Pi EEPROM firmware update is available. This update is being applied automatically and requires a reboot to take effect. Do not turn off your Raspberry Pi during installation"
        title="EEPROM Update $rpi"
        icon="/usr/share/icons/breeze/status/64/dialog-information.svg"
        kdialog --title $title --icon=$icon --msgbox "$update_message" "$eeprom_status"
        if sudo rpi-eeprom-update -a; then
            notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 15000 'EEPROM Update' '✅ EEPROM update staged. Please reboot to apply it!'
        else
            notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 15000 'EEPROM Update' '❌ Failed to update EEPROM. Please check the logs.'
        fi
    fi
}

function use-astro-bleeding-edge()
{
    sudo pacman -Sy && yes | LC_ALL=en_US.UTF-8 sudo pacman -S kstars-git libindi-git indi-3rdparty-drivers-git indi-3rdparty-libs-git
}

function use-astro-stable()
{
    sudo pacman -Sy && yes | LC_ALL=en_US.UTF-8 sudo pacman -S kstars libindi indi-3rdparty-drivers indi-3rdparty-libs
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

    check_and_update_eeprom

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
            notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'Update AstroArch' "❌ Script '$SCRIPT_VER' failed. Reverted to previous state."
        fi
        notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'Update AstroArch' '✅ All scripts applied successfully'
    fi;

    # Temporary fix for kde-portal duplicated conf
    if [ -f /usr/share/xdg-desktop-portal/kde-portal.conf ]; then
        sudo mv /usr/share/xdg-desktop-portal/kde-portal.conf /usr/share/xdg-desktop-portal/kde-portal.conf.old
    fi;

    # Update the repo content
    sudo pacman -Sy --noconfirm

    # Update always keyring first, than all of the other packages
    sudo pacman -S archlinux-keyring --noconfirm

    # Now upgrade all system packages, but ask user to choose in case of conflicts/choices
    sudo pacman -Syu --noconfirm

    if [ $? -eq 0 ]; then
    notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'Update AstroArch' "✅ Successful update"
    else
    notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'Update AstroArch' "❌ Update failed"
    fi

    # Reinstall plasma-x11-session, cannot work on 1.9.0 cause of old kwin
    sudo pacman -Sy plasma-x11-session --noconfirm
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
