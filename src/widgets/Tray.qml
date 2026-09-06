import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

import "root:/"

// System tray — StatusNotifierItems via QuickShell's SNI host/watcher
// (already registered on the session bus). Left-click activates (open
// the app window), middle-click secondary-activates, right-click opens
// the item's D-Bus menu (QsMenuAnchor renders it as a native popup).
// Items with onlyMenu open the menu on any click.
RowLayout {
    spacing: 6

    Repeater {
        model: SystemTray.items

        delegate: Rectangle {
            id: trayIcon

            required property var modelData
            readonly property bool hasMenu: modelData.hasMenu ?? false

            implicitWidth: 22
            implicitHeight: 22
            radius: 6
            color: mouse.containsMouse
                ? Theme.surfaceContainerHigh : "transparent"

            IconImage {
                id: icon
                anchors.centerIn: parent
                width: 18
                height: 18
                source: parent.modelData.icon
                asynchronous: true
            }

            QsMenuAnchor {
                id: menuAnchor
                menu: trayIcon.hasMenu ? trayIcon.modelData.menu : null
                anchor {
                    window: trayIcon.Window.window
                    item: trayIcon
                    edges: Edges.Bottom
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    const item = trayIcon.modelData;
                    if (mouse.button === Qt.RightButton && trayIcon.hasMenu) {
                        menuAnchor.open();
                    } else if (mouse.button === Qt.MiddleButton) {
                        item.secondaryActivate();
                    } else if (item.onlyMenu) {
                        menuAnchor.open();
                    } else {
                        item.activate();
                    }
                }
            }
        }
    }
}