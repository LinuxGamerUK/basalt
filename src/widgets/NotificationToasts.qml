import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland

import "root:/"

// Notification toasts — top-right under the bar, one window per screen.
// Renders the server's tracked notifications as soft-cornered cards with
// the theme border; cards vanish when their notification expires (3s).
PanelWindow {
    id: root

    property var modelData
    screen: modelData
    // Toasts render on the primary screen only — a global event, not a
    // per-screen one (the house per-screen rule is for clicked panels).
    visible: root.modelData
        ? root.modelData.name === (Theme.settings.primaryScreen || "eDP-1")
        : false

    anchors {
        top: true
        right: true
    }
    margins {
        top: Theme.barHeight + Theme.barMargin * 2 + 4
        right: Theme.barMargin + 2
    }
    aboveWindows: true
    focusable: false
    color: "transparent"
    implicitWidth: 380
    implicitHeight: screenColumn.implicitHeight + 8

    ColumnLayout {
        id: screenColumn
        anchors.fill: parent
        anchors.margins: 4
        spacing: 8

        Repeater {
            model: NotificationsState.serverRef.trackedNotifications.values

            Rectangle {
                id: toastCard

                required property var modelData

                Layout.fillWidth: true
                implicitHeight: toastRow.implicitHeight + 20
                radius: 14
                color: Theme.surfaceContainer
                border.width: 1
                border.color: Theme.outlineVariant

                RowLayout {
                    id: toastRow
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    // App icon — resolves the icon theme name when given.
                    Rectangle {
                        implicitWidth: 30
                        implicitHeight: 30
                        radius: 15
                        color: Theme.surfaceContainerHigh

                        Text {
                            anchors.centerIn: parent
                            text: toastCard.modelData.appIcon !== ""
                                ? "" : "󰂚"
                            color: Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            visible: toastCard.modelData.appIcon === ""
                        }

                        Image {
                            anchors.centerIn: parent
                            source: toastCard.modelData.appIcon !== ""
                                ? "image://icon/" + toastCard.modelData.appIcon : ""
                            sourceSize.width: 22
                            sourceSize.height: 22
                            visible: toastCard.modelData.appIcon !== ""
                            asynchronous: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: toastCard.modelData.summary !== ""
                                ? toastCard.modelData.summary
                                : toastCard.modelData.appName
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.bold: true
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: toastCard.modelData.body !== ""
                            text: toastCard.modelData.body
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                        }

                        Text {
                            Layout.fillWidth: true
                            text: toastCard.modelData.appName
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 4
                            opacity: 0.7
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    Text {
                        text: "󰅂"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: toastCard.modelData.dismiss()
                        }
                    }
                }

                // Expired/dismissed toasts leave the tracked model and the
                // card goes with it (Repeater).
                Connections {
                    target: toastCard.modelData
                    function onClosed() {
                        // Nothing needed — the model updates itself.
                    }
                }
            }
        }
    }
}