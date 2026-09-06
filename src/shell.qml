import QtQuick
import Quickshell

// Basalt shell root — one identical bar per screen; workspaces are
// filtered per-screen inside each Bar.
ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: Bar {
            required property var modelData
            screen: modelData
        }
    }
}