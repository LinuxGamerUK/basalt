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

    readonly property int barCount: 24
    property var bars: []
    // cava's raw ASCII values run 0–1000 at the default sensitivity.
    readonly property real valueMax: 1000

    Layout.preferredWidth: barCount * 7 + 2
    Layout.preferredHeight: 22
    Layout.alignment: Qt.AlignVCenter
    spacing: 3

    Repeater {
        model: root.barCount

        Rectangle {
            required property int index

            width: 4
            radius: 1.5
            color: Theme.primary
            opacity: 0.85
            Layout.alignment: Qt.AlignBottom
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
                // cava's raw-ASCII frame is the DFT magnitude of a real
                // signal WITHOUT the Nyquist mirror stripped: bins 0..
                // len/2 are the real low->high spectrum, len/2..len is
                // the mirror (bass lands on BOTH ends). Take the first
                // half and stretch it across the bar row.
                if (vals.length >= 2) {
                    const half = vals.slice(0, Math.ceil(vals.length / 2));
                    const m = half.length / root.barCount;
                    const out = [];
                    for (let i = 0; i < root.barCount; i++) {
                        out.push(half[Math.floor(i * m)] || 0);
                    }
                    root.bars = out;
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