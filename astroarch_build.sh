# Exit on the first error, if any
set -e

# Grab the OS architecture for further forked logic
ARCH=$(uname -m)
HAS_VIRT=$(command -v systemd-detect-virt >/dev/null 2>&1 && echo 1 || echo 0)

is_container() {
    # Docker / Podman
    [ -f /.dockerenv ] && return 0

    # systemd container env
    [ -n "$container" ] && return 0

    # cgroup inspection
    grep -qaE '(docker|containerd|kubepods|podman|lxc)' /proc/1/cgroup 2>/dev/null && return 0

    # mount namespace hints
    grep -qa 'overlay' /proc/mounts 2>/dev/null && return 0

    return 1
}

# Enable a user unit shipped in the repo for one user.
# The unit is linked into the user's unit search path (a symlink that only
# exists inside a .wants directory is not a unit systemd can load), then wanted
# by the given target (default graphical-session.target).
enable_user_unit() {
    local user=$1 unit=$2 target=${3:-graphical-session.target}
    local dir="/home/$user/.config/systemd/user"
    local name
    name=$(basename "$unit")
    su "$user" -c "mkdir -p '$dir/$target.wants'"
    ln -sfn "$unit" "$dir/$name"
    ln -sfn "$dir/$name" "$dir/$target.wants/$name"
    chown -h "$user:$user" "$dir/$name" "$dir/$target.wants/$name"
}

# Parallelize pacman download to 5 and use pacman as progress bar
if [ "$HAS_VIRT" -eq 0 ]; then
    sed -i 's|#ParallelDownloads = 5|ParallelDownloads = 5|g' /etc/pacman.conf
    sed -i 's|ParallelDownloads = 5|ParallelDownloads = 5\nILoveCandy|g' /etc/pacman.conf
    sed -i 's|ParallelDownloads = 5|ParallelDownloads = 5\nDisableDownloadTimeout|g' /etc/pacman.conf
    sed -i 's|\[core\]|\[astromatto\]\nSigLevel = Optional TrustAll\nServer = http://astroarch.astromatto.com:9000/$arch\n\n\[core\]|' /etc/pacman.conf
fi

# Bootstrap pacman-key
pacman-key --init && pacman-key --populate archlinuxarm

# Update all packages now
pacman -Syu --noconfirm

# Install just 2 packages for the next actions
# list of commented locales
pacman -S wget sudo git --noconfirm

# create user astro with home, add it to wheel
useradd -G wheel -m astronaut
echo "astronaut:astro" | chpasswd

# Pull the brain repo, this will be used for scripting out the final image
su astronaut -c "git clone https://github.com/devDucks/astroarch.git /home/astronaut/.astroarch"

# Uncomment en_US UTF8 and generate locale files
sed -i -e 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# If we are on QEMU, packages have already been pulled in the docker phase - install only the pi kernel
if [ "$HAS_VIRT" -eq 1 ]; then
    pacman -Syu linux-rpi linux-rpi-headers linux-firmware --noconfirm --ask 4
else
    pacman -Syu base-devel pipewire-jack gnu-free-fonts wireplumber \
       zsh plasma-desktop networkmanager \
       network-manager-applet networkmanager-qt konsole \
       gpsd breeze-icons hicolor-icon-theme knewstuff tigervnc \
       knotifyconfig kplotting qt6-datavis3d qt5-quickcontrols \
       qt6-websockets qtkeychain-qt6 stellarsolver \
       xplanet plasma-nm dhcp dnsmasq kate plasma-systemmonitor \
       dolphin uboot-tools usbutils cloud-guest-utils samba paru \
       websockify novnc astrometry.net gsc kstars phd2 packagekit-qt6 \
       indi-3rdparty-libs indi-3rdparty-drivers linux-rpi linux-rpi-headers \
       i2c-tools indiserver-ui astro_dmx openssl firefox chrony \
       ksystemlog discover kwalletmanager kgpg qt6-serialbus \
       qt6-serialport qt6ct udisks2 fuse2 kdialog jq \
       fortune-mod cowsay pacman-contrib neofetch \
       astromonitor kscreen flatpak dhcpcd iw rsync \
       krdp plasma-login-manager astroarch-onboarding astroarch-bridge --noconfirm --ask 4
