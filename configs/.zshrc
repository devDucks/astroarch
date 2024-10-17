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
INDI_ROLLBACK_VERSION=2.0.9-1
INDI_LIBS_ROLLBACK_VERSION=2.0.9-1
INDI_DRIVERS_ROLLBACK_VERSION=2.0.9-1
KSTARS_ROLLBACK_VERSION=3.7.2-1

# Alias section
alias update-astromonitor='wget -O - https://raw.githubusercontent.com/MattBlack85/astro_monitor/main/install.sh | sh'
alias astro-rollback-full='astro-rollback-indi && astro-rollback-kstars'

# Run aa_motd.sh
bash /home/astronaut/.astroarch/scripts/aa_motd.sh

function use-astro-bleeding-edge()
{
    echo 'astro' | sudo -S echo ''
    sudo pacman -Sy && yes | LC_ALL=en_US.UTF-8 sudo pacman -S kstars-git libindi-git indi-3rdparty-drivers-git indi-3rdparty-libs-git
}

function use-astro-stable()
{
    echo 'astro' | sudo -S echo ''
    sudo pacman -Sy && yes | LC_ALL=en_US.UTF-8 sudo pacman -S kstars libindi indi-3rdparty-drivers indi-3rdparty-libs
}


function astro-rollback-indi()
{
    echo 'astro' | sudo -S echo ''
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
    echo 'astro' | sudo -S echo ''
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
    echo 'astro' | sudo -S echo ''
    # Store actual version
    OLD_VER=$(cat /home/$USER/.astroarch.version)

    # Checkout latest changes from git
    cd /home/$USER/.astroarch
    git pull origin main
    cd - > /dev/null 2>&1

    NEW_VER=$(cat /home/$USER/.astroarch/configs/.astroarch.version)

    if [ $OLD_VER != $NEW_VER ]; then
	zsh /home/$USER/.astroarch/scripts/$NEW_VER.sh
    fi;

    # Temporary fix for kde-portal duplicated conf
    if [ -f /usr/share/xdg-desktop-portal/kde-portal.conf ]; then
        sudo mv /usr/share/xdg-desktop-portal/kde-portal.conf /usr/share/xdg-desktop-portal/kde-portal.conf.old
    fi;

    # Update the repo content
    yes | LC_ALL=en_US.UTF-8 sudo pacman -Sy

    # Update always keyring first, than all of the other packages
    yes | LC_ALL=en_US.UTF-8 sudo pacman -S archlinux-keyring --noconfirm

    # Now upgrade all system packages, but ask user to choose in case of conflicts/choices
    yes | LC_ALL=en_US.UTF-8 sudo pacman -Syu
}

if [ -f $EXTRA_ZSH ]; then
    source $EXTRA_ZSH
fi
