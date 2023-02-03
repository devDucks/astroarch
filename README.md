# Welcome to the AstroArch! Astrophotography on ArchLinux for Raspberry Pis/x64 and Manjaro and all Arch derived distros

If you have an x64 distro based on ArchLinux on your PC and you just want to access the packages I mantain (kstas, phd2, stellarsolver, indi, indi libs and drivers add my repo to your pacman.conf file (under /etc/pacman.conf) **before** the [core] section, the repo looks like the following
```
[astromatto]
SigLevel = Optional TrustAll
Server = http://astroarch.astromatto.com:9000/$arch
```

Please find below some (hopefully) useful instructions, if you are here instead because you want to know how you can build this image from scratch, see [this](https://github.com/MattBlack85/astroarch/blob/main/BUILD.md)

# Download
Please use this link to download astroarch gzipped img file => https://drive.google.com/file/d/1jYBeKFioCXWDqEf0wk0shj0Dn7eJ8dcX/

# Burn the img to an SD
If you prefer a GUI, use [balenaHetcher](https://www.balena.io/etcher/) otherwise you can use the unix `dd` to flash it, and if you are using `dd` I think
there is nothing I shall explain to you :)

# First boot
After you burned the .img file to your SD, you _should_ be able to reach astroarch via VNC, however if you don't see the desktop or you can't connect to it
this likely means that unfortunately your raspberry pi rev cannot boot the image. In this case please plug a monitor and report here the output! 

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
- most of the widefield indexes for plate solving
- astromonitor (you never heard of it? Check it here https://github.com/MattBlack85/astro_monitor) 

### OS
- alacritty (terminal) **TO BE DEPRECATED IN 1.5**
- KDE Plasma (Desktop environment)
- pacman (package manager, this is **NOT** debian based and pacman instead of apt is your package manager
- NetworkManager (to manage networks)

### Connectivity
- x11vnc
- noVNC

# Reporting issues
AstroArch is actually in a stable state, however, should you find any issue please report them here https://github.com/MattBlack85/astroarch/issues this will help me tracking them and ship a fix for them
