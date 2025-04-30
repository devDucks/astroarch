function _check_vsftpd_installed()
{
    if pacman -Qs 'vsftpd' > /dev/null ; then
    echo "FTP is already installed"
    else
	echo "FTP packages not installed, installing them now..."
	echo 'astro' | sudo -S echo ''
	yes | LC_ALL=en_US.UTF-8 sudo pacman -S vsftpd
	sudo sed -i 's/#write_enable=YES/write_enable=YES/g' /etc/vsftpd.conf
    sudo sed -i 's/#local_enable=YES/local_enable=YES/g' /etc/vsftpd.conf
    sudo sed -i 's/#local_umask=022/local_umask=022/g' /etc/vsftpd.conf
    sudo sed -i 's/#ascii_upload_enable=YES/ascii_upload_enable=YES/g' /etc/vsftpd.conf
    sudo sed -i 's/#ascii_download_enable=YES/ascii_download_enable=YES/g' /etc/vsftpd.conf
    sudo sed -i 's/#chroot_list_enable=YES/chroot_list_enable=YES/g' /etc/vsftpd.conf
    sudo sed -i 's:#chroot_list_file=/etc/vsftpd.chroot_list:chroot_list_file=/etc/vsftpd.chroot_list:g' /etc/vsftpd.conf
    sudo sed -i 's/#ls_recurse_enable=YES/ls_recurse_enable=YES/g' /etc/vsftpd.conf
    sudo sed -i '$alocal_root=public_html' /etc/vsftpd.conf
    sudo sed -i '$aseccomp_sandbox=NO' /etc/vsftpd.conf
    sudo touch /etc/vsftpd.chroot_list
    sudo sed -i '$aastronaut' /etc/vsftpd.chroot_list
    sudo rm /etc/hosts.allow
    sudo touch /etc/hosts.allow
    sudo sh -c "echo 'vsftpd: ALL' >> /etc/hosts.allow"
    sudo sh -c "echo 'vsftpd: 10.0.0.0/255.255.255.0' >> /etc/hosts.allow"
    echo "FTP packages installed!"
    fi
}

function ftp_on()
{
    _check_vsftpd_installed
    echo 'astro' | sudo -S echo ''
    sudo systemctl enable vsftpd.service --now
    notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'FTP ON' 'FTP server turned ON and enabled to autostart at every boot'
}

function ftp_off()
{
    echo 'astro' | sudo -S echo ''
    sudo systemctl disable vsftpd.service --now
    notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'FTP OFF' 'FTP server disabled, remember to re-enable it if you want it to start automatically at boot'
}

function ftp_remove()
{
    echo 'astro' | sudo -S echo ''
    sudo systemctl disable vsftpd.service --now
    yes | LC_ALL=en_US.UTF-8 sudo pacman -Rcs vsftpd
    sudo rm /etc/vsftpd.chroot_list
    notify-send --app-name 'AstroArch' --icon="/home/astronaut/.astroarch/assets/icons/novnc-icon.svg" -t 10000 'FTP' "FTP server remove"
}
