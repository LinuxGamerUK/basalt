import QtQuick
import Quickshell
import Quickshell.Wayland

import "root:/"

// Full-screen click catcher UNDER the bars: swallows desktop clicks only
// while any popup is open and closes them all. The bar excludes its own
// top strip (exclusiveZone + margins), so bar interactions still work.
PanelWindow {
    id: root

    // Set by Variants; non-required so a missing injection degrades
    // gracefully instead of aborting creation (Bar's proven pattern).
    property var modelData
    screen: modelData

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    // Top layer (above toplevels) — a bare-desktop catcher is useless;
    // app windows would stack above it and swallow the clicks. The bars
    // and popups also use aboveWindows, and the popups map after this
    // surface, so they stay clickable on top.
    aboveWindows: true
    focusable: false
    color: "transparent"

    visible: Ui.anythingOpen

    MouseArea {
        anchors.fill: parent
        onClicked: Ui.closeAll()
    }
}