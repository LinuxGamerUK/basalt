import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell._Window
import Quickshell.Io
import Quickshell.Widgets

import "root:/"
import "."

// Basalt Gabbro — a Material 3 file-manager window over the engine
// (FileBackend.qml, NDJSON protocol — vendored, MIT).
//
// Rules (upstream design law, MIT):
// 1. The QML model is an INTEGER count, never a list — recycled
//    viewport delegates only; the held window is all file data in use.
// 2. `list` answers with the first screenful unasked; the client
//    consumes the listed+rows pair before accepting the new window.
// 3. Scroll drift outside the held window issues one coalesced
//    `window` request; thumbnails and dir sizes ride the same settle
//    gate (120 ms, flings issue nothing).
FloatingWindow {
    id: root

    visible: GabbroState.screen === root.screenName
    color: Theme.surfaceContainer

    implicitWidth: 1120
    implicitHeight: 700

    property var modelData
    screen: modelData
    readonly property string screenName: root.modelData ? root.modelData.name : ""

    // ── pane state ───────────────────────────────────────────────────
    property string currentPath: ""
    property int total: 0
    property int cursorIndex: 0
    property int held: 0
    property var rows: []
    property var kinds: []
    property bool showHidden: false
    property string sortKey: "name"
    property bool sortDesc: false
    property string viewMode: "list" // list | grid | columns(later)
    property bool searchMode: false
    property int searchScanned: 0
    property var selection: []
    property int renamingIndex: -1
    property string statusLine: ""
    property string revealName: ""

    // Directory sizes for dir rows (walked on the same settle gate).
    property var dirSizes: ({})

    // Tabs: pills of remembered paths; each stores path + cursor.
    property var tabs: [{ path: "", cursor: 0 }]
    property int tabIndex: 0
    readonly property var curTab: root.tabs[root.tabIndex]

    readonly property real rowH: Theme.fontSize + 8
    readonly property real tileW: 108
    readonly property real tileH: 108
    readonly property int visibleCount: Math.max(1, Math.ceil(view.height / rowH))
    readonly property int visibleTiles: Math.max(1, Math.ceil(view.width / tileW) * Math.ceil(view.height / tileH))
    readonly property int windowSize: Math.min(600, Math.max(visibleCount, visibleTiles) * 4 + 100)
    readonly property string listingStamp: JSON.stringify([total, held, rows, kinds])
    onListingStampChanged: cursorIndex = Math.max(0, Math.min(cursorIndex, Math.max(0, total - 1)))

    Component.onCompleted: {
        if (visible && root.currentPath.length === 0) {
            openPath(Quickshell.env("HOME") || "/");
        }
    }

    // ── helpers ──────────────────────────────────────────────────────
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
            + " " + pad(d.getHours()) + ":" + pad(d.getMinutes());
    }

    function setStatus(label) {
        root.statusLine = label;
    }

    function rememberTab() {
        if (root.tabs.length > root.tabIndex) {
            const copy = root.tabs.slice();
            copy[root.tabIndex] = { path: root.currentPath, cursor: root.cursorIndex + 0 };
            root.tabs = copy;
        }
    }

    function switchTab(i) {
        if (i === root.tabIndex || i < 0 || i >= root.tabs.length) return;
        rememberTab();
        root.tabIndex = i;
        root.revealName = "";
        openPath(root.tabs[i].path || (Quickshell.env("HOME") || "/"));
    }

    function newTab() {
        rememberTab();
        root.tabs = root.tabs.concat([{ path: Quickshell.env("HOME") || "/", cursor: 0 }]);
        root.tabIndex = root.tabs.length - 1;
        openPath(root.tabs[root.tabIndex].path);
    }

    function closeTab(i) {
        if (root.tabs.length <= 1) return; // never the last one
        const copy = root.tabs.slice();
        copy.splice(i, 1);
        root.tabs = copy;
        if (root.tabIndex >= root.tabs.length) root.tabIndex = root.tabs.length - 1;
        if (root.tabIndex === i) openPath(root.tabs[root.tabIndex].path);
    }

    // ── navigation + search ──────────────────────────────────────────
    function openPath(path) {
        if (searchRunning) engine.searchcancel();
        root.searchMode = false;
        root.searchRunning = false;
        root.searchScanned = 0;
        searchInput.text = "";
        root.currentPath = path;
        pathField.text = path;
        root.cursorIndex = 0;
        root.revealName = "";
        root.dirSizes = {};
        engine.list(path, Math.max(400, root.windowSize), root.showHidden);
        rememberTab();
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
        root.dirSizes = {};
        engine.search(root.currentPath, q, root.showHidden);
    }

    function stopSearch() {
        if (root.searchRunning) engine.searchcancel();
        root.searchMode = false;
        root.searchRunning = false;
        refresh();
    }

    function open(index) {
        const row = root.rowFor(index);
        if (row === null) return;
        if (row.d) {
            openPath(root.join(root.currentPath, row.n));
        } else {
            Qt.openUrlExternally(root.pathOf(index));
        }
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

    function focusIndex(index) {
        root.cursorIndex = Math.max(0, Math.min(index, root.total - 1));
        view.positionViewAtIndex(root.cursorIndex, ListView.Contain);
        windowTimer.restart();
    }

    // ── windowing ────────────────────────────────────────────────────
    function requestWindow(force) {
        if (!engine.childRunning || root.total === 0) return;
        const first = Math.max(0, view.firstVisible - root.visibleCount);
        const cover = root.held + root.rows.length - Math.max(1, root.visibleCount);
        if (force || first < root.held || first > cover) {
            engine.window(first, root.windowSize);
        }
    }

    // ── ops ──────────────────────────────────────────────────────────
    function trashSelection() {
        let rows = root.selection.slice().sort((a, b) => a - b);
        if (rows.length === 0) rows = [root.cursorIndex];
        engine.trash(rows);
    }

    function renameStart(index) {
        const row = root.rowFor(index);
        if (row === null) return;
        root.cursorIndex = index;
        root.renamingIndex = -1;
        root.cursorIndex = index;
        root.renamingIndex = index;
        view.forceActiveFocus();
    }

    function renameCommit(text) {
        const idx = root.renamingIndex;
        const row = root.rowFor(idx);
        root.renamingIndex = -1;
        if (!row || idx < 0) return;
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

    // ── keyboard ─────────────────────────────────────────────────────
    function handleKey(event) {
        if (root.renamingIndex >= 0) { event.accepted = true; return; }
        if (event.key === Qt.Key_Down) { if (viewMode === "list") focusIndex(cursorIndex + 1); }
        else if (event.key === Qt.Key_Up && viewMode === "list") focusIndex(cursorIndex - 1);
        else if (event.key === Qt.Key_PageDown) focusIndex(cursorIndex + visibleCount);
        else if (event.key === Qt.Key_PageUp) focusIndex(cursorIndex - visibleCount);
        else if (event.key === Qt.Key_Home) focusIndex(0);
        else if (event.key === Qt.Key_End) focusIndex(total - 1);
        else if (event.key === Qt.Key_Back || event.key === Qt.Key_Left && searchMode) {
            if (searchMode) stopSearch(); else goUp();
        }
        else if (event.key === Qt.Key_Left && !searchMode) goUp();
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_Enter || event.key === Qt.Key_Return) open(cursorIndex);
        else if (event.key === Qt.Key_F2) renameStart(cursorIndex);
        else if (event.key === Qt.Key_Delete) { if (!searchMode) trashSelection(); }
        else if (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier)) newFolder();
        else if (event.key === Qt.Key_H && (event.modifiers & Qt.ControlModifier)) { showHidden = !showHidden; refresh(); }
        else if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier)) undo();
        else if (event.key === Qt.Key_T && (event.modifiers & Qt.ControlModifier)) { newTab(); event.accepted = true; }
        else if (event.key === Qt.Key_W && (event.modifiers & Qt.ControlModifier)) { closeTab(tabIndex); event.accepted = true; }
        else if (event.key === Qt.Key_A && (event.modifiers & Qt.ControlModifier)) {
            const all = [];
            for (let i = 0; i < total; i++) all.push(i);
            selection = all;
            event.accepted = true;
        }
        else if (event.key === Qt.Key_Escape && searchMode) stopSearch();
        else return;
        event.accepted = true;
    }

    // ── settle gate: thumbnails + dir sizes ride the same 120 ms gate ─
    function settleRequests() {
        if (!engine.childRunning || root.total === 0) return;
        const firstVisible = (viewMode === "grid") ? grid.firstVisTile : view.firstVisible;
        const span = Math.max(root.visibleCount, root.visibleTiles) * 2;
        const wantedDir = [];
        for (let i = firstVisible; i < Math.min(root.total, firstVisible + span); i++) {
            const row = root.rowFor(i);
            if (row === null) continue;
            // Directory size walked for the preview + folder tiles.
            if (row.d === true && root.dirSizes[i] === undefined) {
                wantedDir.push(i);
                const ds = root.dirSizes;
                ds[i] = null;
                root.dirSizes = ds;
            }
        }
        engine.dirsize(wantedDir);
    }

    // ── chrome ───────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Tabs row
        RowLayout {
            Layout.fillWidth: true
            implicitHeight: root.tabs.length > 1 ? 34 : 0
            Layout.leftMargin: 10
            spacing: 6
            visible: root.tabs.length > 1

            Repeater {
                model: root.tabs.length

                delegate: RowLayout {
                    readonly property int idx: index

                    Rectangle {
                        implicitWidth: 26
                        implicitHeight: 24
                        radius: 6
                        color: idx === root.tabIndex ? Theme.primary : Theme.surfaceContainerHigh

                        Text {
                            anchors.centerIn: parent
                            text: root.baselineName(root.tabs[idx].path) || "/"
                            color: idx === root.tabIndex ? Theme.textOnPrimary : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 4
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.switchTab(idx)
                        }
                    }

                    Text {
                        text: "󰅜"
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSize - 5
                        visible: root.tabs.length > 1 && idx === root.tabIndex

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeTab(idx)
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true; implicitHeight: 1 }

            Text {
                text: "󰐅"
                color: Theme.text
                font.pixelSize: Theme.fontSize - 3

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.newTab()
                }
            }
        }

        // Toolbar: up, path bar, hidden toggle, new folder, trash, view modes, search.
        RowLayout {
            Layout.fillWidth: true
            implicitHeight: 44
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            spacing: 8

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
                color: root.searchRunning ? Theme.primary : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.searchInput_focus()
                }
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.outlineVariant }

        // Search strip
        RowLayout {
            visible: root.searchMode || root.searchRunning
            Layout.fillWidth: true
            implicitHeight: 32
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            spacing: 8

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
                text: " scanning…"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 3
            }
        }

        // Column header cells — click header to sort
        RowLayout {
            Layout.fillWidth: true
            implicitHeight: 24
            spacing: 0
            visible: viewMode === "list"

            Item { Layout.preferredWidth: 70 }
            Text {
                Layout.fillWidth: true
                text: "Name" + (root.sortKey === "name" ? (root.sortDesc ? " ↓" : " ↑") : "")
                color: root.sortKey === "name" ? Theme.primary : Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 3
                font.bold: true
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.sortByBackend("name")
                }
            }
            Text {
                Layout.preferredWidth: 110
                text: "Size" + (root.sortKey === "size" ? (root.sortDesc ? " ↓" : " ↑") : "")
                color: root.sortKey === "size" ? Theme.primary : Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 3
                font.bold: true
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.sortByBackend("size")
                }
            }
            Text {
                Layout.preferredWidth: 140
                text: "Modified" + (root.sortKey === "mtime" ? (root.sortDesc ? " ↓" : " ↑") : "")
                color: root.sortKey === "mtime" ? Theme.primary : Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 3
                font.bold: true
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.sortByBackend("mtime")
                }
            }
        }

        // Content row — view on the left, preview pane on the right.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            RowLayout {
                anchors.fill: parent
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.centerIn: parent
                        visible: root.total === 0 && !root.searchRunning
                        text: root.searchMode ? "No matches" : "Empty directory"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    // ── list view ────────────────────────────────────
                    ListView {
                        id: view
                        anchors.fill: parent
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.total
                        reuseItems: true
                        spacing: 0
                        visible: root.viewMode === "list"

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
                                : picked ? Qt.alpha(Theme.primary, 0.22)
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
                                    visible: row.d !== null
                                    source: row.d !== null
                                        ? "image://icon/" + (row.d.i || "text-x-generic")
                                        : ""
                                }

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
                                    visible: root.showDetailsForList()
                                    text: row.d !== null
                                        ? (row.d.d ? "—" : root.fmtSize(row.d.s))
                                        : ""
                                    color: Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 3
                                }

                                Text {
                                    Layout.preferredWidth: 140
                                    visible: root.showDetailsForList()
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
                                        return;
                                    }
                                    if (!(mouse.modifiers & Qt.ShiftModifier)) root.clearSel();
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

                        Keys.onPressed: (event) => root.handleKey(event)
                    }

                    // ── grid view ────────────────────────────────────
                    GridView {
                        id: grid
                        anchors.fill: parent
                        clip: true
                        visible: root.viewMode === "grid"
                        model: root.total
                        cellWidth: root.tileW
                        cellHeight: root.tileH
                        boundsBehavior: Flickable.StopAtBounds

                        readonly property int tilesPerRow: Math.max(1, Math.floor(width / root.tileW))
                        readonly property int firstVisTile: Math.max(0, Math.floor(contentY / root.tileH) * tilesPerRow)

                        onContentYChanged: windowTimer.restart()

                        delegate: Item {
                            id: tile
                            width: grid.cellWidth
                            height: grid.cellHeight

                            required property int index
                            property var d: root.rowFor(index)
                            property bool picked: root.isSel(index)
                            property bool onCursor: root.cursorIndex === index

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 4
                                radius: 8
                                color: tile.onCursor ? Theme.surfaceContainerHigh
                                    : tile.picked ? Qt.alpha(Theme.primary, 0.22)
                                    : "transparent"

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 4

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        Image {
                                            anchors.fill: parent
                                            asynchronous: true
                                            fillMode: Image.PreserveAspectFit
                                            visible: root.isImageRow(tile.d)
                                            source: root.isImageRow(tile.d)
                                                ? "file://" + root.pathOf(tile.index)
                                                : ""
                                        }

                                        IconImage {
                                            anchors.centerIn: parent
                                            implicitWidth: 48
                                            implicitHeight: 48
                                            asynchronous: true
                                            visible: !root.isImageRow(tile.d)
                                            source: tile.d !== null
                                                ? "image://icon/" + (tile.d.i || "text-x-generic")
                                                : ""
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        text: root.displayNameOf(tile.d) || "…"
                                        color: tile.onCursor ? Theme.primary : Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize - 4
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: (mouse) => {
                                    root.focusIndex(tile.index);
                                    if (mouse.modifiers & Qt.ControlModifier) {
                                        root.toggleSel(tile.index);
                                    } else {
                                        root.clearSel();
                                    }
                                }

                                onDoubleClicked: root.open(tile.index)
                            }
                        }
                    }
                }

                // ── preview pane ─────────────────────────────────────────
                Rectangle {
                    id: previewPane
                    Layout.preferredWidth: 250
                    Layout.fillHeight: true
                    color: Theme.surfaceContainerHigh
                    visible: root.cursorRowInfo !== null

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        // thumbnail / icon head
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 140

                            Image {
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                visible: root.isImageRow(root.cursorRowInfo)
                                source: root.isImageRow(root.cursorRowInfo)
                                    ? "file://" + root.pathOf(root.cursorIndex)
                                    : ""
                            }

                            IconImage {
                                anchors.centerIn: parent
                                implicitWidth: 64
                                implicitHeight: 64
                                asynchronous: true
                                visible: root.cursorRowInfo !== null
                                    && !root.isImageRow(root.cursorRowInfo)
                                source: root.cursorRowInfo !== null
                                    ? "image://icon/" + (root.cursorRowInfo.i || "text-x-generic")
                                    : ""
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Text {
                                Layout.fillWidth: true
                                text: root.cursorRowInfo !== null
                                    ? root.displayNameOf(root.cursorRowInfo)
                                    : ""
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.cursorRowInfo !== null
                                    ? (root.kinds[root.cursorRowInfo.k] || "Folder")
                                    : ""
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 3
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: root.previewFacts.length > 0 ? 1 : 0
                                color: Theme.outlineVariant
                                visible: root.textPreviewPath.length === 0
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: root.textPreviewPath.length > 0
                                text: root.textPreviewHead
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 3
                                textFormat: Text.PlainText
                                wrapMode: Text.WrapAnywhere
                                clip: true
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.previewFacts
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 3
                                textFormat: Text.PlainText
                                visible: root.textPreviewPath.length === 0
                            }
                        }

                        Item { Layout.fillHeight: true; implicitHeight: 1 }
                    }
                }
            }
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

    // Grid view placeholder — this slice ships list view + preview (grid lands next).
    property alias viewAlias: view

    // ── derived bindings (read-only, safe) ───────────────────────────
    function showDetailsForList() {
        return root.viewMode === "list";
    }

    // .png/.jpg/.jpeg/.gif/.webp/.avif/.bmp — direct file render, no
    // intermediate cache; the grid uses the same direct load.
    readonly property var imageExts: [".png", ".jpg", ".jpeg", ".gif", ".webp", ".avif", ".bmp"]
    function isImageRow(row) {
        if (row === null || row.d) return false;
        const n = (root.displayNameOf(row) || "").toLowerCase();
        return root.imageExts.some((e) => n.endsWith(e));
    }

    // .txt/.md/.log/.nix/.conf-.cfg-etc — preview reads the file via
    // the shell's FileView, capped (first 30 lines, small files only).
    readonly property var textExts: [".txt", ".md", ".log", ".nix", ".conf", ".cfg",
        ".json", ".sh", ".py", ".lua", ".js", ".ts", ".yaml", ".yml", ".toml", ".ini"]
    function isTextRow(row) {
        if (row === null || row.d) return false;
        const n = (root.displayNameOf(row) || "").toLowerCase();
        return root.textExts.some((e) => n.endsWith(e));
    }

    readonly property string textPreviewPath: root.isTextRow(root.cursorRowInfo)
        && root.cursorRowInfo.s < 65536
        ? root.pathOf(root.cursorIndex) : ""

    readonly property string textPreviewHead: {
        if (textPreviewPath.length === 0) return "";
        const t = textPreview.text() || "";
        if (t.length === 0) return "(empty)";
        const lines = t.split("\n").slice(0, 16);
        return lines.join("\n");
    }

    readonly property var cursorRowInfo: root.rowFor(root.cursorIndex)

    readonly property string previewFacts: {
        if (root.cursorRowInfo === null) return "";
        const pieces = [];
        pieces.push(root.fmtSize(root.cursorRowInfo.s));
        pieces.push(root.fmtDate(root.cursorRowInfo.m));
        if (root.cursorRowInfo.d) {
            const dsz = root.dirSizes[root.cursorIndex];
            if (typeof dsz === "number") pieces.push("contents " + root.fmtSize(dsz));
        }
        if (root.cursorRowInfo.l !== undefined && root.cursorRowInfo.l !== null) {
            pieces.push("→ " + root.cursorRowInfo.l);
        }
        return pieces.join("\n");
    }

    readonly property string searchInput_placeholder: ""

    function searchInput_focus() {
        searchInput.forceActiveFocus();
    }

    function sortByBackend(key) {
        if (key === root.sortKey) root.sortDesc = !root.sortDesc;
        else { root.sortKey = key; root.sortDesc = false; }
        engine.sort(root.sortKey, root.sortDesc);
    }

    // ── backend wiring ───────────────────────────────────────────────
    FileView {
        id: textPreview
        printErrors: false
    }

    FileBackend {
        id: engine

        onListed: function (n, readMs, sortMs) {
            root.total = n;
            root.rows = [];
            root.held = 0;
            root.requestWindow(true);
            settleTimer.restart();
        }

        onRows: function (start, items, kinds) {
            root.held = start;
            root.rows = items;
            root.kinds = kinds;
            if (root.revealName.length > 0) {
                for (let k = 0; k < items.length; k++) {
                    const nm = root.searchMode ? root.displayNameOf(items[k]) : items[k].n;
                    if (nm === root.revealName) {
                        root.revealName = "";
                        root.cursorIndex = start + k;
                        root.renameStart(start + k);
                        return;
                    }
                }
                engine.window(0, root.total);
            } else {
                windowTimer.restart();
            }
        }

        onFailed: function (where, message) {
            setStatus("(" + where + ") " + message);
        }

        onSearching: function (n, scannedN) {
            root.total = n;
            root.searchScanned = scannedN;
            setStatus("searching… " + scannedN + " scanned · " + n + " matches");
        }

        onSearched: function (n, cancelled) {
            root.total = n;
            root.searchRunning = false;
            setStatus(cancelled ? "search cancelled" : ("search done — " + n + " matches"));
            root.requestWindow(true);
        }

        onPathsReply: function (paths) {
            if (root.clipPendingMode !== "") {
                root.clipPaths = paths.slice();
                root.clipMode = root.clipPendingMode;
                root.clipPendingMode = "";
                setStatus((root.clipMode === "cut" ? "cut " : "copied ") + paths.length + " item(s)");
            }
        }

        onTransferStarted: function (moving) {
            setStatus((moving ? "moving" : "copying") + "…");
        }

        onTransferProgress: function (index, name, bytes, totalBytes) {
            if (totalBytes > 0) setStatus(name + " — " + Math.round(100 * bytes / totalBytes) + "%");
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
            root.clearSel();
            root.refresh();
        }

        onRenamed: function (ok, path) {
            if (ok) setStatus("renamed → " + root.baselineName(path));
        }

        onMade: function (ok, path) {
            if (ok) { setStatus("created " + root.baselineName(path)); root.revealName = root.baselineName(path); root.refresh(); }
        }

        onUndone: function (ok) {
            setStatus(ok ? "undone" : "undo failed");
            root.refresh();
        }

        onChanged: function (path) {
            if (!root.searchMode && path === root.currentPath) root.refresh();
        }

        onDirsized: function (rowIdx, bytes) {
            if (rowIdx < 0 || rowIdx >= root.total) return;
            const copy = root.dirSizes;
            copy[rowIdx] = bytes;
            root.dirSizes = copy;
        }
    }

    property string clipPendingMode: ""
    property var clipPaths: null
    property string clipMode: ""

    Timer {
        id: windowTimer
        interval: 50
        onTriggered: root.requestWindow(false)
    }

    Timer {
        id: settleTimer
        interval: 150
        onTriggered: root.settleRequests()
    }

    Connections {
        target: GabbroState

        function onScreenChanged() {
            if (root.screenName.length === 0) return;
            if (GabbroState.screen === root.screenName) {
                if (GabbroState.pendingPath.length > 0) {
                    root.openPath(GabbroState.pendingPath);
                    GabbroState.pendingPath = "";
                } else if (root.currentPath.length === 0) {
                    root.openPath(Quickshell.env("HOME") || "/");
                }
            } else if (engine.running) {
                engine.quit();
            }
        }
    }
}
