function power_max_current()
{
    if grep 'usb_max_current_enable=1' /boot/config.txt > /dev/null ; then
    echo "Maximum current is already activated"
    else
    sudo sed -i '/\[pi5\]/a usb_max_current_enable=1' /boot/config.txt
    echo "Maximum current activation for the Pi 5 USB ports is done after restart"
    fi
}
