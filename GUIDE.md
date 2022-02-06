Welcome to the astroarch wiki!

# Download
Please use this link to download astroarch tar gzipped img file => https://drive.google.com/file/d/1AykyUU6CjtIQWEIxDWG10vCpIx-JbSpI
# Burn the img to an SD
TODO

# First boot
After you burned the .img file to your SD, insert it and boot the system, you'll be logged in as user `astronaut`, the password (for sudoing and similar things) is `astro`

By default `AstroArch` will start a hostpot called `AstroArch`, to connect to that WiFi network use the password `astronomy`

noVNC is installed and it will start by default, if your pi is wired to your network, once you find your raspberry pi IP, connect to it through your browser typing `http://RASPBERRY_IP:8080/vnc.html` otherwise, if you are connected to the hotspot, type `http://10.42.0.1:8080/vnc.html`, you will be required to put a password which is `astronomy`! Welcome to astro arch!


# Software available
the following software will be available, by category

### Astronomical
- Kstars

### OS
- alacritty (terminal)
- lxQt (Desktop environment)
- pacman (package manager, this is **NOT** debian based and pacman instead of apt is your package manager
- NetworkManager (to manage networks)

### Connectivity
- x11vncserver
- noVNC

# Reporting issues
Being this is an **very** early alpha stage, should you find any issue please report them here https://github.com/MattBlack85/astroarch/issues this will help me tracking them and ship a fix for them