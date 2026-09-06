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
            // Has windows on it right now (but not active here) → the
            // secondary accent state. toplevels is an ObjectModel — count
            // via .values (a QObjectList), not .count.
            readonly property bool hasWindows: live ? ((live.toplevels && live.toplevels.values.length) > 0) : false

            // implicitWidth/Height: RowLayout sizes children from implicit
            // sizes — explicit width/height gets stomped to 0.
            implicitWidth: 24
            implicitHeight: Theme.chipHeight - 8
            radius: height / 2
            // Three states, one visual language:
            //   active       → primary fill
            //   has windows  → secondary border (content present elsewhere)
            //   empty/missing→ plain outline
            color: isActive ? Theme.primary : Theme.surfaceContainerHigh
            border.width: (!isActive && hasWindows) ? 2 : 1
            border.color: isActive
                ? Theme.primary
                : (hasWindows ? Theme.secondary : Theme.outline)

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
                        // Lua mode: pass a NUMBER id, not a string — a
                        // string creates a NAMED workspace instead of
                        // switching to id N. Two steps: land on the screen,
                        // then the workspace (creates/pulls it here).
                        Hyprland.dispatch('hl.dsp.focus({ monitor = "' + root.screenName + '" })');
                        Hyprland.dispatch('hl.dsp.focus({ workspace = ' + parent.modelData + ' })');
                    } else {
                        Hyprland.dispatch("workspace " + parent.modelData);
                    }
                }
            }
        }
    }
}