#!/usr/bin/env bash

# The repo and the update-astroarch function belong to astronaut, so the kiosk
# runs the update as astronaut. DISPLAY is dropped because astronaut cannot
# open the kiosk X display, the dependency prompt then falls back to the terminal
konsole -e sudo -iu astronaut env -u DISPLAY -u XAUTHORITY /usr/bin/zsh -i -c update-astroarch
