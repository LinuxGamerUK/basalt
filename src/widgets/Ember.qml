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
        running: Theme.emberEnabled
        stdinEnabled: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var msg
                try { msg = JSON.parse(String(data).trim()) } catch (e) { return }
                if (msg.event === "state" && msg.connected) {
                    // Sync immediately, then twice more on delays: the
                    // OpenRGB GUI restores its saved profile after this
                    // shell's paint, and the accent has to win that race.
                    root.sendSync()
                    resyncTimer.restart()
                }
            }
        }
        stderr: StdioCollector {}
    }

    Timer {
        id: resyncTimer
        interval: 4000
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            if (Theme.emberEnabled && bridgeProc.running)
                root.sendSync()
        }
    }

    function sync(hex) {
        lastAccent = hex
        if (bridgeProc.running)
            bridgeProc.write(JSON.stringify(
                { op: "sync_all", color: hex, vivid: true }) + "\n")
    }

    function sendSync() {
        sync(Theme.primary.toString())
    }

    Component.onCompleted: if (Theme.emberEnabled) sendSync()

    Connections {
        target: Theme
        function onPrimaryChanged() { root.sync(Theme.primary.toString()) }
        function onEmberEnabledChanged() {
            if (Theme.emberEnabled) root.sendSync()
        }
    }
}
