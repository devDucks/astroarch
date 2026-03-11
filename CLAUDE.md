# CLAUDE.md — AstroArch AI Assistant Guide

> This file provides context for AI assistants (Claude, Copilot, etc.) working in this repository. Read this before making any changes.

---

## Project Overview

**AstroArch** is a specialized Linux distribution based on **ArchLinux (aarch64)**, tailored for astrophotography and astronomical observation. It targets Raspberry Pi 4/5, PCs, and mini-PCs. The repo is **not a software application** — it is a collection of shell scripts, configuration files, systemd services, and Zsh plugins that together define and build an OS image.

- **Current Version:** 2.0.5 (tracked in `configs/.astroarch.version`)
- **Default user:** `astronaut` / password: `astro`
- **Hostname:** `astroarch`
- **License:** MIT
- **Architecture:** aarch64 ARM

---

## Repository Layout

```
astroarch/
├── astroarch_build.sh            # Main build script (entry point)
├── build-astroarch/              # Chroot and auxiliary build scripts
├── configs/                      # All system config files deployed to the live system
│   ├── .astroarch.version        # Tracks the installed version string
│   ├── .zshrc                    # Deployed as /home/astronaut/.zshrc
│   ├── config.txt                # Raspberry Pi firmware config (/boot/config.txt)
│   ├── cmdline.txt               # Kernel boot parameters
│   ├── kde_settings.conf         # SDDM display-manager config
│   ├── kwinrc                    # KDE Window Manager settings
│   ├── kdeglobals                # KDE global theme/color config
│   ├── smb.conf                  # Samba share config
│   ├── xorg.conf                 # X11 server config
│   ├── *.rules                   # udev and polkit rules
│   ├── look-and-feel/astroarch/  # Custom KDE Plasma theme
│   └── layout-templates/         # Plasma panel layout templates
├── desktop/                      # .desktop launcher files
├── plugins/                      # Zsh plugins (feature extensions)
│   ├── bluetooth/bluetooth.plugin.zsh
│   ├── ftp/ftp.plugin.zsh
│   ├── gps/gps.plugin.zsh
│   └── power_max_current/power_max_current.plugin.zsh
├── scripts/                      # Utility and maintenance scripts
│   ├── update-astroarch.sh       # System updater (called by .zshrc alias)
│   ├── astroarch-tweak-tool.zsh  # GUI tweak tool wrapper
│   ├── resize_partition.sh       # First-boot auto-resize
│   ├── 2.0.5.sh                  # Version-specific migration script
│   └── ...
├── systemd/                      # Systemd service unit files
├── wallpapers/                   # System wallpapers
├── assets/icons/                 # PNG/SVG icons referenced by .desktop files
├── README.md                     # End-user documentation
├── BUILD.md                      # Build instructions
└── CHANGELOG.md                  # Version history
```

---

## Technology Stack

| Layer | Technology |
|---|---|
| Base OS | ArchLinux (aarch64) |
| Package manager | pacman + paru (AUR) |
| Desktop | KDE Plasma (plasma-x11-session) |
| Display manager | SDDM (auto-login: astronaut) |
| Shell | Zsh + oh-my-zsh (theme: af-magic) |
| Remote access | TigerVNC :5900, noVNC :8080, XRDP :3389 |
| Astronomy | Kstars, PHD2, INDI / indi-3rdparty, astrometry.net |
| Scripting | Bash and Zsh exclusively — no Python, Node, or other runtimes in scripts |
| Hardware support | Raspberry Pi 4/5 camera, GPIO, I2C, SPI, GPS (gpsd), RTC |

---

## Development Workflows

### Making Changes

This repo is **configuration-as-code**. Changes here are deployed to a running system via:

```bash
# On the live AstroArch system:
update-astroarch   # git pull + runs version-specific migration script
```

Or by re-building a fresh image via `astroarch_build.sh`.

### Build Workflow

```
1. Start with ArchLinux ARM base image
2. Run astroarch_build.sh inside chroot
   └── installs packages, creates 'astronaut' user, sets up services
3. (Optional) Use build-astroarch/ scripts to build from an existing AstroArch install
4. Shrink image with pishrink-git
5. Compress with pigz → .img.gz artifact
```

The build script detects virtualization (`systemd-detect-virt`) and skips GPU/camera packages when running inside QEMU.

### Version Bumping

1. Update `configs/.astroarch.version` with new version string.
2. Create `scripts/X.X.X.sh` for any migration steps (package installs, config changes, service restarts).
3. The `update-astroarch()` function in `.zshrc` reads the version file and runs the matching script.
4. Update `CHANGELOG.md` with a summary.

### Rollback Versions

Pin specific package versions in `configs/.zshrc` using the established variables:

```bash
INDI_ROLLBACK_VERSION=2.1.3-1
KSTARS_ROLLBACK_VERSION=3.7.6-2
```

