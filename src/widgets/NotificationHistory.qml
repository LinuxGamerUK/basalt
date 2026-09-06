import QtQuick
import QtQuick.Layouts
import Quickshell

import "root:/"

// Notification history — header (title + clear-all + close), then the
// stored notifications newest first, each with an individual dismiss.
Rectangle {
    id: root

    signal closeRequested()

    color: Theme.surfaceContainer
    radius: 20
    border.color: Theme.outlineVariant
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Notifications"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
                Layout.fillWidth: true
            }

            Rectangle {
                implicitWidth: 90
                implicitHeight: 28
                radius: 14
                color: Theme.surfaceContainerHigh
                visible: NotificationsState.history.length > 0

                Text {
                    anchors.centerIn: parent
                    text: "Clear all"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationsState.clearAll()
                }
            }

            Rectangle {
                width: 28; height: 28; radius: 14
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

        // Empty state
        Text {
            visible: NotificationsState.history.length === 0
            text: "No notifications"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            Layout.alignment: Qt.AlignHCenter
        }

        // History list
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            Repeater {
                model: NotificationsState.history

                delegate: Rectangle {
                    id: entry

                    required property int index
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: entryRow.implicitHeight + 14
                    radius: 10
                    color: Theme.surfaceContainerHigh

                    RowLayout {
                        id: entryRow
                        anchors.fill: parent
                        anchors.margins: 7
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: (entry.modelData.summary !== ""
                                    ? entry.modelData.summary
                                    : entry.modelData.appName)
                                    + "  ·  " + entry.modelData.time
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                font.bold: true
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: entry.modelData.body !== ""
                                text: entry.modelData.body
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                            }

                            Text {
                                Layout.fillWidth: true
                                text: entry.modelData.appName
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                opacity: 0.7
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }

                        Text {
                            text: "󰅂"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NotificationsState.removeAt(entry.index)
                            }
                        }
                    }
                }
            }
        }
    }
}