fi

# Allow wheelers to sudo without password to install packages
sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers

# Add astronaut to uucp for serial device ownership
usermod -aG uucp,sys,network,power,audio,input,lp,storage,video,users astronaut

# Make all necessary folders
mkdir -p /etc/plasmalogin.conf.d
su astronaut -c "mkdir -p /home/astronaut/.config/systemd/user/graphical-session.target.wants"
su astronaut -c "mkdir -p /home/astronaut/.config/systemd/user/default.target.wants"
su astronaut -c "mkdir -p /home/astronaut/Pictures/wallpapers"
su astronaut -c "mkdir -p /home/astronaut/Desktop"

# install oh-my-zsh and set the default shell to zsh
chsh -s /usr/bin/zsh astronaut
rm /home/astronaut/.bash*
cd /home/astronaut
ZSH=/home/astronaut/.oh-my-zsh sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
chown -R astronaut:astronaut /home/astronaut/.oh-my-zsh/

# Set the samba pass
ln -s /home/astronaut/.astroarch/configs/smb.conf /etc/samba/smb.conf
smbd --daemon
(echo astro; echo astro) | smbpasswd -s -a astronaut
pkill smbd || true

# Link a zsh config for astronaut
ln -s /home/astronaut/.astroarch/configs/.zshrc /home/astronaut/.zshrc

# NetworkManager WiFi Power Saving
ln -s /home/astronaut/.astroarch/configs/default-wifi-powersave-off.conf /etc/NetworkManager/conf.d

# Start NetworkManager and sleep to create the hotspot
NetworkManager &
sleep 5

# Remove eventually existing systemd configs we are going to substitute
rm -f /usr/lib/systemd/system/novnc.service

# Synchronize the system time with the GPS if there is no Real Time Clock (RTC) or network connection to the Raspberry Pi
sed -i '$a\refclock SHM 0 offset 0.5 delay 0.2 refid NMEA' /etc/chrony.conf
sed -i '$a\driftfile /var/lib/chrony/drift' /etc/chrony.conf

# Disable systemd-timesyncd and enable chronyd
mkdir -p /etc/systemd/system/sysinit.target.wants
mkdir -p /etc/systemd/system/multi-user.target.wants
rm -f /etc/systemd/system/sysinit.target.wants/systemd-timesyncd.service
ln -s /dev/null /etc/systemd/system/systemd-timesyncd.service
ln -s /usr/lib/systemd/system/chronyd.service /etc/systemd/system/multi-user.target.wants/chronyd.service

# Symlink now files
ln -s /home/astronaut/.astroarch/configs/autologin.conf /etc/plasmalogin.conf.d/autologin.conf
ln -s /home/astronaut/.astroarch/systemd/novnc.service /usr/lib/systemd/system/novnc.service
ln -s /home/astronaut/.astroarch/systemd/resize_once.service /etc/systemd/system/resize_once.service
ln -s /home/astronaut/.astroarch/configs/.astroarch.version /home/astronaut/.astroarch.version

# Copy udev rule to disable wifi power saving
cp /home/astronaut/.astroarch/configs/81-wifi-powersave.rules /etc/udev/rules.d/81-wifi-powersave.rules

# Udev rule to force the brcmfmac driver to keep the name “wlan0” for Wi-Fi
cp /home/astronaut/.astroarch/configs/99-brcmfmac.rules /etc/udev/rules.d/99-brcmfmac.rules

# Polkit rules go here
cp /home/astronaut/.astroarch/configs/99-polkit-power.rules /etc/polkit-1/rules.d/
cp /home/astronaut/.astroarch/configs/50-udiskie.rules /etc/polkit-1/rules.d/
cp /home/astronaut/.astroarch/configs/50-networkmanager.rules /etc/polkit-1/rules.d/
cp /home/astronaut/.astroarch/configs/50-timedate.rules /etc/polkit-1/rules.d/

# Copy the systemd unit to create the AP the first boot
cp /home/astronaut/.astroarch/systemd/create_ap.service /etc/systemd/system/

# Network and memory tuning
cp /home/astronaut/.astroarch/configs/99-sysctl.conf /etc/sysctl.d

