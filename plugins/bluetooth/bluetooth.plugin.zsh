function _check_bluez_installed()
{
    check=$(pacman -Q |  grep 'bluez|bluez-utils|bluez-hid2hci|bluedevil')
    if [[ $check -eq 0 ]]; then
	echo "Bluetooth packages not installed, installing them now..."
	yes | LC_ALL=en_US.UTF-8 sudo pacman -S bluez bluez-utils bluez-hid2hci bluedevil
	sudo sed -i 's/#DiscoverableTimeout=0/DiscoverableTimeout=0/g' /etc/bluetooth/main.conf
	sudo sed -i 's/#AlwaysPairable=true/AlwaysPairable=true/g' /etc/bluetooth/main.conf
	sudo sed -i 's/#PairableTimeout=0/PairableTimeout=0/g' /etc/bluetooth/main.conf
	sudo sed -i 's/#AutoEnable=true/AutoEnable=true/g' /etc/bluetooth/main.conf
	echo "Bluetooth packages installed!"
    fi
}

function bluetooth_on()
{
    _check_bluez_installed
    sudo systemctl enable bluetooth.service --now
    echo "Bluetooth turned ON and enabled to autostart at every boot"
}

function bluetooth_off()
{
    sudo systemctl disable bluetooth.service --now
    echo "Bluetooth disabled, remember to re-enable it if you want it to start automatically at boot"
}

function bluetooth_remove()
{
    yes | LC_ALL=en_US.UTF-8 sudo pacman -Rcs bluez bluez-utils bluez-hid2hci bluedevil
}
