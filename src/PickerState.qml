pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "root:/"

// Shared state for the wallpaper picker — folder path, the image list,
// and the refresh trigger. Both bars' WallpaperPicker instances bind to
// these, so the popup is IDENTICAL on every screen (house rule: only the
// clicked screen's popup shows, but it always carries the same contents).
Singleton {
    id: root

    property string folder: (Theme.settings.wallpaperDir
        || (Quickshell.env("HOME") + "/Pictures/Wallpapers"))
    property var images: []

    function refresh() {
        if (listProc.running) return;
        listProc.running = true;
    }

    function setFolder(path) {
        root.folder = path;
        root.images = [];
        root.refresh();
    }

    Component.onCompleted: refresh()

    Process {
        id: listProc
        // Proper argv quoting — the folder never touches a shell string.
        command: ["bash", "-c",
            'find "$1" -maxdepth 1 -type f \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.avif" -o -iname "*.bmp" \\) -print | sort',
            "basalt-picker", root.folder]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                root.images = t ? t.split("\n") : [];
            }
        }
    }
}