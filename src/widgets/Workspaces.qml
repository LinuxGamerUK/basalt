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

    // Startup self-heal: Hyprland gives the second monitor its own default
    // workspace (id 2) before the static-layout rules create 6–10, so at
    // login the bar shows BOTH ws 1 and ws 2 as "active on their monitor".
    // Any workspace parked on the wrong monitor gets focused and pulled
    // home; the monitor's active workspace then settles on the layout's
    // first number (e.g. 6 on the external) and the bar normalises.
    function heal() {
        console.log("heal: strays — " + JSON.stringify(
            [1,2,3,4,5,6,7,8,9,10].map(n => {
                const ws = liveWorkspace(n);
                return ws ? (n + "@" + ws.monitor) : null;
            }).filter(v => v !== null)));
        for (let n = 1; n <= 10; n++) {
            const ws = liveWorkspace(n);
            if (!ws || !ws.monitor) continue;
            const home = ws.id <= 5
                ? (Theme.settings.primaryScreen || "eDP-1")
                : Quickshell.screens
                    .filter(s => s.name !== (Theme.settings.primaryScreen || "eDP-1"))
                    .map(s => s.name)[0] || "";
            // ws.monitor is a HyprlandMonitor object — compare its .name,
            // not the object itself (an object-vs-string compare is always
            // unequal: every workspace looked like a stray on every pass,
            // which was the constant churn / "mind of its own").
            if (home === "" || ws.monitor.name === home) continue;
            console.log("heal: pulling ws " + n + " from " + ws.monitor.name + " to " + home);
            Hyprland.dispatch('hl.dsp.focus({ workspace = ' + n + ' })');
            Hyprland.dispatch('hl.dsp.workspace.move({ monitor = "' + home + '" })');
            Hyprland.dispatch('hl.dsp.focus({ monitor = "' + root.screenName + '" })');
        }
    }

    // The Hyprland IPC + the workspaces model need a beat after shell
    // start before the state is complete.
    Timer {
        interval: 2000
        running: root.screenName !== ""
        repeat: false
        onTriggered: root.heal()
    }

    // Periodic self-heal: workspaces drift when moves/focus land on the
    // wrong monitor (SUPER+SHIFT+N migrates the destination). Pull strays
    // home every few seconds so the static layout holds continuously.
    Timer {
        interval: 8000
        running: root.screenName !== ""
        repeat: true
        onTriggered: {
            // ONE healer only — the primary bar. Two bars healing fight
            // over the monitor focus (each heal ends with a focus on its
            // own screen, bouncing the view between monitors).
            if (root.screenName === (Theme.settings.primaryScreen || "eDP-1")) {
                root.heal();
            }
        }
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
            border.width: !isActive && hasWindows ? 4 : 1
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