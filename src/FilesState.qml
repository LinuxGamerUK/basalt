pragma Singleton

import QtQuick
import Quickshell
import Quickshell

// Basalt Files — open/closed state for the file-manager window.
Singleton {
    id: root

    property bool open: true  // debug: force-open at boot

    function toggle() {
        root.open = !root.open;
    }
}
