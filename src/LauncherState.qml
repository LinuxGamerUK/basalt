pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Launcher usage tracking — launch counts per desktop-entry id, persisted
// in ~/.local/state/basalt/launcher-usage.json (XDG state: survives
// rebuilds). The launcher ranks most-used apps to the top over time.
//
// Same serialized write-queue pattern as Theme's settings writer: a bump
// landing while the writer is busy is queued, never dropped.
Singleton {
    id: root

    // app id -> { count: int, last: epoch-ms }
    property var counts: ({})

    Component.onCompleted: readProc.running = true

    Process {
        id: readProc
        command: ["bash", "-c", "cat \"$HOME/.local/state/basalt/launcher-usage.json\" 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(this.text);
                    if (parsed && typeof parsed === "object") root.counts = parsed;
                } catch (e) {
                    // absent/corrupt — start empty
                }
            }
        }
    }

    property var writeQueue: []

    Process {
        id: writeProc
        stdout: StdioCollector {}
        onExited: {
            if (root.writeQueue.length > 0) {
                const next = root.writeQueue.shift();
                root.runWrite(next.counts);
            }
        }
    }

    function runWrite(counts) {
        writeProc.command = ["python3", "-c",
            "import json, sys, os\n" +
            "p = sys.argv[1]\n" +
            "os.makedirs(os.path.dirname(p), exist_ok=True)\n" +
            "json.dump(json.loads(sys.argv[2]), open(p, 'w'))\n",
            Quickshell.env("HOME") + "/.local/state/basalt/launcher-usage.json",
            JSON.stringify(counts)];
        writeProc.running = true;
    }

    // Bump one app's usage count. Writes are queued behind a busy writer.
    function bump(id) {
        if (!id) return;
        const entry = root.counts[id] || { count: 0, last: 0 };
        const next = Object.assign({}, root.counts);
        next[id] = { count: (entry.count || 0) + 1, last: Date.now() };
        root.counts = next;
        if (writeProc.running) {
            root.writeQueue.push({ counts: next });
            return;
        }
        runWrite(next);
    }

    function countOf(id) {
        return (root.counts[id] || {}).count || 0;
    }

    function lastOf(id) {
        return (root.counts[id] || {}).last || 0;
    }
}