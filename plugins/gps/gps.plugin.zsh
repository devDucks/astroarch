# Plugin Zsh: GPS Management for Archlinux ARM/Raspberry Pi

# --- Configuration Variables ---
_ZSH_GPS_GPSD_CONF="/etc/default/gpsd"
_ZSH_GPS_BAUDS=(4800 9600 19200 38400 57600 115200)
_ZSH_GPS_PORTS=("/dev/ttyS0" "/dev/ttyAMA0" "/dev/ttyACM0" "/dev/ttyUSB0")
_ZSH_GPS_TIME_LIMIT=3
_ZSH_GPS_MIN_BYTES=50


# --- Helper Function: Check if a device is sending a GPS stream ---
# Returns 0 (Success) if a stream is found, 1 otherwise.
# Output to stdout: NONE. All status messages go to stderr (>2).
function _zsh_gps_check_device_stream()
{
    local DEV="$1"
    local COUNT=0

    for BAUD in "${_ZSH_GPS_BAUDS[@]}"; do

        # 1. Configure the serial port for raw reading
        sudo stty -F "$DEV" $BAUD cs8 -cstopb -parenb -ixon -ixoff -crtscts raw 2>/dev/null

        # 2. Try to read data stream within TIME_LIMIT
        COUNT=$(sudo timeout $_ZSH_GPS_TIME_LIMIT dd if="$DEV" bs=1 count=500 2>/dev/null | wc -c)

        if [ "$COUNT" -ge "$_ZSH_GPS_MIN_BYTES" ]; then
            echo "✅ Stream found on $DEV at $BAUD baud ($COUNT bytes read)." >&2 # Output to stderr
            notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'GPS' "✅ Stream found on $DEV at $BAUD baud ($COUNT bytes read)."
            return 0 # Success
        fi
    done

    return 1 # Failure
}


# --- Function for Automatic Detection ---
# Output to stdout: The device path (e.g., /dev/ttyAMA0) or empty string.
function _zsh_gps_find_device()
{
    local DEVICE=""

    echo "🔍 Starting brute-force search for GPS stream on serial ports..." >&2 # Output to stderr
    notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'GPS' "🔍 Starting brute-force search for GPS stream on serial ports..."

    for DEV in "${_ZSH_GPS_PORTS[@]}"; do
        [ -e "$DEV" ] || continue

        if ! sudo fuser -s "$DEV"; then
            # Note: check_device_stream sends its messages to stderr
            if _zsh_gps_check_device_stream "$DEV"; then
                echo "$DEV" # ONLY send the device path to stdout
                return 0 # Success
            fi
        else
            echo "⚠️ Port $DEV is busy (serial console or other service). Skipping" >&2 # Output to stderr
            notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'GPS' "⚠️ Port $DEV is busy (serial console or other service). Skipping"
        fi
    done

    echo "❌ No GPS stream detected on checked serial ports" >&2 # Output to stderr
    notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'GPS' "❌ No GPS stream detected on checked serial ports"
    return 1 # Failure
}

# Enable and configure GPS
function gps_on()
{
    if pacman -Qs 'gpsd' &> /dev/null ; then
        echo "✅ GPS packages are already installed"
        notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'GPS' "✅ GPS packages are already installed"
    else
        echo "📦 GPS packages not installed, installing them now..."
        notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'GPS' "📦 GPS packages not installed, installing them now..."
        sudo pacman -S --noconfirm gpsd jq
        echo "✅ GPS packages and 'jq' installed!"
        notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'GPS' "✅ GPS packages and 'jq' installed!"
    fi

    # 2. Automatic Detection (stderr redirected to user, stdout captured by 'device')
    local device
    device=$(_zsh_gps_find_device)

    if [ $? -eq 0 ] && [[ -n "$device" ]]; then
        echo "✅ Automatic detection successful: $device"
        notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'GPS' "✅ Automatic detection successful: $device"

    else
        echo "❌ Automated GPS detection failed"
        notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'GPS' "❌ Automated GPS detection failed"

        # 3. Manual Fallback with Verification
        echo "--------------------------------------------------------"
        echo "Please enter your GPS port path (e.g., /dev/ttyAMA0):"
        local manual_device
        read manual_device

        if [[ -n "$manual_device" ]]; then
            if [ -e "$manual_device" ]; then
                echo "🔍 Testing manual device: $manual_device..."
                notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'GPS' "🔍 Testing manual device: $manual_device..."

                # check_device_stream sends its messages to stderr
                if _zsh_gps_check_device_stream "$manual_device"; then
                    device="$manual_device"
                    echo "✅ Valid GPS stream confirmed"
                    notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'GPS' "✅ Valid GPS stream confirmed"
                else
                    echo "❌ No valid GPS stream found on $manual_device at any common baud rate"
                    notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'GPS' "❌ No valid GPS stream found on $manual_device at any common baud rate"
                    device=""
                fi
            else
                echo "❌ Device $manual_device does not exist"
                notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'GPS' "❌ Device $manual_device does not exist"
                device=""
            fi
        else
            device=""
        fi
    fi

    # 4. Final Configuration and Activation
    if [[ -n "$device" ]]; then
        echo "⚙️ Configuring GPSD to use device: $device"
        notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'GPS' "⚙️ Configuring GPSD to use device: $device"

        # Clean and configure gpsd
        sudo sh -c "> $_ZSH_GPS_GPSD_CONF"
        echo "# Configuration file generated by script" | sudo tee -a "$_ZSH_GPS_GPSD_CONF" > /dev/null
        echo "USBAUTO=\"false\"" | sudo tee -a "$_ZSH_GPS_GPSD_CONF" > /dev/null
        echo "START_DAEMON=\"true\"" | sudo tee -a "$_ZSH_GPS_GPSD_CONF" > /dev/null
        echo "GPSD_OPTIONS=\"-n\"" | sudo tee -a "$_ZSH_GPS_GPSD_CONF" > /dev/null
        echo "DEVICES=\"$device\"" | sudo tee -a "$_ZSH_GPS_GPSD_CONF" > /dev/null

        # Service Activation
        sudo systemctl enable gpsd.service
        sudo systemctl restart gpsd.service

        echo "🎉 GPS server ($device) is ON and enabled to autostart at every boot"
        notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'GPS' "🎉 GPS server ($device) is ON and enabled to autostart at every boot"
        return 0
    else
        echo "❌ GPS setup failed. GPSD service remains disabled"
        notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'GPS' "❌ GPS setup failed. GPSD service remains disabled"
        sudo systemctl disable gpsd.service --now 2>/dev/null
        return 1
    fi
}

# Disable GPS service
function gps_off()
{
    sudo systemctl disable gpsd.service --now
    echo "🛑 GPS server disabled. Remember to re-enable it if you want it to start automatically at boot"
    notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'GPS' "🛑 GPS server disabled. Remember to re-enable it if you want it to start automatically at boot"
}
