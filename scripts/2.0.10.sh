#!/usr/bin/env bash

# Invoke 2.0.9
bash /home/astronaut/.astroarch/scripts/2.0.9.sh

# Install astroarch-bridge for the astronaut and astronaut-kiosk users
sudo pacman -Sy astroarch-bridge tk python-qrcode --noconfirm

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

  # 5. Enable via symlink (works without active session / chroot)
  local UID_NUM
  UID_NUM=$(id -u "$USERNAME")
  local WANTS_DIR="/home/$USERNAME/.config/systemd/user/default.target.wants"
  sudo -u "$USERNAME" mkdir -p "$WANTS_DIR"
  sudo -u "$USERNAME" ln -sf \
    /usr/lib/systemd/user/astroarch-bridge.service \
    "$WANTS_DIR/astroarch-bridge.service"

  # 6. Reload & start only if the user D-Bus socket is reachable
  local BUS_SOCKET="/run/user/${UID_NUM}/bus"
  if [ -S "$BUS_SOCKET" ]; then
    sudo -u "$USERNAME" \
      XDG_RUNTIME_DIR="/run/user/${UID_NUM}" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=${BUS_SOCKET}" \
      systemctl --user daemon-reload
    sudo -u "$USERNAME" \
      XDG_RUNTIME_DIR="/run/user/${UID_NUM}" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=${BUS_SOCKET}" \
      systemctl --user start astroarch-bridge.service
  else
    echo "[INFO] Session D-Bus not available for $USERNAME — service will start at next login (linger enabled)"
  fi
}

for i in "${!USERS[@]}"; do
  configure_user "${USERS[$i]}" "${PORTS[$i]}"
done

# Pre-launch of the Kiosk session
sudo sed -i '1s/^/auth sufficient pam_succeed_if.so user = astronaut-kiosk\n/' /etc/pam.d/xrdp-sesman
sudo cp -f /home/astronaut/.astroarch/systemd/xrdp-autostart-kiosk.service /etc/systemd/system/xrdp-autostart-kiosk.service
sudo ln -sf /etc/systemd/system/xrdp-autostart-kiosk.service /etc/systemd/system/multi-user.target.wants/xrdp-autostart-kiosk.service
sudo systemctl enable xrdp-autostart-kiosk.service
