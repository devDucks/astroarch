export PATH=/usr/share/GSC/bin:$HOME/bin:/usr/local/bin:$PATH
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

zstyle ':omz:update' mode disabled

ENABLE_CORRECTION="true"
HIST_STAMPS="yyyy-mm-dd"

plugins=(git)

source $ZSH/oh-my-zsh.sh

EDITOR=nano

# Alias section
alias update-astroarch='cd /home/astronaut/.astroarch && git pull origin main'
