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
            height: 2 + Math.max(0, Math.min(1, (root.bars[index] || 0) / 100))
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
                    root.bars = vals.slice(0, root.barCount);
                }
            }
        }
        stderr: StdioCollector {}
    }
}