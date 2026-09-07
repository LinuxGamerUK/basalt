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
    // Explicit alpha-zero — the "transparent" string can parse to an
    // opaque white in the PanelWindow path. The surface must still map
    // (for input) but paint nothing.
    color: Qt.rgba(0, 0, 0, 0)

    // ALWAYS mapped: layer z-order follows map order, and a visible-flip
    // on the first popup open can map this surface AFTER the popup —
    // putting the catcher on top and eating every press (fresh boots hit
    // this race; mid-session restarts didn't). Mapped from shell start it
    // is permanently the bottom-most surface. The input mask gates it:
    // zero-size (all events pass through) until a popup opens, then the
    // full screen (clicks close the popups).
    visible: true

    mask: Region {
        x: 0
        y: 0
        width: Ui.anythingOpen ? root.width : 0
        height: Ui.anythingOpen ? root.height : 0
    }

    MouseArea {
        id: catcherMouse
        anchors.fill: parent
        enabled: Ui.anythingOpen
        onClicked: Ui.closeAll()
    }
}