# VNC runs as app-org.astroarch.vnc.service: the unit name gives w0vncserver the
# portal app id "org.astroarch.vnc", so the remote-desktop grant is limited to
# krdp and VNC. The .desktop file is needed for the portal to resolve that id.
ln -sfn /home/astronaut/.astroarch/desktop/org.astroarch.vnc.desktop /usr/share/applications/org.astroarch.vnc.desktop

# krdp starts only after the portal grant
mkdir -p /etc/systemd/user/app-org.kde.krdpserver.service.d
ln -sfn /home/astronaut/.astroarch/systemd/krdp-after-grant.conf /etc/systemd/user/app-org.kde.krdpserver.service.d/astroarch-grant.conf

# Enable astronaut permissions krdp/vnc
enable_user_unit astronaut /home/astronaut/.astroarch/systemd/astroarch-portal-permissions.service plasma-workspace.target

# Config KRDP
# astronaut
su astronaut -c "mkdir -p /home/astronaut/.local/share/krdpserver"
certificatePath="/home/astronaut/.local/share/krdpserver/krdp.crt"
certificateKeyPath="/home/astronaut/.local/share/krdpserver/krdp.key"
su astronaut -c "openssl req -nodes -new -x509 -keyout '$certificateKeyPath' -out '$certificatePath' -days 3650 -batch -subj '/CN=astroarch' -addext 'subjectAltName = DNS:astroarch'"
su astronaut -c "kwriteconfig6 --file krdpserverrc --group General --key Certificate '$certificatePath'"
su astronaut -c "kwriteconfig6 --file krdpserverrc --group General --key CertificateKey '$certificateKeyPath'"
su astronaut -c "kwriteconfig6 --file krdpserverrc --group General --key SystemUserEnabled true"
su astronaut -c "kwriteconfig6 --file krdpserverrc --group General --key Autostart true"
ln -s /lib/systemd/user/app-org.kde.krdpserver.service /home/astronaut/.config/systemd/user/graphical-session.target.wants/app-org.kde.krdpserver.service

# Enable vnc
enable_user_unit astronaut /home/astronaut/.astroarch/systemd/app-org.astroarch.vnc.service plasma-workspace.target

# Nuke notifications
su astronaut -c "cat <<EOF >/home/astronaut/.config/plasmanotifyrc
[DoNotDisturb]
WhenFullscreen=false
WhenScreensMirrored=false
EOF"

# Copy the config for kwinrc
su astronaut -c "cp /home/astronaut/.astroarch/configs/kwinrc /home/astronaut/.config"

# Create the folder (owned by astronaut) to store index files that requires no root access
su astronaut -c "mkdir -p /home/astronaut/.local/share/kstars/astrometry"

# Enable now all services
mkdir -p /etc/systemd/system/graphical.target.wants
ln -s /usr/lib/systemd/system/plasmalogin.service /etc/systemd/system/graphical.target.wants/plasmalogin.service
ln -s /usr/lib/systemd/system/novnc.service /etc/systemd/system/multi-user.target.wants/novnc.service
ln -s /usr/lib/systemd/system/dhcpcd.service /etc/systemd/system/multi-user.target.wants/dhcpcd.service
ln -s /usr/lib/systemd/system/NetworkManager.service /etc/systemd/system/multi-user.target.wants/NetworkManager.service
ln -s /usr/lib/systemd/system/avahi-daemon.service /etc/systemd/system/multi-user.target.wants/avahi-daemon.service
ln -s /usr/lib/systemd/system/nmb.service /etc/systemd/system/multi-user.target.wants/nmb.service
ln -s /usr/lib/systemd/system/smb.service /etc/systemd/system/multi-user.target.wants/smb.service

# Enable also the AP creation and resize scripts
ln -s /etc/systemd/system/create_ap.service /etc/systemd/system/multi-user.target.wants/create_ap.service
ln -s /etc/systemd/system/resize_once.service /etc/systemd/system/multi-user.target.wants/resize_once.service

# Take sudoers to the original state
sed -i 's/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers

