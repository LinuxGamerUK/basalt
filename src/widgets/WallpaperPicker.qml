import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import "root:/"

// Material wallpaper picker: folder chip (editable), refresh, thumbnail
// grid. Click a wallpaper → persisted to settings.json, applied through
// hyprpaper, and the whole shell re-themes from its accent colors.
Rectangle {
    id: root

    signal closeRequested()

    color: Theme.surfaceContainer
    radius: 20
    border.color: Theme.outlineVariant
    border.width: 1

    property string folder: Theme.settings.wallpaperDir
        || (Quickshell.env("HOME") + "/Pictures/Wallpapers")
    property var images: []

    function refresh() {
        if (listProc.running) return;
        listProc.running = true;
    }

    Component.onCompleted: refresh()

    Process {
        id: listProc
        // Proper argv quoting — the folder never touches a shell string.
        command: ["bash", "-c",
            'find "$1" -maxdepth 1 -type f \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.avif" -o -iname "*.bmp" \\) -print | sort',
            "basalt-picker", root.folder]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                root.images = t ? t.split("\n") : [];
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // Header: folder path chip + refresh + close
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: 15
                color: Theme.surfaceContainerHigh

                TextInput {
                    id: pathInput
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    text: root.folder
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    onAccepted: {
                        root.folder = pathInput.text;
                        root.refresh();
                    }
                }
            }

            Rectangle {
                width: 30; height: 30; radius: 15
                color: Theme.surfaceContainerHigh
                Text {
                    anchors.centerIn: parent
                    text: "\u21bb"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.folder = pathInput.text;
                        root.refresh();
                    }
                }
            }

            Rectangle {
                width: 30; height: 30; radius: 15
                color: Theme.surfaceContainerHigh
                Text {
                    anchors.centerIn: parent
                    text: "\u2715"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        // Thumbnail grid
        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: 156
            cellHeight: 124
            boundsBehavior: Flickable.StopAtBounds

            model: root.images

            delegate: Rectangle {
                id: pill

                required property string modelData

                width: grid.cellWidth - 8
                height: grid.cellHeight - 8
                radius: 10
                color: Theme.surfaceContainerHigh
                border.width: modelData === Theme.settings.wallpaper ? 2 : 0
                border.color: Theme.primary

                Image {
                    anchors.fill: parent
                    anchors.margins: 4
                    source: encodeURI("file://" + pill.modelData)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 312
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Theme.applyWallpaper(pill.modelData)
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.images.length === 0
                text: "No images in this folder"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }
    }
}