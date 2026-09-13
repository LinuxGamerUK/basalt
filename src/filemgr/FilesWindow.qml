import QtQuick
import QtQuick.Layouts
import Quickshell

import "root:/"
import "."

// Basalt Files — Material 3 file-manager window over flea's backend.
// The model is an integer count (flea's first load-bearing rule): the
// view recycles viewport delegates and the held window is the only
// file data in memory. v0.1 slice: list view, navigate, sort, hidden,
// search, trash/rename/mkdir/undo.
FloatingWindow {
    id: root

    visible: FilesState.open
    color: Theme.surfaceContainer

    implicitWidth: 1080
    implicitHeight: 680

    // ── pane state ───────────────────────────────────────────────────
    property string currentPath: ""
    property int total: 0
    property int cursorIndex: 0
    // The held backend window: rows cover [held, held + rows.length).
    property int held: 0
    property var rows: []
    property var kinds: []
    property bool showHidden: false
    // Search walk: result rows name relative paths (backend rule).
    property bool searchMode: false
    property int searchScanned: 0
    // Selection: absolute listing indices.
    property var selection: []
    // The row acting as its own rename editor right now; -1 = off.
    property int renamingIndex: -1
    property string statusLine: ""
    // Row to reveal by name after rename/mkdir replies.
    property string revealName: ""

    readonly property real rowH: Theme.fontSize + 8
    readonly property int visibleCount: Math.max(1, Math.ceil(view.height / rowH))
    readonly property int windowSize: Math.min(600, visibleCount * 4 + 64)
    // Rebuild the index bookkeeping whenever the listing data changes.
    readonly property string listingStamp: JSON.stringify([total, held, rows, kinds])
    onListingStampChanged: cursorIndex = Math.max(0, Math.min(cursorIndex, total - 1))

    function baselineName(p) {
        const parts = (p || "").split("/").filter(Boolean);
        return parts.length ? parts[parts.length - 1] : "";
    }

    function join(dir, name) {
        return dir.endsWith("/") ? dir + name : dir + "/" + name;
    }

    function rowFor(index) {
        const offset = index - root.held;
        if (offset < 0 || offset >= root.rows.length) return null;
        return root.rows[offset];
    }

    function displayNameOf(row) {
        if (!row) return "";
        if (!root.searchMode) return row.n;
        const cut = row.n.lastIndexOf("/");
        return cut >= 0 ? row.n.substring(cut + 1) : row.n;
    }

    function locationOf(row) {
        if (!row || !root.searchMode) return "";
        const cut = row.n.lastIndexOf("/");
        return cut >= 0 ? row.n.substring(0, cut) : "/";
    }

    function pathOf(index) {
        const row = root.rowFor(index);
        if (row === null) return "";
        return root.join(root.currentPath, row.n);
    }

    function fmtSize(bytes) {
        if (bytes < 1024) return bytes + " B";
        const units = ["K", "M", "G", "T", "P", "E"];
        let v = bytes / 1024.0;
        let u = 0;
        while (v >= 1024 && u < units.length - 1) { v /= 1024; u++; }
        return v.toFixed(v >= 100 ? 0 : 1) + " " + units[u];
    }

    function fmtDate(ts) {
        const d = new Date(ts * 1000);
        const pad = (n) => (n < 10 ? "0" : "") + n;
        return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
            + " " + pad(d.getHours()) + ":" + pad(d.getMinutes())
    }

    function setStatus(label) {
        root.statusLine = label;
    }

    // ── navigation + search ──────────────────────────────────────────
    function openPath(path) {
        if (root.searchMode || searchRunning) engine.searchcancel();
        root.searchMode = false;
        searchRunning = false;
        searchInput.text = "";
        root.currentPath = path;
        pathField.text = path;
        root.cursorIndex = 0;
        root.revealName = "";
        engine.list(path, Math.max(400, root.windowSize), root.showHidden);
    }

    function refresh() {
        engine.list(root.currentPath, Math.max(400, root.windowSize), root.showHidden);
    }

    property bool searchRunning: false

    function goUp() {
        const crumbs = root.currentPath.split("/").filter(Boolean);
        crumbs.pop();
        openPath(crumbs.length === 0 ? "/" : "/" + crumbs.join("/"));
    }

    function beginSearch() {
        const q = searchInput.text.trim();
        if (q.length === 0) return;
        root.searchMode = true;
        root.searchRunning = true;
        root.searchScanned = 0;
        root.cursorIndex = 0;
        root.total = 0;
        engine.search(root.currentPath, q, root.showHidden);
    }

    function stopSearch() {
        if (root.searchRunning) engine.searchcancel();
        root.searchMode = false;
        root.searchRunning = false;
        refresh();
    }

    // ── selection ────────────────────────────────────────────────────
    function isSel(index) { return root.selection.indexOf(index) >= 0; }

    function toggleSel(index) {
        const copy = root.selection.slice();
        const i = copy.indexOf(index);
        if (i >= 0) copy.splice(i, 1); else copy.push(index);
        root.selection = copy;
    }

    function clearSel() { root.selection = []; }

    function selRows() { return root.selection.slice().sort((a, b) => a - b); }

    function focusIndex(index) {
        root.cursorIndex = Math.max(0, Math.min(index, root.total - 1));
        view.positionViewAtIndex(root.cursorIndex, ListView.Contain);
        windowTimer.restart();
    }

    // ── windowing (flea rule 3) ──────────────────────────────────────
    function requestWindow(force) {
        if (!engine.childRunning || root.total === 0) return;
        const first = Math.max(0, view.firstVisible - root.visibleCount);
        const cover = root.held + root.rows.length - root.visibleCount;
        // Filter-free v1: a view index IS a listing row.
        if (force || first < root.held || first > cover) {
            engine.window(first, root.windowSize);
        }
    }

    // ── ops ──────────────────────────────────────────────────────────
    function open(index) {
        const row = root.rowFor(index);
        if (row === null) return;
        if (row.d) {
            openPath(root.join(root.currentPath, row.n));
        } else {
            openFile(index);
        }
    }

    function openFile(index) {
        // v1: xdg-open the row's file; dedicated preview surfaces land later.
        Qt.openUrlExternally(root.pathOf(index));
    }


    function trashSelection() {
        let rows = root.selRows();
        if (rows.length === 0) { rows = [root.cursorIndex]; }
        engine.trash(rows);
    }

    function renameStart(index) {
        const row = root.rowFor(index);
        if (row === null) return;
        root.renamingIndex = -1;
        root.cursorIndex = index;
        root.renamingIndex = index;
        view.forceActiveFocus();
    }

    function renameCommit(text) {
        const idx = root.renamingIndex;
        const row = root.rowFor(idx);
        root.renamingIndex = -1;
        if (!row) return;
        const from = row.n;
        const to = text.trim();
        if (to.length === 0 || to === from) return;
        if (to.indexOf("/") >= 0 || to === "." || to === "..") {
            setStatus("invalid name");
            return;
        }
        root.revealName = to;
        engine.rename(root.pathOf(idx), to);
    }

    function newFolder() {
        if (root.searchMode) return;
        root.revealName = "New Folder";
        engine.mkdir(root.currentPath);
    }

    function undo() { engine.undo(); }

    // ── clipboard (copy/cut/paste) ───────────────────────────────────
    property string clipMode: ""

    function clipCapture(mode) {
        let rows = root.selRows();
        if (rows.length === 0) rows = [root.cursorIndex];
        clipPendingMode = mode;
        engine.askPaths(rows);
    }

    property string clipPendingMode: ""

    function pasteSelection() {
        if (clipMode.length === 0 || !clipPaths) return;
        const paths = clipPaths.slice();
        engine.transfer(clipMode === "cut" ? "move" : "copy", paths, root.currentPath);
        if (clipMode === "cut") { clipMode = ""; clipPaths = null; }
    }

    property var clipPaths: null

    function handleKey(event) {
        if (root.renamingIndex >= 0) { event.accepted = true; return; }
        if (event.key === Qt.Key_Down) focusIndex(cursorIndex + 1);
        else if (event.key === Qt.Key_Up) focusIndex(cursorIndex - 1);
        else if (event.key === Qt.Key_PageDown) focusIndex(cursorIndex + visibleCount);
        else if (event.key === Qt.Key_PageUp) focusIndex(cursorIndex - visibleCount);
        else if (event.key === Qt.Key_Home) focusIndex(0);
        else if (event.key === Qt.Key_End) focusIndex(total - 1);
        else if (event.key === Qt.Key_Right) { if (!isDirRow(cursorIndex)) return; open(cursorIndex); }
        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Back) {
            if (searchMode) stopSearch(); else goUp();
        }
        else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) open(cursorIndex);
        else if (event.key === Qt.Key_F2) renameStart(cursorIndex);
        else if (event.key === Qt.Key_Delete) { if (!searchMode) trashSelection(); }
        else if (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier)) newFolder();
        else if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier)) clipCapture("copy");
        else if (event.key === Qt.Key_X && (event.modifiers & Qt.ControlModifier)) clipCapture("cut");
        else if (event.key === Qt.Key_V && (event.modifiers & Qt.ControlModifier)) pasteSelection();
        else if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier)) undo();
        else if (event.key === Qt.Key_H && (event.modifiers & Qt.ControlModifier)) {
            showHidden = !showHidden; refresh();
        }
        else if (event.key === Qt.Key_A && (event.modifiers & Qt.ControlModifier)) {
            const all = [];
            for (let i = 0; i < total; i++) all.push(i);
            selection = all;
        }
        else if (event.key === Qt.Key_Escape && searchMode) stopSearch();
        else return;
        event.accepted = true;
    }

    function isDirRow(index) {
        const row = root.rowFor(index);
        return row !== null && row.d;
    }

    // ── chrome ───────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Toolbar: up, path bar, hidden toggle, new folder, trash, search.
        RowLayout {
            Layout.fillWidth: true
            implicitHeight: 44
            spacing: 8
            Layout.leftMargin: 10
            Layout.rightMargin: 10

            Text {
                text: "󰉖"
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                Layout.preferredWidth: 26
            }

            Text {
                text: "󰋱"
                color: upMouse.containsMouse ? Theme.primary : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize

                MouseArea {
                    id: upMouse
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.goUp()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 32
                radius: 16
                color: Theme.surfaceContainerHigh
                border.color: pathField.activeFocus ? Theme.primary : Theme.outlineVariant
                border.width: 1

                TextInput {
                    id: pathField
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    selectByMouse: true
                    text: root.currentPath
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2

                    Keys.onReturnPressed: (event) => {
                        openPath(this.text.trim());
                        this.focus = false;
                        view.focus = true;
                    }
                    Keys.onEscapePressed: (event) => { this.text = root.currentPath; this.focus = false; }
                }
            }

            Text {
                text: root.showHidden ? "󰊢" : "󰊠"
                color: root.showHidden ? Theme.primary : Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.showHidden = !root.showHidden; root.refresh(); }
                }
            }

            Text {
                text: "󰐋"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.newFolder()
                }
            }

            Text {
                text: "󰆴"
                color: Theme.errorColor
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.trashSelection()
                }
            }

            Text {
                text: "󰍉"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { searchInput.forceActiveFocus(); }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.outlineVariant }

        // Search strip — visible while the walked listing is showing.
        RowLayout {
            visible: root.searchMode || searchRunning
            Layout.fillWidth: true
            implicitHeight: 32
            spacing: 8
            Layout.leftMargin: 12
            Layout.rightMargin: 12

            Text {
                text: "󰍉"
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }

            TextInput {
                id: searchInput
                Layout.fillWidth: true
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2

                Keys.onReturnPressed: root.beginSearch()
                Keys.onEscapePressed: root.stopSearch()
            }

            Text {
                visible: root.searchRunning
                text: "scanning…"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 3
            }
        }

        // Column headers — click to sort.
        RowLayout {
            Layout.fillWidth: true
            implicitHeight: 26
            spacing: 0

            Item { Layout.preferredWidth: 74 }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 2
                text: "Name" + (root.sortKey === "name" ? (root.sortDesc ? " ↓" : " ↑") : "")
                color: root.sortKey === "name" ? Theme.primary : Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 3
                font.bold: true

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.sortBy("name")
                }
            }

            Text {
                Layout.preferredWidth: 110
                text: "Size"
                color: root.sortKey === "size" ? Theme.primary : Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 3
                font.bold: true

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.sortBy("size")
                }
            }

            Text {
                Layout.preferredWidth: 140
                Layout.rightMargin: 10
                text: "Modified"
                color: root.sortKey === "mtime" ? Theme.primary : Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 3
                font.bold: true

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.sortBy("mtime")
                }
            }
        }

        function sortBy(key) {
            if (key === root.sortKey) root.sortDesc = !root.sortDesc;
            else { root.sortKey = key; root.sortDesc = false; }
            root.sortByBackend();
        }

        property string sortKey: "name"
        property bool sortDesc: false

        function sortByBackend() {
            engine.sort(root.sortKey, root.sortDesc);
        }

        // Field/List
        Item {
            id: field
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Loading / empty states.
            Text {
                anchors.centerIn: parent
                visible: total === 0 && !searchRunning
                text: searchMode ? "No matches" : "Empty directory"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            ListView {
                id: view
                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.total
                reuseItems: true
                spacing: 0

                readonly property int firstVisible: Math.max(0, Math.floor(contentY / root.rowH))

                onContentYChanged: windowTimer.restart()
                onHeightChanged: windowTimer.restart()

                delegate: Rectangle {
                    id: row
                    required property int index
                    property var d: root.rowFor(index)
                    property bool picked: root.isSel(index)
                    property bool onCursor: root.cursorIndex === index

                    width: view.width
                    height: root.rowH
                    radius: 6
                    color: onCursor ? Theme.surfaceContainerHigh
                        : picked ? Qt.alpha(Theme.primary, 0.20)
                        : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 12
                        spacing: 10

                        IconImage {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            asynchronous: true
                            source: row.d !== null
                                ? "image://icon/" + (row.d.i || "text-x-generic")
                                : ""
                        }

                        // The rename editor when this row is being renamed.
                        TextInput {
                            id: renameInput
                            visible: root.renamingIndex === row.index
                            enabled: visible
                            Layout.fillWidth: true
                            clip: true
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize

                            onVisibleChanged: {
                                if (visible) {
                                    forceActiveFocus();
                                    selectAll();
                                }
                            }

                            Keys.onReturnPressed: root.renameCommit(text);
                            Keys.onEscapePressed: { root.renamingIndex = -1; view.focus = true; }
                        }

                        Text {
                            visible: root.renamingIndex !== row.index
                            Layout.fillWidth: true
                            text: root.displayNameOf(row.d) || "…"
                            color: onCursor ? Theme.primary : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.bold: row.d !== null && row.d.d
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            visible: root.searchMode
                            Layout.preferredWidth: 220
                            text: root.locationOf(row.d)
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 3
                            elide: Text.ElideMiddle
                            maximumLineCount: 1
                        }

                        Text {
                            Layout.preferredWidth: 110
                            visible: root.showDetails
                            text: row.d !== null && !row.d.d ? root.fmtSize(row.d.s) : (row.d !== null && row.d.d ? "" : "")
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 3
                        }

                        Text {
                            Layout.preferredWidth: 144
                            visible: root.showDetails
                            text: row.d !== null ? root.fmtDate(row.d.m) : ""
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 3
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: (mouse) => {
                            if (root.renamingIndex >= 0 && root.renamingIndex !== row.index) {
                                root.renameCommit(renameInput.text);
                                return;
                            }
                            root.focusIndex(row.index);
                            if (mouse.modifiers & Qt.ControlModifier) {
                                root.toggleSel(row.index);
                            } else if (mouse.modifiers & Qt.ShiftModifier) {
                                root.toggleSel(row.index);
                            } else {
                                root.clearSel();
                            }
                        }

                        onDoubleClicked: {
                            if (root.renamingIndex >= 0) {
                                root.renameCommit(renameInput.text);
                                return;
                            }
                            root.open(row.index);
                        }
                    }
                }

                ScrollIndicator.vertical: ScrollIndicator {}
            }

            Keys.onPressed: (event) => root.handleKey(event)
        }

    // Status bar
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        color: Theme.surfaceContainerHigh

        Text {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: Text.AlignVCenter
            text: root.statusLine.length > 0
                ? root.statusLine
                : root.total + " items" + (root.showHidden ? " · hidden shown" : "")
                    + (root.searchMode ? " · results" : "")
                    + (root.selection.length > 0 ? " · " + root.selection.length + " selected" : "")
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 3
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
    }

    // ── backend wiring ───────────────────────────────────────────────
    FileBackend {
        id: engine

        onListed: function (n, readMs, sortMs) {
            root.total = n;
            root.rows = [];
            root.held = 0;
            root.requestWindow(true);
        }

        onRows: function (start, items, kinds) {
            root.held = start;
            root.rows = items;
            root.kinds = kinds;
            // Reveal flow: the pending name's row gets cursor + F2 editor.
            if (root.revealName.length > 0) {
                for (let i = 0; i < items.length; i++) {
                    const nm = root.searchMode ? root.displayNameOf(items[i]) : items[i].n;
                    if (nm === root.revealName) {
                        root.revealName = "";
                        root.cursorIndex = start + i;
                        root.startRename(start + i);
                        return;
                    }
                }
                // Not in this window; widen once and wait for the next rows.
                engine.window(0, root.total);
            } else {
                windowTimer.restart();
            }
        }

        onFailed: function (where, message) {
            root.statusLine = "  (" + where + ") " + message;
        }

        onSearching: function (n, scanned) {
            root.total = n;
            root.searchScanned = scanned;
        }

        onSearched: function (n, cancelled) {
            root.total = n;
            root.searchRunning = false;
            root.requestWindow(true);
        }

        onPathsReply: function (paths) {
            if (root.clipPendingMode !== "") {
                root.clipPaths = paths.slice();
                root.clipMode = root.clipPendingMode;
                root.clipPendingMode = "";
                setStatus((root.clipMode === "cut" ? "cut " : "copied ") + paths.length + " item(s)");
                return;
            }
            // Direct paths reply with no pending clipboard: nothing v1 uses.
        }

        onTransferStarted: function (moving) {
            setStatus((moving ? "moving" : "copying") + "…");
        }

        onTransferItem: function (name, ok, err) {
            if (!ok) setStatus(name + " — " + err);
        }

        onTransferDone: function (cancelled) {
            setStatus(cancelled ? "cancelled" : "transfer done");
            root.refresh();
        }

        onTrashed: function (ok, failed) {
            setStatus("trashed " + ok + " · failed " + failed);
            root.clipMode = "";
            root.clipPaths = null;
            root.clearSel();
            root.refresh();
        }

        onRenamed: function (ok, path) {
            if (ok) { setStatus("renamed → " + path); }
            refresh();
        }

        onMade: function (ok, path) {
            if (ok) { setStatus("created " + path); }
            refresh();
        }

        onUndone: function (fok) { setStatus(fok ? "undo" : "undo failed"); }

        onChanged: function (path) {
            if (!root.searchMode && path === root.currentPath) refresh();
        }
    }

    Timer {
        id: windowTimer
        interval: 50
        onTriggered: root.requestWindow(false)
    }
}
