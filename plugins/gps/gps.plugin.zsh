function gps_on()
{
    if pacman -Qs 'gpsd' > /dev/null ; then
    echo "GPS packages is already installed"
    else
	echo "GPS packages not installed, installing them now..."
	yes | LC_ALL=en_US.UTF-8 sudo pacman -S gpsd
    echo "GPS packages installed!"
    fi
    sudo systemctl enable gpsd.service --now
    sudo sh -c "echo 'refclock SHM 0 offset 0.5 delay 0.2 refid NMEA' >> /etc/chrony.conf"
    sudo sh -c "echo 'driftfile /var/lib/chrony/drift' >> /etc/chrony.conf"
    sudo rm /etc/default/gpsd
    sudo touch /etc/default/gpsd
    sudo sh -c 'echo "#Default settings for gpsd." >> /etc/default/gpsd'

    gps_info=$(gpspipe -w -n 10 2>/dev/null)
    if [[ -n "$gps_info" ]]; then
    device_path=$(echo "$gps_info" | jq -r 'select(.class=="DEVICES") | .devices[0].path' 2>/dev/null)
        if [[ -n "$device_path" && "$device_path" != "null" ]]; then
        echo "The GPS device is mounted on the path : $device_path"
            if [ $device_path="/dev/ttyACM0" ]; then
                sudo sh -c 'echo "START_DAEMON=\""false\" >> /etc/default/gpsd'
                sudo sh -c 'echo "GPSD_OPTIONS=\""-n\" >> /etc/default/gpsd'
                sudo sh -c 'echo "DEVICES=\""/dev/ttyACM0\" >> /etc/default/gpsd'
                sudo sh -c 'echo "USBAUTO=\""false\" >> /etc/default/gpsd'
                sudo systemctl restart gpsd.service --now
                echo "GPS server USB /dev/ttyACM0 turned ON and enabled to autostart at every boot"
                return 1
            elif [ $device_path="/dev/ttyAMA0" ]; then
                sudo sh -c 'echo "START_DAEMON=\""false\" >> /etc/default/gpsd'
                sudo sh -c 'echo "GPSD_OPTIONS=\""-n\" >> /etc/default/gpsd'
                sudo sh -c 'echo "DEVICES=\""/dev/ttyAMA0\" >> /etc/default/gpsd'
                sudo sh -c 'echo "USBAUTO=\""false\" >> /etc/default/gpsd'
                sudo systemctl restart gpsd.service --now
                echo "GPS server USB /dev/ttyAMA0 turned ON and enabled to autostart at every boot"
                return 1
            elif [ $device_path="/dev/ttyS0" ]; then
                sudo sh -c 'echo "START_DAEMON=\""false\" >> /etc/default/gpsd'
                sudo sh -c 'echo "GPSD_OPTIONS=\""-n\" >> /etc/default/gpsd'
                sudo sh -c 'echo "DEVICES=\""/dev/ttyS0\" >> /etc/default/gpsd'
                sudo sh -c 'echo "USBAUTO=\""false\" >> /etc/default/gpsd'
                sudo systemctl restart gpsd.service --now
                echo "GPS server USB /dev/ttyS0 turned ON and enabled to autostart at every boot"
                return 1
            else
                echo ""
            fi
        else
        echo " gpsd does not appear to have any active devices"
        fi

        echo "Please enter your GPS point /dev (eg: /dev/ttyxx):"
        read device

        if [ -e "$device" ] && timeout 2s cat "$device" | head -n 1 > /dev/null; then
        sudo sh -c 'echo "START_DAEMON=\""true\" >> /etc/default/gpsd'
        sudo sh -c 'echo "GPSD_OPTIONS=\""\" >> /etc/default/gpsd'
        sudo tee -a /etc/default/gpsd <<< 'DEVICES="'$device'"'
        sudo sh -c 'echo "USBAUTO=\""true\" >> /etc/default/gpsd'
        sudo systemctl enable gpsd.service --now
        echo "GPS server $device turned ON and enabled to autostart at every boot"
        else
        echo "No GPS found"
        fi
    fi
}


function gps_off()
{
    sudo systemctl disable gpsd.service --now
    echo "GPS server disabled, remember to re-enable it if you want it to start automatically at boot"
}

