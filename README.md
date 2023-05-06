# Welcome to AstroArch! Astrophotography on ArchLinux for Raspberry Pis/x64, Manjaro and all Arch derived distros

[![Discord chat][discord-badge]][discord-url]

[discord-badge]: https://img.shields.io/discord/1100468635086106706?logo=discord&style=flat-square
[discord-url]: https://discord.gg/uJEQCZKBT8

![astroarch](https://user-images.githubusercontent.com/4163222/216557489-08221a7f-d835-4837-a219-1bc73f01f9c3.png)


If you have an x64 distro based on ArchLinux on your PC and you just want to access the packages I mantain (kstas, phd2, stellarsolver, indi, indi libs and drivers) add my repo to your pacman.conf file (under /etc/pacman.conf) **before** the [core] section, the repo looks like the following
```
[astromatto]
SigLevel = Optional TrustAll
Server = http://astroarch.astromatto.com:9000/$arch
```

Please find below some (hopefully) useful instructions, if you are here instead because you want to know how you can build this image from scratch, see [this](https://github.com/MattBlack85/astroarch/blob/main/BUILD.md)

<br />

# ⚠️ BE SURE TO READ THE FOLLOWING SECTION AT LEAST BEFORE STARTING ASTROARCH ⚠️
**AstroArch doesn't support yet HDMI, it means it works only via VNC and if you plug a monitor, you won't see the desktop although the system may be functional.**

**After acknowledging this fact, enjoy the rest of the read 🤓**

<br />
<br />
<br />


# If you are coming from version 1.3.1
Version **1.3.1** is the first image released, if you have that image and you never run `update-astroarch`, please download the new image (see the link below) as there is a small breaking change with the terminal.

If you had **1.3.1** and updated, you should be able to go to **1.5.0** by updating directly using `update-astroarch`.

If it is the first time you download the .img you are good to go

# Download
Please use this link to download the latest astroarch gzipped img file => https://drive.google.com/file/d/1KHSfrismTYFnyXq8FygNCtA_XaJvQPDi/view?usp=share_link

# Burn the img to an SD
If you prefer a GUI, use [balenaHetcher](https://www.balena.io/etcher/) otherwise you can use the unix `dd` to flash it, and if you are using `dd` I think
there is nothing I shall explain to you :)

# Useful commands
The followings are some useful commands that you can run from the terminal so you don't have to deal with complicated stuff by yourself if you don't want to:
 - `update-astroarch` => this command will update system packages (including kstars, indi, etc. if there are new versions) and will pull any fix for astroarch itself, additionally will update the astroarch configuration that may bring in more commands etc.
 - `astro-rollback-indi` => rollback automatically indi to the previous version
 - `astro-rollback-kstars` => rollback automatically indi to the previous version
 - `astro-rollback-full` => rollback automatically indi and kstars to the previous version

# First boot
After you burned the .img file to your SD, you _should_ be able to reach astroarch via VNC, however if you don't see the desktop or you can't connect to it
this likely means that unfortunately your raspberry pi rev cannot boot the image. In this case please plug a monitor and report here the output!
Once you are logged in the first thing you should do is update the system, open the terminal and type `update-astroarch` command

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
- Kstars 3.6.4
- phd2 2.6.11dev4
- indi libs 2.0.1 **(all of them)**
- indi drivers 2.0.1 **(all of them)**
- most of the widefield indexes for plate solving
- astromonitor (you never heard of it? Check it here https://github.com/MattBlack85/astro_monitor) 

### OS
- Konsole (terminal)
- KDE Plasma (Desktop environment)
- pacman (package manager, this is **NOT** debian based and pacman instead of apt is your package manager
- NetworkManager (to manage networks)

### Connectivity
- x11vnc
- noVNC

# Reporting issues
AstroArch is actually in a stable state, however, should you find any issue please report them here https://github.com/MattBlack85/astroarch/issues this will help me tracking them and ship a fix for them
