#!/bin/zsh
result=$(kdialog --menu "Select action" 1 "Update-astroarch" 2 "Set GPS" 3 "Set Bluetooth" 4 "Set FTP" --title "AstroArch Tweak Tool")
source ~/.zshrc
case $result in
    1)
        update-astroarch
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
esac
