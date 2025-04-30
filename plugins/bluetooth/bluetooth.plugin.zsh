function _check_bluez_installed()
{
    check=$(pacman -Q |  grep -E -c 'bluez|bluez-utils|bluez-hid2hci|bluedevil')
    if [[ $check -lt 6 ]]; then
	echo "Bluetooth packages not installed, installing them now..."
	echo 'astro' | sudo -S echo ''
	yes | LC_ALL=en_US.UTF-8 sudo pacman -S bluez bluez-utils bluez-hid2hci bluedevil
	echo 'astro' | sudo sed -i 's/#DiscoverableTimeout=0/DiscoverableTimeout=0/g' /etc/bluetooth/main.conf
	sudo sed -i 's/#AlwaysPairable=true/AlwaysPairable=true/g' /etc/bluetooth/main.conf
	sudo sed -i 's/#PairableTimeout=0/PairableTimeout=0/g' /etc/bluetooth/main.conf
	sudo sed -i 's/#AutoEnable=true/AutoEnable=true/g' /etc/bluetooth/main.conf
	echo "Bluetooth packages installed!"
    fi
}

function bluetooth_on()
{
    _check_bluez_installed
    echo 'astro' | sudo -S echo ''
    sudo systemctl enable bluetooth.service --now
    notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'BLUETOOTH ON' 'Bluetooth turned ON and enabled to autostart at every boot'
}

function bluetooth_off()
{
    echo 'astro' | sudo -S echo ''
    sudo systemctl disable bluetooth.service --now
    notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'BLUETOOTH OFF' 'Bluetooth disabled, remember to re-enable it if you want it to start automatically at boot'
}

function bluetooth_remove()
{
    echo 'astro' | sudo -S echo ''
    yes | LC_ALL=en_US.UTF-8 sudo pacman -Rcs bluez bluez-utils bluez-hid2hci bluedevil
    notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'BLUETOOTH' "Bluetooth packets removed"
}
