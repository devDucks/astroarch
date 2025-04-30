function _check_gpsd_installed()
{
    if pacman -Qs 'gpsd' > /dev/null ; then
    echo "GPS is already installed"
    else
	echo "GPS packages not installed, installing them now..."
	yes | LC_ALL=en_US.UTF-8 sudo pacman -S gpsd
        echo "GPS packages installed!"
    fi
}

function gps_ublox_on()
{
    _check_gpsd_installed
    echo 'astro' | sudo -S echo ''
    sudo systemctl enable gpsd.service --now
    sudo sh -c "echo 'refclock SHM 0 offset 0.5 delay 0.2 refid NMEA' >> /etc/chrony.conf"
    sudo sh -c "echo 'driftfile /var/lib/chrony/drift' >> /etc/chrony.conf"
    sudo rm /etc/default/gpsd
    sudo touch /etc/default/gpsd
    sudo sh -c 'echo "#Default settings for gpsd." >> /etc/default/gpsd'
    sudo sh -c 'echo "START_DAEMON=\""false\" >> /etc/default/gpsd'
    sudo sh -c 'echo "GPSD_OPTIONS=\""-n\" >> /etc/default/gpsd'
    sudo sh -c 'echo "DEVICES=\""/dev/ttyACM0\" >> /etc/default/gpsd'
    sudo sh -c 'echo "USBAUTO=\""false\" >> /etc/default/gpsd'
    notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'GPS USB UBLOX ON' 'GPS server turned ON and enabled to autostart at every boot'
}

function gps_on()
{
    _check_gpsd_installed
    echo 'astro' | sudo -S echo ''
    sudo sh -c "echo 'refclock SHM 0 offset 0.5 delay 0.2 refid NMEA' >> /etc/chrony.conf"
    sudo sh -c "echo 'driftfile /var/lib/chrony/drift' >> /etc/chrony.conf"
    sudo rm /etc/default/gpsd
    sudo touch /etc/default/gpsd
    sudo sh -c 'echo "#Default settings for gpsd." >> /etc/default/gpsd'
    sudo sh -c 'echo "START_DAEMON=\""true\" >> /etc/default/gpsd'
    sudo sh -c 'echo "GPSD_OPTIONS=\""\" >> /etc/default/gpsd'
    sudo sh -c 'echo "DEVICES=\""/dev/gps0\" >> /etc/default/gpsd'
    sudo sh -c 'echo "USBAUTO=\""true\" >> /etc/default/gpsd'
    sudo systemctl enable gpsd.service --now
    if [[ "$gps" == "GPS UART ON" ]] ; then
    echo $gps
    notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 $gps 'GPS server turned ON and enabled to autostart at every boot'
    else
    echo "standart"
    notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'GPS ON' 'GPS server turned ON and enabled to autostart at every boot'
    fi
}

function gps_uart_on()
{
    echo 'astro' | sudo -S echo ''
    gps="GPS UART ON"
    sudo sh -c 'echo "dtparam=spi=on" >> /boot/config.txt'
    sudo sh -c 'echo "enable_uart=1" >> /boot/config.txt'
    gps_on
}

function gps_off()
{
    echo 'astro' | sudo -S systemctl disable gpsd.service --now
    notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'GPS OFF ' 'GPS server disabled, remember to re-enable it if you want it to start automatically at boot'
    sudo sh -c 'sed -i "s~dtparam=spi=on~~g" /boot/config.txt'
    sudo sh -c 'sed -i "s~enable_uart=1~~g" /boot/config.txt'
}

