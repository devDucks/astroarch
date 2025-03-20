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

    # Fonction pour convertir une version (ex: 1.9 ou 1.9.1) en nombre (ex: 10900 ou 10901)
    version_to_num() {
        local version=$1
        local major minor patch
        IFS='.' read -r major minor patch <<< "$version"
        minor=${minor:-0}
        patch=${patch:-0}
        printf "%d%02d%02d" "$major" "$minor" "$patch"
    }

    # Définition des fichiers et variables
    UPDATE_HISTORY="/home/astronaut/.astroarch/.update_history"
    if [ ! -f "$UPDATE_HISTORY" ]; then
        touch "$UPDATE_HISTORY"
    fi

    # Récupération de l'ancienne version (bien qu'elle ne sera plus utilisée pour le test)
    if [ -f "/home/astronaut/.astroarch/configs/.astroarch.version" ]; then
        OLD_VER=$(cat /home/astronaut/.astroarch/configs/.astroarch.version)
    else
        OLD_VER="1.9.0"  # Valeur par défaut si le fichier est absent
    fi

    # Mise à jour depuis le dépôt Git
    cd /home/$USER/.astroarch
    git pull origin main
    cd - > /dev/null 2>&1

    # Lecture de la nouvelle version après mise à jour
    if [ -f "/home/astronaut/.astroarch/configs/.astroarch.version" ]; then
        NEW_VER=$(cat /home/astronaut/.astroarch/configs/.astroarch.version)
    else
        echo "Error: Unable to read updated version of AstroArch"
        exit 1
    fi

    # Conversion des versions en format numérique
    OLD_NUM=$(version_to_num "$OLD_VER")
    NEW_NUM=$(version_to_num "$NEW_VER")
    MIN_VERSION="1.9.0"
    MIN_NUM=$(version_to_num "$MIN_VERSION")

    echo "Ancienne version : $OLD_VER ($OLD_NUM)"
    echo "Nouvelle version : $NEW_VER ($NEW_NUM)"
    echo "Version minimale requise : $MIN_VERSION ($MIN_NUM)"

    # Parcours des scripts de mise à jour
    for script in /home/astronaut/.astroarch/scripts/1.*.sh; do
        SCRIPT_BASENAME=$(basename "$script")
        # Récupération de la version en retirant uniquement l'extension .sh
        SCRIPT_VER=$(basename "$script" .sh)
        SCRIPT_NUM=$(version_to_num "$SCRIPT_VER")

        echo "Vérification du script : $SCRIPT_BASENAME (version $SCRIPT_VER, $SCRIPT_NUM, $MIN_NUM, $NEW_NUM)"

        # On applique le script uniquement si :
        # - La version du script est strictement supérieure à la version minimale (1.9.0)
        # - Inférieure ou égale à la nouvelle version
        if [[ $SCRIPT_NUM -gt $MIN_NUM && $SCRIPT_NUM -le $NEW_NUM ]]; then
            if ! grep -Fq "$SCRIPT_BASENAME" "$UPDATE_HISTORY"; then
                echo "=== Application de la mise à jour $SCRIPT_BASENAME... ==="
                    zsh "$script"
                echo "$SCRIPT_BASENAME" >> "$UPDATE_HISTORY"
            else
                echo "Déjà appliqué : $SCRIPT_BASENAME"
            fi
        else
            echo "Ignoré : $SCRIPT_BASENAME"
        fi
    done

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
