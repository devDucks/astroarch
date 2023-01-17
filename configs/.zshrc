export PATH=/usr/share/GSC/bin:$HOME/bin:/usr/local/bin:$PATH
export ZSH="$HOME/.oh-my-zsh"
export LC_CTYPE=en_US.UTF-8

ZSH_THEME="af-magic"

zstyle ':omz:update' mode disabled

ENABLE_CORRECTION="false"
HIST_STAMPS="yyyy-mm-dd"

plugins=(git archlinux)

source $ZSH/oh-my-zsh.sh

EDITOR=nano

# Alias section
alias update-astromonitor='wget -O - https://raw.githubusercontent.com/MattBlack85/astro_monitor/main/install.sh | sh'

function update-astroarch()
{
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

    # Now upgrade all system packages
    sudo pacman -Syu
}
