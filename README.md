# astroarch

This is the main bag to build an aarch64 ISO using arch linux that will be focused around astronomical software like kstars and indi.
You won't probably (very very probably) want to build the ISO from scratch using this repo but rather downloading a ready one that can be burned to a SD card,
in case you really want to try, the next sections will guide you through the entire procedure.

The guide is for the raspberry pi aarhc64 version of arch linux but it should work with any version.

# How to build the ISO


## Prepare the SD card
Insert the SD card into your PC and check under which device name it presents itself (it may be `/dev/sdX` or `/dev/mmcblkX`), the guide will assume
it's `/dev/mmcblk0`, if your PC mounts the card automatically **you need to unmount it before proceeding**

The next commands assume that after `type X` an `enter` is given to confirm the command

- Run fdisk typing `sudo fdisk /dev/mmcblk0`
- type `o` this will wipe all the existing partitions from the card
- type `n` then `p` then `1`, when prompted for the first sector press `enter`, when prompted for the last sector type `+256M` (some guides report `100M` but from
personal experience that is not enough)
- type `t` and then type `0c` to modify the just created partition to `W95FAT LBA`
- type `p` and take note of the number under `End` this will be used as starting point for the next partition
- type `n` then `p` then `2`, when prompted for the `First sector` check if the default value is bigger than the number you noted before, if it's bigger confirm
with `enter` otherwise add 1 to the number annotated before and use it in this step
- confirm the `Last sector` with enter
- type `w` to write the changes to the card, this will also exit fdisk.
- type `sudo mkfs.vfat /dev/mmcblk0p1` (/dev/sdX1 for sd like devices)
- type `sudo mkfs.ext4 /dev/mmcblk0p2`

At this point the SD card is ready!

## Burn the iso to the SD card
TODO
