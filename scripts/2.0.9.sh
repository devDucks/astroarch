#!/usr/bin/env bash

# Invoke 2.0.8
bash /home/astronaut/.astroarch/scripts/2.0.8.sh

# Backup packages
sudo pacman -Sy rsync fakeroot

# Install astroarch-bridge for the astronaut and astronaut-kiosk users
sudo pacman -Sy astroarch-bridge tk python-qrcode

USERS=("astronaut" "astronaut-kiosk")
PORTS=("8765" "8766")

configure_user() {
  local USERNAME=$1
  local PORT=$2

  if ! id "$USERNAME" &>/dev/null; then
    return
  fi

  # 1. Folders
  sudo -u "$USERNAME" mkdir -p "/home/$USERNAME/.config/astroarch-bridge"
  sudo -u "$USERNAME" mkdir -p "/home/$USERNAME/Pictures/Ekos"

  # 2. Linger
  loginctl enable-linger "$USERNAME"

  # 3. Network port
  DROPIN_DIR="/home/$USERNAME/.config/systemd/user/astroarch-bridge.service.d"
  sudo -u "$USERNAME" mkdir -p "$DROPIN_DIR"
  cat <<EOF | sudo -u "$USERNAME" tee "$DROPIN_DIR/override.conf" > /dev/null
[Service]
Environment=ASTROARCH_PORT=$PORT
EOF

  # 4. Desktop shortcut
  ln -sf /usr/share/astroarch-bridge/desktop_dashboard/AstroarchBridge.desktop \
    "/home/$USERNAME/Desktop/AstroarchBridge.desktop"

  # 5. Services
  systemctl --machine="${USERNAME}@.host" --user daemon-reload
  systemctl --machine="${USERNAME}@.host" --user enable --now astroarch-bridge.service
}

for i in "${!USERS[@]}"; do
  configure_user "${USERS[$i]}" "${PORTS[$i]}"
done

# Pre-launch of the Kiosk session
sudo sed -i '1s/^/auth sufficient pam_succeed_if.so user = astronaut-kiosk\n/' /etc/pam.d/xrdp-sesman
sudo cp /home/astronaut/.astroarch/systemd/xrdp-autostart-kiosk.service /etc/systemd/system/xrdp-autostart-kiosk.service
sudo systemctl daemon-reload
sudo systemctl enable xrdp-autostart-kiosk.service

# Prevents XRDP from creating a second virtual desktop for the same user
sudo sed -i 's/^Policy=.*/Policy=UHQ/' /etc/xrdp/sesman.ini
sudo sed -i '/^\[Xorg\]/a fork=true' /etc/xrdp/xrdp.ini


