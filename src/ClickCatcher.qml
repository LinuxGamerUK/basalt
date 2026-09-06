import QtQuick
import Quickshell
import Quickshell.Wayland

import "root:/"

// Full-screen click catcher UNDER the bars: swallows desktop clicks only
// while any popup is open and closes them all. The bar excludes its own
// top strip (exclusiveZone + margins), so bar interactions still work.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    aboveWindows: false
    focusable: false
    color: "transparent"

    MouseArea {
        anchors.fill: parent
        // Only active while something is open; otherwise fully inert.
        enabled: Ui.anythingOpen
        z: 1
        onClicked: Ui.closeAll()
    }
}