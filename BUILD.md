This is the main bag to build an aarch64 ISO using arch linux that will be focused around astronomical software like kstars and indi.


**!!! DRAGONS AHEAD !!!**

**If you are here you likely know what you're going to do, this section is strictly for people who wants to test how to build the .img
 I package from scratch**


The guide is for the raspberry pi aarch64 version of arch linux but it should work with any version.

# How to build the ISO


## Prepare the SD card
Insert the SD card into your PC and check under which device name it presents itself (it may be `/dev/sdX` or `/dev/mmcblkX`), the guide will assume
it's `/dev/mmcblk0`, if your PC mounts the card automatically **you need to unmount it before proceeding**

The next commands assume that after `type X` an `enter` is given to confirm the command

- Run fdisk typing `sudo fdisk /dev/mmcblk0`
- type `o` this will wipe all the existing partitions from the card
- type `n` then `p` then `1`, when prompted for the first sector press `enter`, when prompted for the last sector type `+512M` (some guides report `100M` but from
personal experience that is not enough as after all updates the boot partition will be full)
- type `t` and then type `0c` to modify the just created partition to `W95FAT LBA`
- type `n` then `p` and take note of the number under `End` this will be used as starting point for the next partition
- type `n` then `p` then `2`, when prompted for the `First sector` check if the default value is bigger than the number you noted before, if it's bigger confirm
with `enter` otherwise add 1 to the number annotated before and use it in this step
- confirm the `Last sector` with enter
- type `w` to write the changes to the card, this will also exit fdisk.
- type `sudo mkfs.vfat /dev/mmcblk0p1` (/dev/sdX1 for sd like devices)
- type `sudo mkfs.ext4 /dev/mmcblk0p2`

At this point the SD card is ready!

## Raspberry Pi 4 C0 (sd issue on boot)
BE AWARE AND READ THIS!
If you have a recent model marked as C0 (look here https://archlinuxarm.org/forum/viewtopic.php?f=67&t=15422&start=20)
You need to tweak 2 things to be able to boot:
 1) You don't need to do the sed command from the next step and you don't need to add the second entry in `/etc/fstab`
 2) you additionally need to edit `/boot/boot.txt`, edit the two lines starting with `booti` changing `fdt_addr_r` to `fdt_addr`
 3) run `sudo ./mkscr` within the `boot/` folder after 2 otherwise the changes won't be written into the bootloader

## Burn the iso to the SD card

We will proceed with moving the arch iso to the SD card

- `mkdir arch-install && cd arch-install`
- `mkdir boot`
- `mkdir root`
- `wget http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz`
- `sudo mount /dev/mmcblk0p1 boot/`
- `sudo mount /dev/mmcblk0p2 root/`
- `bsdtar -xpf ArchLinuxARM-rpi-aarch64-latest.tar.gz -C root`
- `sudo mv root/boot/* boot`
- `sudo sed -i 's/mmcblk0/mmcblk1/g' root/etc/fstab`
-  edit the file `root/etc/fstab` adding the following line `/dev/mmcblk1p2  /       ext4    defaults        0       0`
- `sudo umount boot/ root/`

Congratz! Your SD card is ready, insert it into your raspberry and boot it!

## First boot

Connect your raspberry pi to your netowork via an ethernet cable, you can ssh into it after the boot using `ssh alarm@IP_OF_YOUR_RASPBERRY` the password will
be `alarm`

You'll be dropped into `alarm` shell and now we can proceed:
- become sudo with `su -` the password is `root`
- type `curl https://raw.githubusercontent.com/devDucks/astroarch/main/astroarch_build.sh > astroarch_build.sh`
- type `bash astroarch_build.sh`

This is the only thing required, the rest of the procedure is fully automated!

## Manual steps to finalize the image
After reboot, few final steps may be made to improve further the final image, mainly:
- Use UUID in `/etc/fstab` so that the image can start with every media attached (SD, USB, HDD, SDD)
  Dump the following table into `/etc/fstab`, to know the partition id simply run `sudo blkid` and look for UUID values
  ```
  # Static information about the filesystems.
  # See fstab(5) for details.

  # <file system> <dir> <type> <options> <dump> <pass>
  UUID=XXXX-XXXX  /boot   vfat    defaults        0       0
  UUID=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX  / ext4 defaults 0 1
  ```
- Set the theme to dark breeze
- Set a wallpaper
- Edit `/boot/cmdline.txt` replacing the default content with
  ```
  root=UUID=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX rw rootwait console=serial0,115200 console=tty1 fsck.repair=yes plymouth.ignore-serial-consoles video=HDMI-A-1:1920x1080@60D
  ```
- start Kstars without acknowledging any message, start ekos simulator, go to the guiding tab and download the most common indexes
- enable the resize script to do its magic on the user's first boot - run `sudo systemctl enable resize_once`
- enable the access point script to do its magic on the user's first boot - run `sudo systemctl enable create_ap`

Now the raspberry can be turned off and the image packaging can start

## Repackaging .img file

Once astroarch has been fully bootstrapped the image can be repackaged to be distributed

Using `pishrink` follow these steps:
- create a .img file of the SD card with `sudo dd if=/dev/mmcblk0 of=astroarch.img bs=8M status=progress` (if mmcblk0 is not the raspberry SD card, change accordingly)
- `sudo ./pishrink.sh -za astroarch.img astroarch-X.X.X.img.gz`

the gzipped image is ready to be distributed and can be flashed on other media
