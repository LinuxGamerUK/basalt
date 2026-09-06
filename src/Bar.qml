import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import "widgets"
import "root:/"

// Floating Material pill bar across the top of every screen.
PanelWindow {
    id: root

    // Set by Variants (one Bar per screen); non-required so a missing
    // injection degrades gracefully instead of aborting creation.
    property var modelData
    screen: modelData

    // Popup state lives on the shared Ui singleton (click-catcher, house
    // rule: open only on the screen that was clicked).
    readonly property bool calendarOpen: Ui.calendarScreen === root.screenName
    readonly property bool pickerOpen: Ui.pickerScreen === root.screenName
    readonly property bool notificationsOpen: Ui.notificationsScreen === root.screenName
    readonly property string screenName: root.modelData ? root.modelData.name : ""

    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: Theme.barMargin
        left: Theme.barMargin
        right: Theme.barMargin
    }

    aboveWindows: true
    focusable: false
    // Reserve the bar PLUS a 2px breathing gap below it (margin is also
    // the top gap — symmetric floating pad).
    exclusiveZone: Theme.barHeight + Theme.barMargin * 2
    implicitHeight: Theme.barHeight
    color: Qt.rgba(0, 0, 0, 0)

    // The pill
    Rectangle {
        id: pill
        anchors.fill: parent
        radius: Theme.barRadius
        color: Theme.surface
        opacity: 0.92
        border.width: 1
        border.color: Theme.outlineVariant

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.padding
            anchors.rightMargin: Theme.padding
            spacing: Theme.spacing

            // Left: this screen's workspaces, then the window title chip
            Workspaces {
                // null-guard: modelData lands shortly after creation
                screenName: root.modelData ? root.modelData.name : ""
            }
            WindowTitle {
                // Sized to content, hard-capped so it can never reach the
                // center-locked clock. NO fillWidth — the spacer below is
                // the single flexible element (that's what pins the right
                // cluster to the right edge on any width).
                Layout.maximumWidth: root.width / 2 - 300
            }

            // Spacer: pins the right cluster to the right edge even when
            // the title hits its maximum width.
            Item {
                Layout.fillWidth: true
            }

            // Right: tray, then the picker and notifications buttons rightmost
            Tray {}
            Rectangle {
                id: wallBtn
                implicitWidth: Theme.chipHeight
                implicitHeight: Theme.chipHeight
                radius: height / 2
                color: root.pickerOpen ? Theme.primary : Theme.surfaceContainerHigh
                Text {
                    anchors.centerIn: parent
                    text: "\uf03e"
                    color: root.pickerOpen ? Theme.textOnPrimary : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Ui.togglePicker(root.screenName)
                }
            }
            Rectangle {
                id: bellBtn
                implicitWidth: Theme.chipHeight
                implicitHeight: Theme.chipHeight
                radius: height / 2
                color: root.notificationsOpen
                    ? Theme.primary : Theme.surfaceContainerHigh

                Text {
                    anchors.centerIn: parent
                    text: "\uf0f3"
                    color: root.notificationsOpen
                        ? Theme.textOnPrimary : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                // Unread badge — a small dot pinned to the bell's corner.
                Rectangle {
                    visible: NotificationsState.unread > 0
                        && !root.notificationsOpen
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 3
                    anchors.rightMargin: 3
                    implicitWidth: 16
                    implicitHeight: 16
                    radius: 8
                    color: Theme.error

                    Text {
                        anchors.centerIn: parent
                        text: NotificationsState.unread
                        color: Theme.surface
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 6
                        font.bold: true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        NotificationsState.markSeen();
                        Ui.toggleNotifications(root.screenName);
                    }
                }
            }
        }

        // Center: the clock is anchored to the pill itself — locked to
        // true center regardless of title width or module sizes.
        Clock {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            onClicked: Ui.toggleCalendar(root.screenName)
        }
    }

    // Calendar dropdown — drops from under the bar center.
    PopupWindow {
        id: calendarPopup
        anchor.window: root
        anchor.edges: Edges.Bottom
        anchor.rect.x: Math.max(8, (root.width / 2) - 165)
        anchor.rect.y: Theme.barHeight + Theme.barMargin * 2
        visible: root.calendarOpen
        implicitWidth: Math.round(330 * Theme.uiScale)
        implicitHeight: Math.round(390 * Theme.uiScale)
        color: Qt.rgba(0, 0, 0, 0)

        Calendar {
            anchors.fill: parent
            onCloseRequested: Ui.calendarScreen = ""
        }
    }

    // Wallpaper picker — right-aligned under the bar, near its button.
    PopupWindow {
        id: pickerPopup
        anchor.window: root
        anchor.edges: Edges.Bottom
        anchor.rect.x: Math.max(8, root.width - 676)
        anchor.rect.y: Theme.barHeight + Theme.barMargin * 2
        visible: root.pickerOpen
        implicitWidth: Math.round(660 * Theme.uiScale)
        implicitHeight: Math.round(480 * Theme.uiScale)
        color: Qt.rgba(0, 0, 0, 0)

        WallpaperPicker {
            anchors.fill: parent
            onCloseRequested: Ui.pickerScreen = ""
        }
    }

    // Notification history — right-aligned under the bell.
    PopupWindow {
        id: notificationsPopup
        anchor.window: root
        anchor.edges: Edges.Bottom
        anchor.rect.x: Math.max(8, root.width - 456)
        anchor.rect.y: Theme.barHeight + Theme.barMargin * 2
        visible: root.notificationsOpen
        implicitWidth: Math.round(440 * Theme.uiScale)
        implicitHeight: Math.round(520 * Theme.uiScale)
        color: Qt.rgba(0, 0, 0, 0)

        NotificationHistory {
            anchors.fill: parent
            onCloseRequested: Ui.notificationsScreen = ""
        }
    }
}