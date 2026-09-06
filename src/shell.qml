// Native D-Bus menus (tray right-click) require QApplication mode.
//@ pragma UseQApplication
import QtQuick
import Quickshell
import "widgets"

// Basalt shell root — one identical bar per screen; workspaces are
// filtered per-screen inside each Bar. modelData/screen live on Bar.qml
// itself — do NOT redeclare them inline here (shadowing breaks the
// Variants injection).
ShellRoot {
    // Click-catcher — created first so it maps at the BOTTOM of the
    // layer: bars and popups always stack above it. Its MouseArea is
    // active only while a popup is open — desktop clicks close any open
    // popup (house rule) without ever blocking normal use.
    Variants {
        model: Quickshell.screens

        delegate: Component {
            ClickCatcher {}
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            NotificationToasts {}
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Bar {}
        }
    }
}