These are used by the `rollback-*` aliases defined in `.zshrc`.

---

## Coding Conventions

### Shell Scripts (Bash / Zsh)

- **Error handling:** Use `set -e` at the top of scripts that should abort on failure.
- **Variables:** `ALL_CAPS_WITH_UNDERSCORES` for configuration constants at file top.
- **Functions:**
  - Public (user-callable): `lowercase_with_underscores()` — e.g., `gps_on()`
  - Private (internal helpers): `_leading_underscore()` — e.g., `_zsh_gps_check_device_stream()`
- **Notifications:** Use `notify-send` with the AstroArch icon path for desktop notifications.
- **Comments:** `#` prefixed, placed above the block they describe.
- **pacman flags:** Always include `--noconfirm` in non-interactive pacman calls.

### Zsh Plugin Structure

Each plugin lives in `plugins/<name>/<name>.plugin.zsh` and follows this layout:

```zsh
# 1. Configuration variables (ALL_CAPS, leading underscore)
_ZSH_PLUGIN_CONF="/etc/default/something"

# 2. Private helper functions (leading underscore)
_check_dep_installed() { ... }

# 3. Public API functions (no leading underscore)
feature_on()  { ... }
feature_off() { ... }
feature_remove() { ... }
```

Plugins are sourced via `.zshrc`. Do not add plugins to `.zshrc` directly; instead add a `source` line pointing to the plugin file.

### Configuration Files

- Files in `configs/` are **deployed by symlink** from `~/.astroarch/configs/` to their target path during the build. Do not hard-code paths to the repo inside config files.
- Keep each config file focused on a single system concern (network, display, audio, etc.).
- Raspberry Pi-specific settings belong in `configs/config.txt` and `configs/cmdline.txt`.

### Desktop Launchers

`.desktop` files in `desktop/` must:
- Reference icons from `assets/icons/` (deployed to `/home/astronaut/.astroarch/assets/icons/`).
- Set `Terminal=true` if the script produces console output the user needs to see.

---

## Key Files to Know

| File | Why it matters |
|---|---|
| `astroarch_build.sh` | Entry point for building the whole distribution image |
| `configs/.zshrc` | User shell — defines aliases, update logic, rollback pins |
| `configs/.astroarch.version` | Single source of truth for the installed version |
| `plugins/gps/gps.plugin.zsh` | Most complex plugin; GPS baud detection, gpsd wiring, time sync |
| `scripts/update-astroarch.sh` | Called by the `update-astroarch` alias |
| `scripts/2.0.5.sh` | Current migration script — template for future versions |
| `configs/astroarch-maintained-packages-list.txt` | Watchlist checked during updates for dependency integrity |
| `systemd/x0vncserver.service` | Primary remote access service |

---

## What NOT to Do

- **Do not add Node.js, Python scripts, or other runtimes** to the shell plugin system. Plugins must be pure Zsh/Bash.
- **Do not edit config files in place on a live system** and then commit — always edit the file in `configs/` first, then re-deploy.
- **Do not use `pacman -Sy` alone** (partial upgrades break ArchLinux); always use `pacman -Syu` or `pacman -S <pkg>` after a full sync.
- **Do not hardcode the username `astronaut`** in new scripts where it can be avoided — prefer `$USER` or `$HOME`.
- **Do not skip `--noconfirm`** in automated/non-interactive pacman calls; it will block builds.
- **Do not push directly to `master`** without testing on a live or virtual AstroArch system first.

---

## Service Ports Reference

| Service | Port |
|---|---|
| TigerVNC (primary) | 5900 |
| TigerVNC (XRDP/display :10) | 5910 |
| noVNC browser | 8080 |
| XRDP (RDP protocol) | 3389 |
| SSH | 22 |
| Samba/SMB | 445 |

---

## Hardware Support Notes

- **Raspberry Pi firmware settings** are in `configs/config.txt`. This file is parsed by the firmware at boot — syntax errors here can make the board unbootable.
- **I2C / SPI / GPIO** are enabled by default. udev rules are in `configs/99-arch-gpio.rules`.
- **RTC overlays** (ds3231, ds1307, etc.) are commented examples in `config.txt`; enable per deployment.
- **Camera detection** uses `camera_auto_detect=1`; disable only when using legacy v1 camera modules.
- **WiFi power-save** is disabled via `configs/81-wifi-powersave.rules` to prevent VNC/SSH disconnects.

---

## Documentation Files

| File | Audience |
|---|---|
| `README.md` | End users — setup, VNC, troubleshooting, FAQ |
| `BUILD.md` | Developers — how to build images from scratch |
| `CHANGELOG.md` | Everyone — version history and upgrade notes |
| `CLAUDE.md` (this file) | AI assistants and developers — codebase conventions |
