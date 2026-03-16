#!/bin/sh

FLAG_FILE="$HOME/.config/kiosk_setup_done"

if [ -f "$FLAG_FILE" ]; then
    exit 0
fi

while ! qdbus6 org.kde.plasmashell /PlasmaShell >/dev/null 2>&1; do
    sleep 0.5
done

qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
// Apply wallpapers
var allDesktops = desktops();
for (var i in allDesktops) {
    allDesktops[i].wallpaperPlugin = "org.kde.image";
    allDesktops[i].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    allDesktops[i].writeConfig("Image", "file:///home/astronaut-kiosk/Pictures/wallpapers/astroarch-kiosk.png");
    allDesktops[i].writeConfig("FillMode", "0");
}

// Clean panels
var panels = panels();
for (var i in panels) {
    var widgets = panels[i].widgets();
    for (var j in widgets) {

        // Kickoff favorites
        if (widgets[j].type === "org.kde.plasma.kickoff") {
            widgets[j].currentConfigGroup = ["Configuration", "General"];
            widgets[j].writeConfig("favorites", []);
            widgets[j].writeConfig("systemFavorites", false);
            widgets[j].reloadConfig();
        }

        // Clear task manager launchers
        if (widgets[j].type === "org.kde.plasma.icontasks") {
            widgets[j].currentConfigGroup = ["Configuration", "General"];
            widgets[j].writeConfig("launchers", "");
            widgets[j].reloadConfig();
        }
    }
}'

kwriteconfig6 --file kscreenlockerrc --group Daemon --key Autolock false
kwriteconfig6 --file kscreenlockerrc --group Daemon --key Timeout 0
qdbus6 org.freedesktop.ScreenSaver /ScreenSaver configure

touch "$FLAG_FILE"
