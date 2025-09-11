This guide is for the Raspberry Pi aarch64 version of Arch Linux.

## Compiling with an AstroArch script from an existing version
## (as described here: https://wiki.archlinux.org/title/Install_Arch_Linux_from_existing_Linux)

Copy the build-astroarch directory from the GitHub site https://github.com/astroarch/build-astroarch into your home directory.

Make the .sh files executable with the command chown +x followed by the filename. Add a hard drive or SD card to your Raspberry Pi and simply run the command AA_build_fromAA.sh.

The script will simply ask you which device you want to install AstroArch on. Specify the hard drive or SD card you just mounted.

At the end of the process, you will have a working installation on your disk and an image to install.

The AA_build_fromAA.sh script allows you to pass the files needed for compilation.

The astroarch_build_chroot.sh script compiles the operating system. You can add packages, services, and any other files to customize your configuration.


