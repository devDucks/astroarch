function _check_astroarch-bridge_installed()
{
    if pacman -Qs 'astroarch-bridge' > /dev/null ; then
    echo "✅ astroarch-bridge packages are already installed"
    notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'astroarch-bridge' "✅ astroarch-bridge packages are already installed"
    else
	echo "📦 astroarch-brige packages not installed, installing them now..."
	notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'astroarch-bridge' "📦 astroarch-bridge packages not installed, installing them now..."
	yes | LC_ALL=en_US.UTF-8 sudo pacman -S astroarch-bridge
    echo "✅ astroarch-bridge packages installed!"
    notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'astroarch-bridge' "✅ astroarch-bridge packages installed!"
    fi
}

function astroarch-bridge_astronaut_on()
{
    _check_astroarch-bridge_installed
    mkdir -p /home/astronaut/.config/systemd/user/default.target.wants
    ln -sf /usr/lib/systemd/user/astroarch-bridge.service \
           "/home/astronaut/.config/systemd/user/default.target.wants/astroarch-bridge.service"
    echo "🎉 astroarch-bridge will be active after the next reboot"
    notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'astroarch-bridge' "🎉 astroarch-bridge will be active after the next reboot"
}

function astroarch-bridge_astronaut_off()
{
    rm -f /home/astronaut/.config/systemd/user/default.target.wants/astroarch-bridge.service
    echo "🛑 astroarch-bridge disabled. Remember to re-enable it if you want it to start automatically at boot"
    notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'astroarch-bridge' "🛑 astroarch-bridge disabled. Remember to re-enable it if you want it to start automatically at boot"
}

function astroarch-bridge_astronaut-kiosk_on()
{
    _check_astroarch-bridge_installed
    su astronaut-kiosk -c "mkdir -p /home/astronaut-kiosk/.config/systemd/user/default.target.wants && \
        ln -sf /usr/lib/systemd/user/astroarch-bridge.service /home/astronaut-kiosk/.config/systemd/user/default.target.wants/astroarch-bridge.service"
    echo "🎉 astroarch-bridge will be active after the next reboot"
    notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'astroarch-bridge' "🎉 astroarch-bridge will be active after the next reboot"
}

function astroarch-bridge_astronaut-kiosk_off()
{
    su astronaut-kiosk -c "rm -f /home/astronaut-kiosk/.config/systemd/user/default.target.wants/astroarch-bridge.service"
    echo "🛑 astroarch-bridge disabled. Remember to re-enable it if you want it to start automatically at boot"
    notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'astroarch-bridge' "🛑 astroarch-bridge disabled. Remember to re-enable it if you want it to start automatically at boot"
}

function astroarch-bridge_remove()
{
    rm -f /home/astronaut/.config/systemd/user/default.target.wants/astroarch-bridge.service
    su astronaut-kiosk -c "rm -f /home/astronaut-kiosk/.config/systemd/user/default.target.wants/astroarch-bridge.service"
    yes | LC_ALL=en_US.UTF-8 sudo pacman -Rcs astroarch-bridge
    echo "🗑️ astroarch-bridge remove"
    notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'astroarch-bridge' "🗑️ astroarch-bridge remove"
}
