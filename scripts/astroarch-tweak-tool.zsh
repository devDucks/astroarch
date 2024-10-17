#!/bin/zsh
result=$(kdialog --menu "Select action" 1 "Update-astroarch" 2 "Set GPS" 3 "Set Bluetooth" 4 "Set FTP" 5 "Rollback Kstars/Indi" 6 "Install Kstars/Indi stable/bleeding-edge" --title "AstroArch Tweak Tool")
source ~/.zshrc
case $result in
    1)
        update-astroarch
        if [ $? -eq 0 ] ; then
        notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'Update AstroArch' 'Update completed'
        else
        notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'Update AstroArch' 'Update returns an error'
        fi
        ;;
    2)
        gps=$(kdialog --menu "Select action" 1 "Activate default GPS" 2 "Activate Usb Ublox GPS" 3 "Activate UART GPS" 4 "Stop GPS" --title "AstroArch GPS")
        case $gps in
            1)
                gps_on
                ;;
            2)
                gps_ublox_on
                ;;
            3)
                gps_uart_on
                ;;
            4)
                gps_off
                ;;
        esac
        ;;
    3)
        bluetooth=$(kdialog --combobox "Select action for Bluetooth" "ON" "OFF" --title "AstroArch bluetooth")
        case $bluetooth in
            ON)
                bluetooth_on
                ;;
            OFF)
                bluetooth_off
                ;;
        esac
        ;;
    4)
        ftp=$(kdialog --combobox "Select action for FTP" "ON" "OFF" --title "AstroArch FTP")
        case $ftp in
            ON)
                ftp_on
                ;;
            OFF)
                ftp_off
                ;;
        esac
        ;;
    5)
        rollback=$(kdialog --combobox "Select action for rollback" "Full-Kstars-Indi" "Indi" "Kstars" --title "AstroArch Rollback")
        case $rollback in
            Full-Kstars-Indi)
                astro-rollback-full
                if [ $? -eq 0 ] ; then
                notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'Rollback full' 'Completed'
                else
                notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'Rollback full' 'Returns an error'
                fi
                ;;
            Indi)
                astro-rallback-indi
                if [ $? -eq 0 ] ; then
                notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'Rollback indi' 'Completed'
                else
                notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'Rollback indi' 'Returns an error'
                fi
                ;;
            Kstars)
                astro-rollback-kstars
                if [ $? -eq 0 ] ; then
                notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'Rollback kstars' 'Completed'
                else
                notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'Rollback kstars' 'Returns an error'
                fi
                ;;
        esac
        ;;
    6)
        install_kstars=$(kdialog --combobox " Select the Kstars installation version" "Bleeding-edge" "Stable" --title "AstroArch Install Kstars")
        case $install_kstars in
            Bleeding-edg)
                use-astro-bleeding-edge
                if [ $? -eq 0 ] ; then
                notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'Installation Kstars bleeding-edge' 'Completed'
                else
                notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'Installation Kstars bleeding-edge' 'Returns an error'
                fi
                ;;
            Stable)
                use-astro-stable
                if [ $? -eq 0 ] ; then
                notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'Installation Kstars' 'Completed'
                else
                notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'Installation Kstars' 'Returns an error'
                fi
                ;;
        esac
        ;;
esac
