loadTemplate("astroarchPanel")

var plasma = getApiVersion(1);

var layout = {
    "desktops": [
        {
            "applets": [
            ],
            "config": {
                "/": {
                    "ItemGeometriesHorizontal": "",
                    "formfactor": "0",
                    "immutability": "1",
                    "lastScreen": "0",
                    "wallpaperplugin": "org.kde.slideshow"
                },
                "/Wallpaper/org.kde.slideshow/General": {
                    "Image": "file:///home/astronaut/Pictures/wallpapers/pacman.jpg",
                    "SlidePaths": "/home/astronaut/Pictures/wallpapers/"
                }
            },
            "wallpaperPlugin": "org.kde.slideshow"
        }
    ],
    "serializationFormatVersion": "1"
}
;

plasma.loadSerializedLayout(layout);
