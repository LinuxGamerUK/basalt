import QtQuick
import Quickshell.Io
import "root:/"

// Ember — OpenRGB theme sync. Owns the Python bridge process; on every
// theme accent change it paints all OpenRGB devices the (vivid-lifted)
// accent. Gated by the persisted emberEnabled toggle in Settings.
Item {
    id: root

    readonly property string bridgePath: Qt.resolvedUrl(
        "../scripts/ember_bridge.py").toString().replace(/^file:\/\//, "")

    // Last accent sent, so the bridge can be told on connect.
    property string lastAccent: ""

    Process {
        id: bridgeProc
        command: ["python3", "-u", root.bridgePath,
                  "--host", "127.0.0.1", "--port", "6742"]
        stdinEnabled: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var msg
                try { msg = JSON.parse(String(data).trim()) } catch (e) { return }
                if (msg.event === "state" && msg.connected)
                    bridgeProc.write(JSON.stringify(
                        { op: "sync_all", color: Theme.primary.toString(),
                          vivid: true }) + "\n")
            }
        }
        stderr: StdioCollector {}
    }

    Connections {
        target: Theme
        function onPrimaryChanged() { root.sync(Theme.primary.toString()) }
    }

    function sync(hex) {
        root.lastAccent = hex
        if (bridgeProc.running)
            bridgeProc.write(JSON.stringify(
                { op: "sync_all", color: hex, vivid: true }) + "\n")
    }
}
