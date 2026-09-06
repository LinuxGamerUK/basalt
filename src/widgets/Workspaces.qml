import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

import "root:/"

// Static house workspace layout: the primary screen carries 1–5, every
// other screen carries 6–10 — regardless of where Hyprland's live state
// has drifted (workspaces migrate when accessed from another monitor).
// A pill for a workspace that doesn't currently exist on this monitor
// renders dim; clicking it creates/pulls the workspace here.
RowLayout {
    id: root

    property string screenName: ""

    readonly property bool isPrimary: root.screenName === (Theme.settings.primaryScreen || "eDP-1")

    readonly property var workspaceNumbers: {
        const out = [];
        const first = root.isPrimary ? 1 : 6;
        const last = root.isPrimary ? 5 : 10;
        for (let n = first; n <= last; n++) {
            out.push(n);
        }
        return out;
    }

    // Live workspace object for a number, if it currently exists anywhere.
    function liveWorkspace(n) {
        const ws = Hyprland.workspaces.values;
        for (let i = 0; i < ws.length; i++) {
            if (ws[i].id === n) {
                return ws[i];
            }
        }
        return null;
    }

    spacing: 4

    Repeater {
        model: root.workspaceNumbers

        delegate: Rectangle {
            id: pill

            required property int modelData
            readonly property var live: root.liveWorkspace(modelData)
            readonly property bool isActive: live ? (live.active ?? false) : false

            // implicitWidth/Height: RowLayout sizes children from implicit
            // sizes — explicit width/height gets stomped to 0.
            implicitWidth: 24
            implicitHeight: Theme.chipHeight - 8
            radius: height / 2
            color: isActive ? Theme.primary : Theme.surfaceContainerHigh
            border.width: 1
            border.color: isActive ? Theme.primary
                         : (live ? Theme.outline : Theme.outlineVariant)

            Text {
                anchors.centerIn: parent
                text: parent.modelData % 10
                color: parent.isActive ? Theme.textOnPrimary
                     : (parent.live ? Theme.textSecondary : Theme.outline)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: parent.isActive
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                // Creates the workspace here if missing; pulls it back to
                // this screen if it drifted.
                onClicked: Hyprland.dispatch("workspace " + parent.modelData)
            }
        }
    }
}