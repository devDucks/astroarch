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
alias update-astroarch='cd /home/astronaut/.astroarch && git pull origin main & cd -'
alias update-astromonitor='wget -O - https://raw.githubusercontent.com/MattBlack85/astro_monitor/main/install.sh | sh'
