#!/usr/bin/env bash

# First run 1.9.2.sh to be sure that old changes will be applied
bash /home/astronaut/.astroarch/scripts/1.9.2.sh

check_asn=$(pacman -Q | grep -c astroarch-status-notifications)

if [ $check_asn -eq 0 ]; then
    echo "===================="
    echo "AA status notifications not found... Installing"
    sudo pacman -Sy astroarch-status-notifications --noconfirm
    echo "AA status notifications installed"
    echo "===================="
fi
