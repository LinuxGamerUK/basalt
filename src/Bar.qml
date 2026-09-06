import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import "widgets"

// Floating Material pill bar across the top of every screen.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    property bool calendarOpen: false

    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: Theme.barMargin
        left: Theme.barMargin
        right: Theme.barMargin
    }

    aboveWindows: true
    focusable: false
    exclusiveZone: Theme.barHeight + Theme.barMargin
    implicitHeight: Theme.barHeight
    color: "transparent"

    // The pill
    Rectangle {
        id: pill
        anchors.fill: parent
        radius: Theme.barRadius
        color: Theme.surface
        opacity: 0.92
        border.width: 1
        border.color: Theme.outlineVariant

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.padding
            anchors.rightMargin: Theme.padding
            spacing: Theme.spacing

            // Left: this screen's workspaces, then the window title chip
            Workspaces {
                screenName: root.modelData.name
            }
            WindowTitle {}

            // Center: the clock (true centering between the two spacers)
            Item {
                Layout.fillWidth: true
                Layout.minimumWidth: 8
            }
            Clock {
                onClicked: root.calendarOpen = !root.calendarOpen
            }
            Item {
                Layout.fillWidth: true
                Layout.minimumWidth: 8
            }

            // Right
            Tray {}
        }
    }

    // Calendar dropdown — drops from under the bar center.
    PopupWindow {
        id: calendarPopup
        anchor.window: root
        anchor.edges: Edges.Bottom
        anchor.rect.x: Math.max(8, (root.width / 2) - 165)
        anchor.rect.y: Theme.barHeight + Theme.barMargin
        visible: root.calendarOpen
        implicitWidth: 330
        implicitHeight: 390
        color: "transparent"

        Calendar {
            anchors.fill: parent
            onCloseRequested: root.calendarOpen = false
        }
    }
}