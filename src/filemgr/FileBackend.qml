import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io


// Gabbro backend bridge — the engine's NDJSON protocol over
// `gabbro --backend` (stdin/stdout, one JSON line each way), vendored
// from upstream (MIT). Trimmed to v0.5's surface.
Item {
    id: root

    signal listed(int total, real readMs, real sortMs)
    signal rows(int start, var items, var kinds)
    signal failed(string where, string message)
    signal searching(int total, int scanned)
    signal searched(int total, bool cancelled)
    signal transferStarted(bool moving)
    signal transferProgress(int index, string name, real bytes, real total)
    signal transferItem(string name, bool ok, string err)
    signal transferDone(bool cancelled)
    signal trashed(int ok, int failed)
    signal renamed(bool ok, string path)
    signal made(bool ok, string path)
    signal undone(bool ok)
    signal pathsReply(var paths)
    signal changed(string path)
    // Preview facilities — thumbnails / directory sizes, one reply per named row.
    signal thumbed(int row, string file)
    signal dirsized(int row, real bytes)

    // The listing directory's filesystem id (move vs copy on patches).
    property int dirDev: 0

    // Current sort order, set by accepted sorts (list resets to name asc).
    property string sortBy: "name"
    property bool sortDesc: false

    // Single write author — the protocol has exactly one.
    function send(obj) {
        const line = JSON.stringify(obj) + "\n";
        if (queueing) { pending.push(line); return; }
        if (!child.running) { root.failed("backend", "backend not running"); return; }
        child.write(line);
    }

    function list(path, first, hidden) {
        root.sortBy = "name";
        root.sortDesc = false;
        root.send({ c: "list", path: path, first: first, hidden: hidden,
                    by: root.sortBy, desc: root.sortDesc, foldersFirst: true });
    }

    function sort(by, desc) {
        root.send({ c: "sort", by: by, desc: desc, foldersFirst: true });
    }

    function dirsize(rows) {
        if (rows.length === 0) return;
        root.send({ c: "dirsize", rows: rows });
    }

    function dirsizecancel() { root.send({ c: "dirsizecancel" }); }

    function window(start, count) {
        root.send({ c: "window", start: start, count: count });
    }

    function search(path, query, hidden) {
        root.send({ c: "search", path: path, query: query, hidden: hidden });
    }

    function searchcancel() { root.send({ c: "searchcancel" }); }

    // Read-only look at a directory that is NOT the current listing —
    // the columns view's home. Replies are one-shot snapshots.
    function peek(path, first, hidden) {
        root.send({ c: "peek", path: path, first: first, hidden: hidden });
    }

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
        case "dirsized":
            root.dirsized(m.row, m.bytes || 0);
            break;
        case "peeked":
            root.peeked(m.path || "", m.failed === true, m.n || 0, m.rows || []);
            break;
        case "transferprogress":
            root.transferProgress(m.index, m.name, m.bytes, m.total);
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

    // GABBRO_BIN dev seam — an override binary without a rebuild.
    readonly property string commandName: Quickshell.env("GABBRO_BIN") || "gabbro"
    readonly property bool childRunning: child.running

    Process {
        id: child
        command: [commandName, "--backend"]
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
