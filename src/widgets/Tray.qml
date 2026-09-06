import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

// System tray icons (StatusNotifierItems). Render-only for v0 — menus
// arrive with the notifications phase.
RowLayout {
    spacing: 6

    Repeater {
        model: SystemTray.items

        delegate: Image {
            required property var modelData

            source: modelData.icon
            sourceSize.width: 18
            sourceSize.height: 18
            fillMode: Image.PreserveAspectFit
            smooth: true

            MouseArea {
                anchors.fill: parent
                // v0: left-click activates the tray item (open app window)
                onClicked: modelData.activate()
            }
        }
    }
}
