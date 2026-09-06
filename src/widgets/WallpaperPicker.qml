import QtQuick
import QtQuick.Layouts
import Quickshell

import "root:/"

// Material wallpaper picker: folder chip (editable), refresh, thumbnail
// grid. Click a wallpaper → persisted to settings.json, applied through
// hyprpaper, and the whole shell re-themes from its accent colors.
// Folder + image list live in PickerState (shared — identical on every
// screen that shows this popup).
Rectangle {
    id: root

    signal closeRequested()

    color: Theme.surfaceContainer
    radius: 20
    border.color: Theme.outlineVariant
    border.width: 1

    // Shared instance state (house rule: popup identical on every screen)
    readonly property string folder: PickerState.folder
    readonly property var images: PickerState.images

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
                    font.pixelSize: Theme.fontSize
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    onAccepted: {
                        PickerState.setFolder(text);
                        // Remember the browsed folder for next time.
                        Theme.saveSetting("wallpaperDir", text);
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
                        PickerState.setFolder(pathInput.text);
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