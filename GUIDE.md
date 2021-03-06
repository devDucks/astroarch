Welcome to the astroarch wiki!

# Download
Please use this link to download astroarch gzipped img file => https://drive.google.com/file/d/1zENnDzZt8sNN_NX7eguw7Oz1pMvZAbQR/

# Burn the img to an SD
If you prefer a GUI, use [balenaHetcher](https://www.balena.io/etcher/) otherwise you can use the unix `dd` to flash it, and if you are using `dd` I think
there is nothing I shall explain to you :)

# First boot
After you burned the .img file to your SD, you _should_ be able to reach astroarch via VNC, however if you don't see the desktop or you can't connect to it
this likely means that the SD partition has not been expanded on the first boot, to solve this issue just **reboot your raspberry pi by unplugging it from the power**

# Connecting via browser (noVNC)
By default `AstroArch` will start a hostpot called `AstroArch`, to connect to that WiFi network use the password `astronomy`

noVNC is installed and it will start by default, if your pi is wired to your network you can connect to it with the follwing methods:
- **http://astroarch.local:8080/vnc.html**
- if the previous method doesn't work, find your raspberry pi IP, connect to it through your browser typing `http://RASPBERRY_IP:8080/vnc.html`
 
otherwise, if you want to connect to its hotspot, find the WiFi network `AstroArch` (the pass is `astronomy`) and type in your browser `http://10.42.0.1:8080/vnc.html`

Welcome to astro arch!


# Software available
the following software will be available, by category

### Astronomical
- Kstars
- phd2
- indi drivers (all of them) 

### OS
- alacritty (terminal)
- KDE Plasma (Desktop environment)
- pacman (package manager, this is **NOT** debian based and pacman instead of apt is your package manager
- NetworkManager (to manage networks)

### Connectivity
- x11vnc
- noVNC

# Reporting issues
AstroArch is actually in a beta state, things seems to work and look pretty stable. However should you find any issue please report them here https://github.com/MattBlack85/astroarch/issues this will help me tracking them and ship a fix for them
