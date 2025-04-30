#!/usr/bin/env bash

# DisableDownloadTimeout in pacman.conf
if [ $(grep -c DisableDownloadTimeout /etc/pacman.conf) -eq 0 ]; then
    sudo sed -i '/ParallelDownloads=5/aDisableDownloadTimeout' /etc/pacman.conf
fi

# Checkout latest changes from git
    cd /home/$USER/.astroarch
    git pull origin main
    cd - > /dev/null 2>&1

# clone git repo sc74
mkdir -p /home/astronaut/.astroarch/sc74
cd /home/astronaut/.astroarch/sc74
git clone -b 1.10 --single-branch https://github.com/sc74/astroarch.git /home/astronaut/.astroarch/sc74

# Update .zshrc
cp -rf /home/astronaut/.astroarch/sc74/configs/.zshrc /home/astronaut/.astroarch/configs

echo 'astro' | sudo -S echo ''

    # Function to convert a version (eg: 1.9 or 1.9.1) to a number (eg: 10900 or 10901)
    version_to_num() {
        local version=$1
        local major minor patch
        IFS='.' read -r major minor patch <<< "$version"
        minor=${minor:-0}
        patch=${patch:-0}
        printf "%d%02d%02d" "$major" "$minor" "$patch"
    }

    # Defining files and variables
    UPDATE_HISTORY="/home/astronaut/.astroarch/.update_history"
    if [ ! -f "$UPDATE_HISTORY" ]; then
        touch "$UPDATE_HISTORY"
    fi

    # Recovering the old version (although it will no longer be used for testing)
    if [ -f "/home/astronaut/.astroarch/configs/.astroarch.version" ]; then
        OLD_VER=$(cat /home/astronaut/.astroarch/configs/.astroarch.version)
    else
        OLD_VER="1.9.0"  # Default value if the file is missing
    fi

    # Update from Git repository
    cd /home/$USER/.astroarch
    git pull origin main
    cd - > /dev/null 2>&1

    # Reading the new version after updating
    if [ -f "/home/astronaut/.astroarch/configs/.astroarch.version" ]; then
        NEW_VER=$(cat /home/astronaut/.astroarch/configs/.astroarch.version)
    else
        echo "Error: Unable to read updated version of AstroArch"
        exit 1
    fi

    # Converting versions into digital format
    OLD_NUM=$(version_to_num "$OLD_VER")
    NEW_NUM=$(version_to_num "$NEW_VER")
    MIN_VERSION="1.9.0"
    MIN_NUM=$(version_to_num "$MIN_VERSION")

    echo "Old version : $OLD_VER ($OLD_NUM)"
    echo "New version : $NEW_VER ($NEW_NUM)"
    echo "Minimum version required : $MIN_VERSION ($MIN_NUM)"

    # Update Scripts Walkthrough
    for script in /home/astronaut/.astroarch/scripts/1.*.sh; do
        SCRIPT_BASENAME=$(basename "$script")
        # Recovering the version by removing only the .sh extension
        SCRIPT_VER=$(basename "$script" .sh)
        SCRIPT_NUM=$(version_to_num "$SCRIPT_VER")

        echo "Script Check : $SCRIPT_BASENAME (version $SCRIPT_VER, $SCRIPT_NUM, $MIN_NUM, $NEW_NUM)"

        # The script is only applied if:
        # - if the script is not in history
        # - The script version is strictly higher than the minimum version (1.9.0)
        if ! grep -Fq "$SCRIPT_BASENAME" "$UPDATE_HISTORY"; then
            if [[ $SCRIPT_NUM -gt $MIN_NUM ]]; then
                echo "=== Applying the update $SCRIPT_BASENAME... ==="
                    zsh "$script"
                echo "$SCRIPT_BASENAME" >> "$UPDATE_HISTORY"
                if [[ $SCRIPT_NUM -gt $NEW_NUM ]]; then
                    echo $SCRIPT_VER > /home/astronaut/.astroarch/configs/.astroarch.version
                    echo "update version"
                fi
            else
               echo "Already applied : $SCRIPT_BASENAME"
            fi
        else
            echo "Ignored : $SCRIPT_BASENAME"
        fi
    done

    # Temporary fix for kde-portal duplicated conf
    if [ -f /usr/share/xdg-desktop-portal/kde-portal.conf ]; then
        sudo mv /usr/share/xdg-desktop-portal/kde-portal.conf /usr/share/xdg-desktop-portal/kde-portal.conf.old
    fi;

    # Update the repo content
    yes | LC_ALL=en_US.UTF-8 sudo pacman -Sy

    # Update always keyring first, than all of the other packages
    yes | LC_ALL=en_US.UTF-8 sudo pacman -S archlinux-keyring --noconfirm

    # Now upgrade all system packages, but ask user to choose in case of conflicts/choices
    yes | LC_ALL=en_US.UTF-8 sudo pacman -Syu

# Update files for the driver vc4-kms-v3d #106
sudo cp /home/astronaut/.astroarch/sc74/configs/cmdline.txt /boot
sudo cp /home/astronaut/.astroarch/sc74/configs/config.txt /boot
sudo cp /home/astronaut/.astroarch/sc74/configs/xorg.conf /etc/X11/
sudo cp /home/astronaut/.astroarch/sc74/configs/99-v3d.conf /etc/X11/xorg.conf.d
sudo cp /home/astronaut/.astroarch/sc74/configs/kwinrc /home/astronaut/.config

# Delete repo sc74
sudo rm -Rf /home/astronaut/.astroarch/sc74

# Add some packages
yes | LC_ALL=en_US.UTF-8 sudo pacman -S spectacle nano

# Printer
yes | LC_ALL=en_US.UTF-8 sudo pacman -S cups cups-pdf
sudo systemctl enable cups.service

# Set local Hostname resolution
yes | LC_ALL=en_US.UTF-8 sudo pacman -S nss-mdns
sudo sed -i 's|hosts: mymachines |&mdns_minimal [NOTFOUND=return] |g' /etc/nsswitch.conf

########################################################################################
# This section allows you to install some packages from a GitHub repo. If the packages are on your site with a repo, install the packages in the packages section. Then copy the services to /etc/systemd/system and enable them

# Repository sc74.github.io
cd /home/astronaut/.astroarch
git clone https://github.com/sc74/sc74.github.io.git
sudo sed -i 's|\[astromatto\]|\[sc74\]\nSigLevel = Optional TrustAll\nServer = file:///home/astronaut/.astroarch/sc74.github.io/aarch64\n\n\[astromatto\]|' /etc/pacman.conf
yes | LC_ALL=en_US.UTF-8 sudo pacman -Syu
# Install package astroarch-onboarding
yes | LC_ALL=en_US.UTF-8 sudo pacman -S astroarch-onboarding
sudo cp /home/astronaut/.astroarch/build-astroarch/systemd/astroarch-onboarding.service /etc/systemd/system/
sudo systemctl enable astroarch-onboarding.service

# Install some packages
yes | LC_ALL=en_US.UTF-8 sudo pacman -S rustdesk-bin indi-pylibcamera libcamera-rpi python-libcamera-rpi libcamera-ipa-rpi libcamera-docs-rpi libcamera-tools-rpi gst-plugin-libcamera-rpi python-pycamera2 rpicam-apps

# Delete repo sc74
sudo sed -i -e '/\[sc74\]/,+2d' /etc/pacman.conf


# delete repo sc74.github.io
sudo rm -Rf /home/astronaut/.astroarch/sc74.github.io

########################################################################################

echo "Reboot system now"
read -p "Press enter to continue"
reboot
