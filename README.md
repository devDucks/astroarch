# Welcome to AstroArch! Astrophotography on ArchLinux for Raspberry Pi, PC and mini PC (works also on Manjaro and all Arch derived distros)

[![Discord chat][discord-badge]][discord-url] <= Join us on discord!

[discord-badge]: https://img.shields.io/discord/1100468635086106706?logo=discord&style=flat-square
[discord-url]: https://discord.gg/uJEQCZKBT8

![astroarch](https://github.com/devDucks/astroarch/assets/4163222/d26c8d0b-a5ad-404b-8c2d-ef0a04f2f19a)


Please find below some (hopefully) useful instructions, if you are here instead because you want to know how you can build this image from scratch, see [this](https://github.com/MattBlack85/astroarch/blob/main/BUILD.md)
 - [Quick video intro](#quick-video-intro-to-astroarch)
 - [What Raspberry is supported?](#what-raspberry-version-is-supported)
 - [Download](#download)
 - [Flash the image to SD](#flash-the-img-to-an-sd)
 - [On first boot - things to know](#first-boot)
 - [Connecting via noVNC (browser)](#connecting-via-browser-novnc)
 - [How can I boot from USB/SDD?](#boot-from-external-disk-usb-hdd-ssd-nvme)
 - [Kstars hours is not correct, how can I fix it?](#set-timezone)
 - [What are the passwords for the user and the hotspot?](#passwords)
 - [Useful commands](#useful-commands)
 - [List of available software](#software-available)
 - [How can I add a RTC to AstroArch?](#how-to-add-a-rtc)
 - [How to make a GPS dongle working?](#using-a-gps-dongle)
 - [How to enable bluetooth?](#how-to-enable-bluetooth)
 - [reporting problems](#reporting-issues)
 - [For PC/mini PC running an ArchLinux derived distro (Manjaro, ArcoLinux, etc.)](#use-only-the-astro-packages-mantained-for-astroarch-on-pc-and-mini-pc)


# What Raspberry version is supported?
AstroArch runs on any raspberry capable to run aarch64 OS, this means `Raspberry Pi 4` and of course `Raspberry Pi 5`

# Download
Please use this link to download the latest astroarch gzipped img file => https://drive.google.com/file/d/111VLsfO-G9PiHvtZUz7PRrjngkYxyHPc/view

# Flash the img to an SD
If you prefer a GUI, use [balenaHetcher](https://www.balena.io/etcher/) otherwise you can use the unix `dd` to flash it, and if you are using `dd` I think
there is nothing I shall explain to you :)

# First boot
After you burned the .img file to your SD, you _should_ be able to reach astroarch via VNC, however if you don't see the desktop or you can't connect to it
this likely means that unfortunately your raspberry pi rev cannot boot the image. In this case please plug a monitor and report here the output!
Once you are logged in the first thing you should do is update the system, open the terminal and type `update-astroarch` command

# Set timezone
Do not forget to set the right timezone! to do so run `sudo timedatectl set-timezone Foo/Bar` where Foo/Bar is something like `Europe/Rome`

# Passwords
To save you some time, here the default password you will need for AstroArch:
 - the user password for `astronaut` (which is the user used to login or for ssh) is `astro`
 - the password for the `AstroArch-XXXXXXX` WiFi hotspot is `astronomy`

# Use only the astro packages mantained for AstroArch on PC and mini PC
If you have an x64 distro based on ArchLinux on your PC and you just want to access the packages I mantain (kstas, phd2, stellarsolver, indi, indi libs and drivers) add my repo to your pacman.conf file (under /etc/pacman.conf) **before** the [core] section, the repo looks like the following
```
[astromatto]
SigLevel = Optional TrustAll
Server = http://astroarch.astromatto.com:9000/$arch
```

after that run `sudo pacman -Sy && sudo pacman -S kstars phd2 indi-3rdparty-drivers stellarsolver`

# Useful commands
The followings are some useful commands that you can run from the terminal so you don't have to deal with complicated stuff by yourself if you don't want to:
 - `update-astroarch` => this command will update system packages (including kstars, indi, etc. if there are new versions) and will pull any fix for astroarch itself, additionally will update the astroarch configuration that may bring in more commands etc.
 - `astro-rollback-indi` => rollback automatically indi to the previous version
 - `astro-rollback-kstars` => rollback automatically indi to the previous version
 - `astro-rollback-full` => rollback automatically indi and kstars to the previous version
 - `use-astro-bleeding-edge` => install bleeding edge packages for Kstars and INDI
 - `use-astro-stable` => install stable  packages for Kstars and INDI

# Connecting via browser (noVNC)
By default `AstroArch` will start a hostpot called `AstroArch`, to connect to that WiFi network use the password `astronomy`

noVNC is installed and it will start by default, if your pi is wired to your network you can connect to it with the follwing methods:
- **http://astroarch.local:8080/vnc.html**
- if the previous method doesn't work, find your raspberry pi IP, connect to it through your browser typing `http://RASPBERRY_IP:8080/vnc.html`

otherwise, if you want to connect to its hotspot, find the WiFi network `AstroArch` (the pass is `astronomy`) and type in your browser `http://10.42.0.1:8080/vnc.html`

Welcome to astro arch!

# Adding swap
By default astroarch don't have swap, for prevent issues about memory space you can add a swap file and enable it, we will set swappiness to 10 don't use swap file if RAM space is ok.
In this example we make a 2GB swapfile 
```
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile 
sudo mkswap /swapfile
sudo swapon /swapfile
sudo echo "vm.swappiness = 10" | sudo tee -a  /etc/sysctl.d/99-swappiness.conf
```

Check swappiness
```
$ cat /proc/sys/vm/swappiness
10
```
Check if Swap is enabled
```
free -h
```
Output should be something like this on Swap row :
```
$ free -h
               total        used        free      shared  buff/cache   available
Mem:           3.7Gi       1.4Gi       1.1Gi        88Mi       1.3Gi       2.3Gi
Swap:          2.0Gi          0B       2.0Gi
```
Make permanent swapfile on system
```
$ sudo echo "/swapfile   none    swap    sw              0       0" | sudo tee -a  /etc/fstab
```

# Boot from external disk (USB, HDD, SSD, NVME)
If you want to use an alternative media to boot AstroArch, just flash the image to your support and it will work out of the box! No special steps are required


# Software available
the following software will be available, by category

### Astronomical
- Kstars 3.6.9
- phd2 2.6.13dev1
- indi libs 2.0.6 **(all of them)**
- indi drivers 2.0.6 **(all of them)**
- most of the widefield indexes for plate solving
- astromonitor (you never heard of it? Check it here https://github.com/MattBlack85/astro_monitor)
- AstroDMx (a capture software like FireCapture)

### OS
- Konsole (terminal)
- KDE Plasma (Desktop environment)
- pacman (package manager, this is **NOT** debian based and pacman instead of apt is your package manager
- NetworkManager (to manage networks)
- Discovery (to install other packages)

### Connectivity
- tigervnc (x0vncserver)
- noVNC

### Browser
- chromium (like chrome, but without google tracking code)
- firefox

# How to add a RTC
Adding a RTC to AstroArch is easy from version 1.6.
First, wire your RTC to your pi, open a terminal and type `sudo i2cdetect -y 1` you should see a similar table, take note of the number for the next steps
![i2cdetect](https://github.com/devDucks/astroarch/assets/4163222/147f90ed-6f56-43ab-900b-0ad0c44f919c)

Now find the line `dtoverlay=i2c-rtc` in `/boot/config.txt` and modify it by adding a comma and the name of your RTC device, in my case for the ds3231 will be `dtoverlay=i2c-rtc,ds3231`

Reboot your Raspberry PI and if you type again `sudo i2cdetect -y 1` you should now see a `UU` instead of the number, this means the kernel module for your RTC has been loaded correctly.

That's all you need! We just enabled automatic modules to setup the system time from the RTC if it's present! No more steps are required!

Reboot your PI and you should have the time automatically synchronized when it starts!

If you want to remove the RTC sync just drop `,xxxx` from `/boot/config.txt` at line `dtoverlay=i2c-rtc,xxxx`

# Using a GPS dongle
TODO

# How to enable bluetooth
By default there are no packages to enabling bluetooth, to install them and enabling bluetooth functionalities run the following commands:
- `sudo pacman -S bluez bluez-utils bluez-hid2hci bluedevil`
- `sudo sed -i 's/#DiscoverableTimeout=0/DiscoverableTimeout=0/g' /etc/bluetooth/main.conf`
- `sudo sed -i 's/#AlwaysPairable=true/AlwaysPairable=true/g' /etc/bluetooth/main.conf`
- `sudo sed -i 's/#PairableTimeout=0/PairableTimeout=0/g' /etc/bluetooth/main.conf`
- `sudo sed -i 's/#AutoEnable=true/AutoEnable=true/g' /etc/bluetooth/main.conf`
- `sudo systemctl enable bluetooth --now`

# Reporting issues
AstroArch is actually in a stable state, however, should you find any issue please report them here https://github.com/MattBlack85/astroarch/issues this will help me tracking them and ship a fix for them

# Quick video intro to AstroArch

https://github.com/devDucks/astroarch/assets/4163222/27bb0842-2db0-4db7-83e5-c513c8e02f5a