# Copy wallpapers
su astronaut -c "cp /home/astronaut/.astroarch/wallpapers/bubble.jpg /home/astronaut/Pictures/wallpapers"
su astronaut -c "cp /home/astronaut/.astroarch/wallpapers/south-milky.jpg /home/astronaut/Pictures/wallpapers"
su astronaut -c "cp /home/astronaut/.astroarch/wallpapers/pacman.jpg /home/astronaut/Pictures/wallpapers"

# Autostart folder
su astronaut -c "mkdir /home/astronaut/.config/autostart"

# Copy desktop icons
su astronaut -c "ln -snf /usr/share/applications/org.kde.konsole.desktop /home/astronaut/Desktop/Konsole"
su astronaut -c "ln -snf /usr/share/applications/org.kde.kstars.desktop /home/astronaut/Desktop/Kstars"
su astronaut -c "ln -snf /usr/share/applications/astrodmx_capture.desktop /home/astronaut/Desktop/AstroDMx_capture"
su astronaut -c "ln -snf /usr/share/applications/phd2.desktop /home/astronaut/Desktop/PHD2"
su astronaut -c "ln -snf /home/astronaut/.astroarch/desktop/update-astroarch.desktop /home/astronaut/Desktop/update-astroarch"
su astronaut -c "ln -snf /home/astronaut/.astroarch/desktop/astroarch-tweak-tool.desktop /home/astronaut/Desktop/AstroArch-Tweak-Tool"
su astronaut -c "ln -snf /usr/share/astroarch_onboarding/desktop/AstroArch-onboarding.desktop /home/astronaut/Desktop/AstroArch-onboarding"

# Make the icons executable so there will be no ! on the first boot
chmod +x /home/astronaut/Desktop/update-astroarch
chmod +x /home/astronaut/Desktop/AstroArch-onboarding
chmod +x /home/astronaut/Desktop/AstroArch-Tweak-Tool

