#!/usr/bin/env bash

bash /home/astronaut/.astroarch/scripts/2.0.4.sh

# Increases the xrdp buffer
if grep -q "^#tcp_send_buffer_bytes=" /etc/xrdp/xrdp.ini; then
    sudo sed -i 's|^#tcp_send_buffer_bytes=.*|tcp_send_buffer_bytes=419|g' /etc/xrdp/xrdp.ini
fi
