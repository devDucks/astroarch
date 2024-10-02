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
 - [Connecting via VNC client (this is the preferred way)](#connecting-via-vnc-client)
 - [How can I use a raspberry camera?](#how-can-i-use-a-raspberry-camera)
 - [How can I boot from USB/SDD?](#boot-from-external-disk-usb-hdd-ssd-nvme)
 - [Kstars hours is not correct, how can I fix it?](#set-timezone)
 - [What are the passwords for the user and the hotspot?](#passwords)
 - [Protect VNC with a password](#how-to-protect-vnc-with-password)
 - [Useful commands](#useful-commands)
 - [List of available software](#software-available)
 - [How can I add a RTC to AstroArch?](#how-to-add-a-rtc)
 - [How to make a GPS dongle working?](#using-a-gps-dongle)
 - [How to enable bluetooth?](#how-to-enable-bluetooth)
 - [How to enable an FTP server?](#how-to-enable-FTP)
 - [Where can I find more packages?](#where-to-find-more-pacakges)
 - [How can I install Python packages?](#how-to-install-python-packages)
 - [reporting problems](#reporting-issues)
 - [For PC/mini PC running an ArchLinux derived distro (Manjaro, ArcoLinux, etc.)](#use-only-the-astro-packages-mantained-for-astroarch-on-pc-and-mini-pc)


# What Raspberry version is supported?
AstroArch runs on any raspberry capable to run aarch64 OS, this means `Raspberry Pi 4` and of course `Raspberry Pi 5`

# Download
Please use this link to download the latest astroarch gzipped img file => https://drive.google.com/file/d/1S4lGyRT1soCdO8QAUk5gmDEXj6T2_b2g/view

# Flash the img to an SD
If you prefer a GUI, use [balenaHetcher](https://www.balena.io/etcher/) otherwise you can use the unix `dd` to flash it, and if you are using `dd` I think
there is nothing I shall explain to you :)

# First boot
After you burned the .img file to your SD, you _should_ be able to reach astroarch via VNC, however if you don't see the desktop or you can't connect to it
this likely means that unfortunately your raspberry pi rev cannot boot the image. In this case please plug a monitor and report here the output!
Once you are logged in the first thing you should do is update the system, open the terminal and type `update-astroarch` command

# Set timezone
Here a small video that will show you how to set the timezone without the terminal

https://github.com/devDucks/astroarch/assets/4163222/a935b491-5b7a-444d-9f89-a01a279063de

If you want to use the terminal list first the available timezone with `timedatecl list-timezones` and then set the right one with `tsudo timedatectl set-timezone Foo/Bar` where Foo/Bar is something like `Europe/Rome`

Do not forget to set the right timezone! 

# Passwords
To save you some time, here the default password you will need for AstroArch:
 - the user password for `astronaut` (which is the user used to login or for ssh) is `astro`
 - the password for the `AstroArch-XXXXXXX` WiFi hotspot is `astronomy`

# How to protect VNC with password
If you want to add more security to your installation (or maybe you are at a starparty with more users running AstroArch), you may want to add a password to VNC (by default there is no password).
To do so first set a password running `sudo vncpasswd` and after that edit `/etc/systemd/system/x0vncserver.service` changing the ExecStart line from this


```
ExecStart=x0vncserver -display :0 -SecurityTypes None
```


to this


```
ExecStart=x0vncserver -display:0 -rfbauth /root/.vnc/passwd
```

Reboot and now you should be prompted to input a password when connecting via VNC

# How can I use a raspberry camera
AstroArch finally supports raspberry cameras via indi pylibcamera, to install it and having fun with it just run `sudo pacman -S indi-pylibcamera`

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

The AstroArch Tweak Tool utility allows you to easily run all these commands

# Connecting via browser (noVNC)
By default `AstroArch` will start a hostpot called `AstroArch`, to connect to that WiFi network use the password `astronomy`

noVNC is installed and it will start by default, if your pi is wired to your network you can connect to it with the follwing methods:
- **http://astroarch.local:8080/vnc.html**
- if the previous method doesn't work, find your raspberry pi IP, connect to it through your browser typing `http://RASPBERRY_IP:8080/vnc.html`

otherwise, if you want to connect to its hotspot, find the WiFi network `AstroArch` (the pass is `astronomy`) and type in your browser `http://10.42.0.1:8080/vnc.html`

Welcome to astro arch!

# Connecting via VNC client
If you trust me, this should be always the preferred way to connect usig VNC. noVNC goes through the browser and is less fluid and performant than a real VNC client.
You can use whatever VNC client you prefer, there should be no issue.

The address is `astroarch.local` (or the IP if you prefer) and the port is 5900

Few VNC client suggestions (work an all platforms):
- TigerVNC (https://tigervnc.org/)
- RealVNC (https://www.realvnc.com/en/)

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
If you want to use an alternative media to boot AstroArch, just flash the image to your support and it will work out of the box for USB and SSDs! No special steps are required

If you have a NVMe there are some additional steps to be able to boot from it:
- install rpi-eeprom with `sudo pacman -S rpi5-eeprom` (or rpi4-eeprom if you have a rasberry4)
- be sure to run the latest eeprom firmware `sudo rpi-eeprom-update -a`
- *be sure to read this table https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#boot_order-fields*
- decide the boot order for your raspberry, bear in mind that the priority goes right to left, so for example, if you want your boot
  to be something like NVMe first, then USB then SD card the values to put in the `BOOT_ORDER` field would be 641 but since it's reversed we should put 146
  with a final value (put always the f) of `0xf146`
- create a new file with the following command 
```sh
cat>eeprom.conf<<EOF
[all]
BOOT_UART=1
WAKE_ON_GPIO=0
POWER_OFF_ON_HALT=1
BOOT_ORDER=0xf146
PCIE_PROBE=1
EOF
```
- apply the eeprom settings `sudo rpi-eeprom-config --apply eeprom.conf`
- remove the eeprom settings created in the previous steps `rm eeprom.conf`
- the eeprom update requires a reboot, so be sure to reboot your pi

# Software available
the following software will be available, by category

### Astronomical
- Kstars 3.7.2
- phd2 2.6.13dev1
- indi libs 2.0.9 **(all of them)**
- indi drivers 2.0.9 **(all of them)**
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
To use a GPS dongle, simply plug in your device and activate the GPSD service which is disabled by default. So the only command required is sudo systemctl enable gpsd --now and the service will start automatically after each boot. You can also manually edit /etc/gpsd and hardcode the device path on the DEVICES="" line with DEVICES="/dev/gps0"

Otherwise, simply use the following command `gps_on` to perform these two operations.

For users of a GPS USB dongle models u-blox 7 or VK-162 with a mount using the eqmod module, use the `gps_ublox_on` command. This helps avoid a conflict between the GPS and the mount.

For GPS UART users, use the `gps_uart_on` command.

If you want to disable automatic startup of the GPS daemon, run `gps_off`.

ADDITIONAL CONSIDERATIONS (use these as guidelines):

If you are having trouble getting the signal, you may need to protect your USB3 cables (they interfere with the GPS signal)
if the device is not recognized (which is very unlikely on ArchLinux), we do not recommend using ttyXXX as it may point to other serial devices after a reboot

These commands are in the AstroArch Tweak Tool utility

# How to enable bluetooth
By default there are no packages to enabling bluetooth, to install them and enabling bluetooth functionalities run the following command `bluetooth_on`, this command will install the BT packages and enable the bluetooth daemon to run automatically at boot.
If you want to disable bluetooth daemon autostart just run `bluetooth_off` and if you want to remove it run `bluetooth_remove`. These commands are in the AstroArch Tweak Tool utility

# How to enable FTP
Identical to Bluetooth, there is no default package to activate an FTP server.

To install and activate it, run the following command `ftp_on`. This command will install the Very Secure FTP Daemon package and allow the FTP server to run automatically on startup.

To connect from a remote station, use an FTP client such as FileZilla or other. All you need to do is identify yourself with the astronaut user, his password and the IP address where the server is located. You will easily find the IP address of your LAN or WLAN with the ifconfig command in a console. Once connected, you can very quickly transfer your files in both directions.

If you want to disable the automatic start of the FTP server, simply run `ftp_off` and if you want to remove it, run `ftp_remove`. 

These commands are in the AstroArch Tweak Tool utility

# Where to find more packages?
If you want to install more packages you should look what is available here https://archlinuxarm.org/packages - if you find the package there you can easily install it running `sudo pacman -S PACKAGE_NAME`,
if you want to install packages using a GUI instead, open discovery (the blue bag icon on the tray) and follow the instructions.

If the package you are looking for is not there you may additionally have a look at the AUR https://aur.archlinux.org/ - AUR is a list of packages mantained by the community,
they are not ready to be installed so they can't be installed with pacman but instead you need `paru` (already installed on AstroArch), if you find your package on the AUR run `paru -S PACKAGE_NAME`
it will ask you for a review (confirm it) and then it will compile the package for you and install it. Please be patient, some packages are just huges and it may take some time to compile on lower hardware like the raspberry.
Even for AUR there is a graphical installer (although I never used it and I cannot guarantee if it works well or not), run `sudo pacman -S pamac-full` and you can run `pamac` to install graphically packages from the AUR.

What if your package is not in the AUR or the offcial ArchLinux repository? Please let me know, it is not hard to package stuff for ArchLinux and in fact I already do it for few things, I can take a look at the source and if possible I will try to package
it for Arch so that you may be able to install it using pacman.

# How to install Python packages?
PLEASE READ THIS CAREFULLY

Python packages via pip installing has changed over time and it now looks way more different than it was years ago, this may looks like a cultural shock if you are coming from more stable distros (Debian and similar) that still didn't catch up with this change but bear with us;
installing packages via pip globally is not supported anymore by default (sudo pip install) cause it messes up distro packaging. If you try to do so you will see an error message suggesting to use a virtual environment (which, by the way, is a GREAT suggestion).
Sometimes vietual envs are not simply possible, so there are 3 ways to achieve the wanted result:
1) install the package via the package manager (pacman) - if the python package you want to install is a common one, there is a big chance it's been packaged for ArchLinux already and you can install it with pacman - BEST WAY
2) open an issue here on github and let me know what python packages you would like to see available to be installed via `pacman`, it will take few days to few weeks depending on availability but it is doable - RECOMMENDED WAY if 1 is not possible
3) bypass the pip check and force a global install running `sudo pip install --break-system-packages PACKAGE_NAME` - NOT RECOMMENDED and likely to break other dependencies in the long run, if you do so, we do not offer any support, sorry!

# Reporting issues
AstroArch is actually in a stable state, however, should you find any issue please report them here https://github.com/MattBlack85/astroarch/issues this will help me tracking them and ship a fix for them

# Quick video intro to AstroArch

https://github.com/devDucks/astroarch/assets/4163222/27bb0842-2db0-4db7-83e5-c513c8e02f5a


