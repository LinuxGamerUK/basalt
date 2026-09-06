import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

import "root:/"

// Workspace pills — all persistent workspaces, active one filled.
// Click to dispatch. (v0: all workspaces across monitors; per-monitor
// filtering arrives with the display phase.)
RowLayout {
    id: root

    property string screenName: ""

    // Only the workspaces that live on THIS screen (house layout:
    // 1–5 on eDP-1, 6–10 on the desk monitor — see hyprland.lua).
    // Hyprland.workspaces is an ObjectModel — iterate .values.
    readonly property var screenWorkspaces: {
        const out = [];
        const ws = Hyprland.workspaces.values;
        for (let i = 0; i < ws.length; i++) {
            const w = ws[i];
            if (w.monitor && w.monitor.name === root.screenName) {
                out.push(w);
            }
        }
        return out;
    }

    spacing: 4

    Repeater {
        model: screenWorkspaces

        delegate: Rectangle {
            required property var modelData
            readonly property bool isActive: modelData.active ?? false

            // implicitWidth/Height: RowLayout sizes children from implicit
            // sizes — explicit width/height gets stomped to 0.
            implicitWidth: 24
            implicitHeight: Theme.chipHeight - 8
            radius: height / 2
            color: isActive ? Theme.primary : Theme.surfaceContainerHigh
            border.width: 1
            border.color: isActive ? Theme.primary : Theme.outline

            Text {
                anchors.centerIn: parent
                text: modelData.id % 10
                color: parent.isActive ? Theme.textOnPrimary : Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: parent.isActive
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: modelData.activate()
            }
        }
    }
}
