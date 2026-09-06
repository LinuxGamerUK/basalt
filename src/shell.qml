import QtQuick
import Quickshell

// Basalt shell root — one identical bar per screen; workspaces are
// filtered per-screen inside each Bar. modelData/screen live on Bar.qml
// itself — do NOT redeclare them inline here (shadowing breaks the
// Variants injection).
ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: Component {
            Bar {}
        }
    }
}