# Remove actual novnc icons
rm -r /usr/share/webapps/novnc/app/images/icons/*

# Copy custom novnc icons folder
cp -r /home/astronaut/.astroarch/assets/icons/* /usr/share/webapps/novnc/app/images/icons

# config hostnames
echo "astroarch" > /etc/hostname
echo "127.0.0.1          localhost" >> /etc/hosts
echo "127.0.1.1          astroarch" >> /etc/hosts

# Copy the screensaver config, by default it is off
su astronaut -c "cp /home/astronaut/.astroarch/configs/kscreenlockerrc /home/astronaut/.config/kscreenlockerrc"

# Never dim, turn off or suspend: with nobody at the Pi, VNC and RDP would stop getting frames
install -m644 /home/astronaut/.astroarch/configs/powerdevilrc /etc/xdg/powerdevilrc

# Set a standard TZ to avoid breaking plasma clock widget
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime

# If we are on a raspberry let's adjust /boot/config.txt
cp /home/astronaut/.astroarch/configs/config.txt /boot/config.txt

install -o root -g root -m 644 /home/astronaut/.astroarch/configs/kdeglobals /etc/xdg/

# Config plasma theme AstroArch
cp -r /home/astronaut/.astroarch/configs/look-and-feel/astroarch /usr/share/plasma/look-and-feel/
cp -r /home/astronaut/.astroarch/configs/layout-templates/astroarchPanel /usr/share/plasma/layout-templates/

# Add user astronaut-kiosk
useradd -G wheel -m astronaut-kiosk
echo "astronaut-kiosk:astro" | chpasswd
usermod -aG uucp,sys,network,power,audio,input,lp,storage,video,users,astronaut astronaut-kiosk
usermod -aG astronaut-kiosk astronaut
chmod -R 777 /home/astronaut-kiosk
su astronaut-kiosk -c "LC_ALL=C.UTF-8 xdg-user-dirs-update --force"
su astronaut-kiosk -c "mkdir -p /home/astronaut-kiosk/.local/{bin,share,state}"
su astronaut-kiosk -c "mkdir -p /home/astronaut-kiosk/.config/systemd/user/graphical-session.target.wants"
su astronaut-kiosk -c "mkdir -p /home/astronaut-kiosk/.config/systemd/user/default.target.wants"

# Enable kiosk permissions krdp/vnc
enable_user_unit astronaut-kiosk /home/astronaut/.astroarch/systemd/astroarch-portal-permissions.service plasma-workspace.target

## KRDP ##
# astronaut-kiosk
su astronaut-kiosk -c "mkdir -p /home/astronaut-kiosk/.local/share/krdpserver"
kioskcertificatePath="/home/astronaut-kiosk/.local/share/krdpserver/krdp.crt"
kioskcertificateKeyPath="/home/astronaut-kiosk/.local/share/krdpserver/krdp.key"
su astronaut-kiosk -c "openssl req -nodes -new -x509 -keyout '$kioskcertificateKeyPath' -out '$kioskcertificatePath' -days 3650 -batch -subj '/CN=astroarch' -addext 'subjectAltName = DNS:astroarch'"
su astronaut-kiosk -c "kwriteconfig6 --file krdpserverrc --group General --key Certificate '$kioskcertificatePath'"
su astronaut-kiosk -c "kwriteconfig6 --file krdpserverrc --group General --key CertificateKey '$kioskcertificateKeyPath'"
su astronaut-kiosk -c "kwriteconfig6 --file krdpserverrc --group General --key SystemUserEnabled true"
su astronaut-kiosk -c "kwriteconfig6 --file krdpserverrc --group General --key Autostart true"
su astronaut-kiosk -c "kwriteconfig6 --file krdpserverrc --group General --key ListenPort 3390"
ln -s /lib/systemd/user/app-org.kde.krdpserver.service /home/astronaut-kiosk/.config/systemd/user/graphical-session.target.wants/app-org.kde.krdpserver.service

# Enable kiosk vnc
enable_user_unit astronaut-kiosk /home/astronaut/.astroarch/systemd/app-org.astroarch.vnc.service plasma-workspace.target
# Same unit as astronaut (same portal app id), only the VNC port differs: 5901
su astronaut-kiosk -c "mkdir -p /home/astronaut-kiosk/.config/systemd/user/app-org.astroarch.vnc.service.d"
ln -sfn /home/astronaut/.astroarch/systemd/kiosk-vnc-port.conf /home/astronaut-kiosk/.config/systemd/user/app-org.astroarch.vnc.service.d/port.conf

# Kiosk session: headless Plasma next to the desktop, started at boot by the kiosk user
# manager (astronaut-kiosk lingers, see below). KWin draws on a virtual output, KRdp gives
# each RDP client an output sized to its window
enable_user_unit astronaut-kiosk /home/astronaut/.astroarch/systemd/astroarch-kiosk-session.service default.target
enable_user_unit astronaut-kiosk /home/astronaut/.astroarch/systemd/astroarch-kiosk-rdp-output.service
# On X11 .xinitrc ran 00-init-layout.sh at the first kiosk start
enable_user_unit astronaut-kiosk /home/astronaut/.astroarch/systemd/astroarch-kiosk-layout.service plasma-workspace.target
su astronaut-kiosk -c "mkdir -p /home/astronaut-kiosk/.config/systemd/user/plasma-kwin_wayland.service.d /home/astronaut-kiosk/.config/systemd/user/app-org.kde.krdpserver.service.d"
ln -sfn /home/astronaut/.astroarch/configs/kiosk/kwin-headless.conf /home/astronaut-kiosk/.config/systemd/user/plasma-kwin_wayland.service.d/headless.conf
ln -sfn /home/astronaut/.astroarch/configs/kiosk/krdpserver-kiosk.conf /home/astronaut-kiosk/.config/systemd/user/app-org.kde.krdpserver.service.d/kiosk.conf

# Kiosk apps: astroarch-kiosk-app@<app> units, turned on and off by the kiosk configurator
ln -sfn /home/astronaut/.astroarch/systemd/astroarch-kiosk-app@.service /home/astronaut-kiosk/.config/systemd/user/astroarch-kiosk-app@.service
chown -h astronaut-kiosk:astronaut-kiosk /home/astronaut-kiosk/.config/systemd/user/astroarch-kiosk-app@.service
# Only those units start apps: Plasma session restore would start a second copy
su astronaut-kiosk -c "kwriteconfig6 --file ksmserverrc --group General --key loginMode emptySession"

# Shutdown and reboot without a password, from the desktop or the kiosk
cp /home/astronaut/.astroarch/configs/kiosk/45-allow-shutdown-kiosk.rules /etc/polkit-1/rules.d/

# Copy wallpapers
su astronaut-kiosk -c "mkdir -p /home/astronaut-kiosk/Pictures/wallpapers"
cp /home/astronaut/.astroarch/configs/kiosk/astroarch-kiosk.png /home/astronaut-kiosk/Pictures/wallpapers/

# Add menu
cp -r /home/astronaut/.astroarch/configs/kiosk/menus /home/astronaut-kiosk/.config/

# Copy kstars folders
cp -R /home/astronaut/.local/share/kstars /home/astronaut-kiosk/.local/share/

su astronaut-kiosk -c "cat <<EOF >/home/astronaut-kiosk/.config/plasmanotifyrc
[DoNotDisturb]
WhenFullscreen=false
WhenScreensMirrored=false
EOF"

# Adjustment of user rights
chmod -R 777 /home/astronaut-kiosk
chown -R astronaut-kiosk:astronaut-kiosk /home/astronaut-kiosk

# Minimal desktop
ln -snf /home/astronaut/.astroarch/desktop/astroarch-config-kiosk.desktop /home/astronaut-kiosk/Desktop/Astroarch-config-Kiosk
ln -snf /home/astronaut/.astroarch/desktop/org.kde.konsole.desktop /home/astronaut-kiosk/Desktop/Konsole
ln -snf /home/astronaut/.astroarch/desktop/update-astroarch-kiosk.desktop /home/astronaut-kiosk/Desktop/update-astroarch

# Disable Kwallet by default
su astronaut -c "echo $'[Wallet]\nEnabled=false' > /home/astronaut/.config/kwalletrc"

# Modprobe brcmfmac
bash -c "echo \"options brcmfmac feature_disable=0x282000\" > /etc/modprobe.d/brcmfmac.conf"

# Fix 'Insecure completion-dependent directories detected'
chmod -R go-w /home/astronaut /home/astronaut-kiosk

# Give astronaut-kiosk rwx on the astronaut home, must run after any chmod
# since chmod -R go-w above strips the group-write bit it grants
bash /home/astronaut/.astroarch/scripts/kiosk-home-acl.sh

# Copy the screensaver config, by default it is off
# Must run after kiosk-home-acl.sh, which is what grants astronaut-kiosk
# read access to ~astronaut/.astroarch in the first place
su astronaut-kiosk -c "cp /home/astronaut/.astroarch/configs/kscreenlockerrc /home/astronaut-kiosk/.config/kscreenlockerrc"

# Shared data folder for astronaut and astronaut-kiosk (e.g. images saved by
# KStars), outside both homes with a ~/astro-data symlink in each. The default
# ACL that keeps it group writable is set at boot by systemd-tmpfiles, the
# Docker build has no ACL support
groupadd -f astro
usermod -aG astro astronaut
usermod -aG astro astronaut-kiosk
install -d -o root -g astro -m 2775 /srv/astro-data
cp /home/astronaut/.astroarch/configs/astro-data.conf /etc/tmpfiles.d/astro-data.conf
su astronaut -c "ln -snf /srv/astro-data /home/astronaut/astro-data"
su astronaut-kiosk -c "ln -snf /srv/astro-data /home/astronaut-kiosk/astro-data"

# Linger
mkdir -p /var/lib/systemd/linger
touch /var/lib/systemd/linger/astronaut
chown root:root /var/lib/systemd/linger/astronaut
chmod 644 /var/lib/systemd/linger/astronaut
touch /var/lib/systemd/linger/astronaut-kiosk
chown root:root /var/lib/systemd/linger/astronaut-kiosk
chmod 644 /var/lib/systemd/linger/astronaut-kiosk

# Override cmdline.txt
echo "root=UUID=$(blkid -s UUID -o value /dev/vda2) rw rootwait console=tty1 fsck.repair=yes video=HDMI-A-1:1920x1080M@60D" > /boot/cmdline.txt

# Reboot and enjoy now, if QEMU stop and add indexes
if [ "$HAS_VIRT" -eq 0 ]; then
    reboot
else
    echo "Astroarchization achieved, now it's your turn"
fi
