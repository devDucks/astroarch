export PATH=/usr/share/GSC/bin:$HOME/bin:/usr/local/bin:$PATH
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

zstyle ':omz:update' mode disabled

ENABLE_CORRECTION="true"
HIST_STAMPS="yyyy-mm-dd"

plugins=(git archlinux)

source $ZSH/oh-my-zsh.sh

EDITOR=nano

# Alias section
alias update-astroarch='cd /home/astronaut/.astroarch && git pull origin main & cd -'
alias update-astromonitor='wget -O - https://raw.githubusercontent.com/MattBlack85/astro_monitor/main/install.sh | sh'

function update-indi() {
    cd ~/.build/indi && git checkout v1.9.4
    mkdir -p ~/.build/indi-core
    cd ~/.build/indi-core
    cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Debug ~/.build/indi
    make -j4
    sudo make install
    cd ~/
    rm -rf ~/.build/indi-core
}

function update-indi-drivers() {
    cd ~/.buildastro
    git clone https://github.com/indilib/indi-3rdparty
    mkdir -p ~/.buildastro/build-indi-3rdparty
    mkdir -p ~/.buildastro/build-indi-3rdparty-libs
    cd ~/.buildastro/build-indi-3rdparty-libs
    cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Debug -DBUILD_LIBS=1 ~/.buildastro/indi-3rdparty
    make -j4
    sudo make install
    cd ~/.buildastro/build-indi-3rdparty
    cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Debug ~/.buildastro/indi-3rdparty
    make -j4
    sudo make install
    cd ~/
    rm -rf ~/.buildastro/build-indi-3rdparty
    rm -rf ~/.buildastro/build-indi-3rdparty-libs
    rm -rf ~/.buildastro/indi-3rdparty
}
