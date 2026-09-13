pragma Singleton

import QtQuick
import Quickshell
import Quickshell

// Basalt Files — open/closed state for the file-manager window.
Singleton {
    id: root

    property bool open: false
    // Debug/inspection surface — the window writes its live state here.
    property string diag: ""

    function toggle() {
        root.open = !root.open;
    }
}
