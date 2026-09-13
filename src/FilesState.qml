pragma Singleton

import QtQuick
import Quickshell

// Basalt Files — open state for the file-manager window (house rule:
// one window, on the focused screen, shared singleton state).
Singleton {
    id: root

    // "" = closed; otherwise the screen name the window is open on.
    property string screen: ""

    function toggle() {
        root.screen = "";
    }

    function toggleOnScreen(name) {
        root.screen = (root.screen === name) ? "" : name;
    }
}
