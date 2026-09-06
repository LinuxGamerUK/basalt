import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

// Workspace pills — all persistent workspaces, active one filled.
// Click to dispatch. (v0: all workspaces across monitors; per-monitor
// filtering arrives with the display phase.)
RowLayout {
    spacing: 4

    Repeater {
        model: Hyprland.workspaces

        delegate: Rectangle {
            required property var modelData
            readonly property bool isActive: modelData.active ?? false

            width: 24
            height: Theme.chipHeight - 8
            radius: height / 2
            color: isActive ? Theme.primary : Theme.surfaceContainerHigh
            border.width: 1
            border.color: isActive ? Theme.primary : Theme.outline

            Text {
                anchors.centerIn: parent
                text: modelData.id % 10
                color: parent.isActive ? Theme.onPrimary : Theme.onSurfaceVariant
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: parent.isActive
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Hyprland.dispatch("workspace " + modelData.id)
            }
        }
    }
}
