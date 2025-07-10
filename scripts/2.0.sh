#!/usr/bin/env bash

# First run 1.9.3.sh to be sure that old changes will be applied
bash /home/astronaut/.astroarch/scripts/1.9.3.sh

if [ ! -f /home/astronaut/Desktop/update-astroarch ]; then
    echo "===================="
    echo "Update astroarch script not found... Installing"
    su astronaut -c "cp /home/astronaut/.astroarch/desktop/update-astroarch.desktop /home/astronaut/Desktop/update-astroarch"
    sudo chmod +x /home/astronaut/Desktop/update-astroarch
    echo "Update AstroArch script installed"
    echo "===================="
fi
