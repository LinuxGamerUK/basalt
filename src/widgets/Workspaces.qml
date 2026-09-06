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
            // One visual format for every pill, always — Hyprland
            // auto-destroys empty non-persistent workspaces, so "missing"
            // is a transient state and must not read as a broken style.
            // Click materializes the workspace on this screen.
            color: isActive ? Theme.primary : Theme.surfaceContainerHigh
            border.width: 1
            border.color: isActive ? Theme.primary : Theme.outline

            Text {
                anchors.centerIn: parent
                text: parent.modelData % 10
                color: parent.isActive ? Theme.textOnPrimary : Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: parent.isActive
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (Hyprland.usingLua) {
                        // Lua-mode Hyprland mangles string dispatches
                        // ("hl.dispatch(workspace 7)" is invalid Lua) —
                        // use the hl.dsp.focus API. Two steps: land on the
                        // screen, then the workspace — which creates it
                        // there if missing and pulls it back if drifted.
                        Hyprland.dispatch('hl.dsp.focus({ monitor = "' + root.screenName + '" })');
                        Hyprland.dispatch('hl.dsp.focus({ workspace = "' + parent.modelData + '" })');
                    } else {
                        Hyprland.dispatch("workspace " + parent.modelData);
                    }
                }
            }
        }
    }
}