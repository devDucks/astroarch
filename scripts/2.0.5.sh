#!/usr/bin/env bash

bash /home/astronaut/.astroarch/scripts/2.0.4.sh

# Increases the xrdp buffet
sudo sed -i 's|#tcp_send_buffer_bytes=32768|tcp_send_buffer_bytes= 4194304|g' /etc/xrdp/xrdp.ini





