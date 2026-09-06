import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import "widgets"

// Floating Material pill bar across the top of every screen.
PanelWindow {
    id: root

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

            Workspaces {}
            WindowTitle {
                Layout.fillWidth: true
            }
            Tray {}
            Clock {}
        }
    }
}
