import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

import "root:/"

// Launcher — centered search pill + filtered app list. SUPER+SPACE or
// the bar's rocket button opens it on the focused screen. Keyboard:
// type to filter, ↑/↓ to move, Enter to launch, Esc to close.
PanelWindow {
    id: root

    property var modelData
    screen: modelData
    readonly property string screenName: root.modelData ? root.modelData.name : ""
    visible: Ui.launcherScreen === root.screenName

    // Keyboard capture — the launcher owns input while open. Overlay
    // mode: above every window, reserving no space (it must not push
    // the desktop around).
    focusable: true
    aboveWindows: true
    exclusiveZone: -1

    anchors {
        top: true
        left: true
        right: true
    }
    margins.top: Theme.barHeight + Theme.barMargin * 2 + 4
    color: Qt.rgba(0, 0, 0, 0)
    implicitHeight: launcherPill.implicitHeight + 8

    function filterApps() {
        return DesktopEntries.applications.values
            .filter(e => !e.noDisplay)
            .filter(e => {
                const q = searchInput.text.trim().toLowerCase();
                if (q === "") return true;
                return (e.name || "").toLowerCase().includes(q)
                    || (e.comment || "").toLowerCase().includes(q)
                    || (e.keywords || []).some(k => (k || "").toLowerCase().includes(q));
            })
            .sort((a, b) => (a.name || "").localeCompare(b.name || ""));
    }

    onVisibleChanged: {
        if (visible) {
            searchInput.text = "";
            list.model = filterApps();
            list.currentIndex = 0;
            searchInput.forceActiveFocus();
        }
    }

    Rectangle {
        id: launcherPill

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 4
        width: Math.min(560, root.screenName !== "" ? parent.width - 16 : parent.width)
        implicitHeight: listColumn.implicitHeight + 16
        radius: 20
        color: Theme.surfaceContainer
        border.color: Theme.outlineVariant
        border.width: 1

        ColumnLayout {
            id: listColumn
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            // Search box
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 34
                radius: 17
                color: Theme.surfaceContainerHigh

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Text {
                        text: "󰀄"
                        color: Theme.primary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        selectByMouse: true

                        onTextChanged: {
                            list.model = root.filterApps();
                            list.currentIndex = 0;
                        }

                        Keys.onUpPressed: if (list.currentIndex > 0) list.currentIndex--;
                        Keys.onDownPressed: if (list.currentIndex < list.count - 1) list.currentIndex++;
                        Keys.onReturnPressed: root.launch(list.currentItem?.modelData);
                        Keys.onEnterPressed: root.launch(list.currentItem?.modelData);
                        Keys.onEscapePressed: Ui.closeAll();
                    }
                }
            }

            // App list
            ListView {
                id: list

                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: Math.min(contentHeight, 400)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                spacing: 2

                delegate: Rectangle {
                    id: appRow

                    required property var modelData
                    required property int index

                    width: list.width
                    implicitHeight: appRowLayout.implicitHeight + 10
                    radius: 10
                    color: list.currentIndex === index
                        ? Theme.primaryContainer
                        : "transparent"

                    RowLayout {
                        id: appRowLayout
                        anchors.fill: parent
                        anchors.margins: 5
                        spacing: 10

                        Rectangle {
                            implicitWidth: 28
                            implicitHeight: 28
                            radius: 8
                            color: Theme.surfaceContainerHigh

                            IconImage {
                                anchors.centerIn: parent
                                width: 20
                                height: 20
                                source: appRow.modelData.icon
                                asynchronous: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: appRow.modelData.name || appRow.modelData.id
                                color: list.currentIndex === index
                                    ? Theme.onPrimaryContainer : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: (appRow.modelData.comment || "") !== ""
                                text: appRow.modelData.comment
                                color: list.currentIndex === index
                                    ? Theme.onPrimaryContainer : Theme.textSecondary
                                opacity: 0.8
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 3
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: list.currentIndex = appRow.index
                        onClicked: root.launch(appRow.modelData)
                    }
                }
            }
        }
    }

    function launch(entry) {
        if (!entry) return;
        entry.execute();
        Ui.closeAll();
    }
}