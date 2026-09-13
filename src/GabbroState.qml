pragma Singleton

import QtQuick
import Quickshell

// Basalt Gabbro — open state for the file-manager window (house rule:
// one window, on the focused screen, shared singleton state).
Singleton {
    id: root

    // "" = closed; otherwise the screen name the window is open on.
    property string screen: ""

    // Remote-drive seams: a path queued to list; a view mode push.
    property string pendingPath: ""
    property string pendingView: ""

    function toggle() {
        root.screen = "";
    }

    function toggleOnScreen(name) {
        root.screen = (root.screen === name) ? "" : name;
    }
}
