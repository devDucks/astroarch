power_max_current() {
    local cfg="/boot/config.txt"
    local key="usb_max_current_enable=1"

    # Ensure [pi5] section exists
    if ! grep -q "^\[pi5\]" "$cfg"; then
        echo "[pi5]" | sudo tee -a "$cfg" > /dev/null
    fi

    # If the line (commented or uncommented) exists anywhere
    if grep -Eq "^[#[:space:]]*usb_max_current_enable=" "$cfg"; then
        # Normalize it — uncomment and set to 1
        sudo sed -i 's/^[#[:space:]]*usb_max_current_enable=.*/usb_max_current_enable=1/' "$cfg"
        echo "Maximum current setting corrected and activated."
    else
        # Add it right after [pi5]
        sudo sed -i '/^\[pi5\]/a usb_max_current_enable=1' "$cfg"
        echo "Maximum current activation line added under [pi5]."
    fi
}
