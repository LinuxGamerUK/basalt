import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import "root:/"

// CAVA visualizer — the audio spectrum as a row of accent bars, fed by
// the cava binary (raw ASCII output: semicolon-separated values per
// line, one frame per line). Reacts to whatever is playing.
RowLayout {
    id: root

    readonly property int barCount: 12
    property var bars: []
    // cava's raw ASCII values run 0–1000 at the default sensitivity.
    readonly property real valueMax: 1000
    property int framesSeen: 0

    Layout.preferredWidth: barCount * 5 + 2
    Layout.preferredHeight: 22
    Layout.alignment: Qt.AlignVCenter
    spacing: 2

    Repeater {
        model: root.barCount

        Rectangle {
            required property int index

            width: 3
            radius: 1
            color: Theme.primary
            opacity: 0.85
            anchors.bottom: parent.bottom
            height: 2 + Math.max(0, Math.min(1, (root.bars[index] || 0) / root.valueMax))
                * (root.height - 2)

            Behavior on height {
                NumberAnimation {
                    duration: 60
                    easing.type: Easing.Linear
                }
            }
        }
    }

    Process {
        id: cavaProc
        command: ["cava", "-p", Quickshell.env("HOME") + "/.config/cava/config"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"

            onRead: (data) => {
                const vals = data.split(";")
                    .filter(v => v.length > 0)
                    .map(v => parseInt(v) || 0);
                if (vals.length >= root.barCount) {
                    root.framesSeen++;
                    if (root.framesSeen % 60 === 0) {
                        console.log("cava frame", root.framesSeen,
                            "vals:", JSON.stringify(vals));
                    }
                    root.bars = vals.slice(0, root.barCount);
                }
            }
        }
        stderr: StdioCollector {}
        // Respawn: cava dies when its capture source briefly disappears
        // (e.g. an Arctis Sound Manager filter-chain restart removes the
        // monitor from the bus) — bring it back after a beat.
        onExited: respawnTimer.restart()
    }

    Timer {
        id: respawnTimer
        interval: 1500
        onTriggered: cavaProc.running = true
    }
}