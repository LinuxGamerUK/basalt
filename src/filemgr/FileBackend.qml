import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io


// Basalt Files backend bridge — flea's NDJSON protocol over
// `flea --backend` (stdin/stdout, one JSON line each way). Upstream
// contract: flea docs/protocol.md (MIT). Trimmed to v1's surface.
Item {
    id: root

    signal listed(int total, real readMs, real sortMs)
    signal rows(int start, var items, var kinds)
    signal failed(string where, string message)
    signal searching(int total, int scanned)
    signal searched(int total, bool cancelled)
    signal transferStarted(bool moving)
    signal transferItem(string name, bool ok, string err)
    signal transferDone(bool cancelled)
    signal trashed(int ok, int failed)
    signal renamed(bool ok, string path)
    signal made(bool ok, string path)
    signal undone(bool ok)
    signal pathsReply(var paths)
    signal changed(string path)

    // The listing directory's filesystem id (move vs copy on patches).
    property int dirDev: 0

    // Single write author.
    function send(obj) {
        const line = JSON.stringify(obj) + "\n";
        if (queueing) { pending.push(line); return; }
        if (!child.running) { root.failed("backend", "backend not running"); return; }
        child.write(line);
    }

    function list(path, first, hidden) {
        root.hasListed = true;
        root.send({ c: "list", path: path, first: first, hidden: hidden,
                    by: "name", desc: false, foldersFirst: true });
    }

    function sort(by, desc) {
        root.send({ c: "sort", by: by, desc: desc, foldersFirst: true });
    }

    function window(start, count) {
        root.send({ c: "window", start: start, count: count });
    }

    function search(path, query, hidden) {
        root.send({ c: "search", path: path, query: query, hidden: hidden });
    }

    function searchcancel() { root.send({ c: "searchcancel" }); }

    function trash(rows) {
        if (rows.length === 0) return;
        root.send({ c: "trash", rows: rows });
    }

    function transfer(op, paths, dest) {
        if (paths.length === 0) return;
        root.send({ c: "transfer", op: op, paths: paths, dest: dest });
    }

    function rename(path, to) {
        root.send({ c: "rename", path: path, to: to });
    }

    // No name: the backend picks "New Folder(/N)".
    function mkdir(path) { root.send({ c: "mkdir", path: path }); }

    function undo() { root.send({ c: "undo" }); }

    function askPaths(rows) { root.send({ c: "paths", rows: rows }); }

    function quit() {
        if (quitting || !child.running) return;
        quitting = true;
        root.send({ c: "quit" });
    }

    function receive(line) {
        if (!line || line.length === 0) return;
        let m = null;
        try { m = JSON.parse(line); }
        catch (e) { root.failed("parse", "unreadable line from backend"); return; }
        switch (m.t) {
        case "listed":
            root.dirDev = m.v || 0;
            root.hasListed = true;
            root.listed(m.n, m.read, m.sort);
            break;
        case "rows":
            root.rows(m.start, m.rows, m.kinds || []);
            break;
        case "error":
            root.failed(m.where, m.msg);
            break;
        case "searching":
            root.searching(m.n, m.scanned);
            break;
        case "searched":
            root.searched(m.n, m.cancelled === true);
            break;
        case "transferstarted":
            root.transferStarted(m.moving === true);
            break;
        case "transferitem":
            root.transferItem(m.name, m.ok === true, m.err || "");
            break;
        case "transferdone":
            root.transferDone(m.cancelled === true);
            break;
        case "trashed":
            root.trashed(m.ok, m.failed);
            break;
        case "renamed":
            root.renamed(m.ok === true, m.path || "");
            break;
        case "made":
            root.made(m.ok === true, m.path || "");
            break;
        case "undone":
            root.undone(m.ok === true);
            break;
        case "paths":
            root.pathsReply(m.paths || []);
            break;
        case "changed":
            root.changed(m.path || "");
            break;
        }
    }

    property var pending: []
    property bool queueing: true
    property bool quitting: false
    property bool hasListed: false

    // FLEA_BIN dev seam (upstream). Resolved by PATH in the running env.
    readonly property string fleaBin: Quickshell.env("FLEA_BIN") || "flea"
    readonly property bool childRunning: child.running

    Process {
        id: child
        command: [fleaBin, "--backend"]
        running: true
        stdinEnabled: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (data) { root.receive(data) }
        }

        onStarted: {
            root.queueing = false;
            for (let i = 0; i < root.pending.length; i++)
                child.write(root.pending[i]);
            root.pending = [];
        }

        onRunningChanged: {
            // A spawn failure surfaces here, without onExited.
            if (root.queueing && !child.running) {
                root.queueing = false;
                root.pending = [];
                root.failed("backend", "could not start the backend");
            }
        }

        onExited: {
            root.queueing = true;
            root.pending = [];
        }
    }
}
