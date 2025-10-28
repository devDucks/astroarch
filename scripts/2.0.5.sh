#!/usr/bin/env bash

bash /home/astronaut/.astroarch/scripts/2.0.4.sh

# Increases the xrdp buffer
if grep -q "^#tcp_send_buffer_bytes=" /etc/xrdp/xrdp.ini; then
    sudo sed -i 's|^#tcp_send_buffer_bytes=.*|tcp_send_buffer_bytes=419|g' /etc/xrdp/xrdp.ini
fi

# Add user xrdp
sudo useradd xrdp -d / -c 'xrdp daemon' -s /usr/sbin/nologin
# Set user in xrdp.ini
sudo sed -i '/#runtime_user=xrdp/s/^#//' /etc/xrdp/xrdp.ini
sudo sed -i '/#runtime_group=xrdp/s/^#//' /etc/xrdp/xrdp.ini
sudo sed -i 's/bitmap_cache=true/bitmap_cache=false/g' /etc/xrdp/xrdp.ini
# Set user in xrdp.sesman.ini
sudo sed -i '/#SessionSockdirGroup=xrdp/s/^#//' /etc/xrdp/sesman.ini
sudo sed -i '/TerminalServerUsers=tsusers/s/^/#/' /etc/xrdp/sesman.ini
# Set permissions
sudo chown root:xrdp /etc/xrdp/rsakeys.ini
sudo chmod u=rw,g=r /etc/xrdp/rsakeys.ini
sudo chmod 755 /etc/xrdp/cert.pem
sudo chmod 755 /etc/xrdp/key.pem
# Allows adding devices from the xorg.conf.d section
sudo sed -i '/Option "AutoAddDevices" "off"/s/^/#/' /etc/X11/xrdp/xorg.conf
