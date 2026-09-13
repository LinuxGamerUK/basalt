pragma Singleton

import QtQuick

// Basalt Files — open/closed state for the file-manager window.
Singleton {
    id: root

    property bool open: false

    function toggle() {
        root.open = !root.open;
    }
}
