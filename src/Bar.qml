import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import "widgets"

// Floating Material pill bar across the top of every screen.
PanelWindow {
    id: root

    // Set by Variants (one Bar per screen); non-required so a missing
    // injection degrades gracefully instead of aborting creation.
    property var modelData
    screen: modelData

    property bool calendarOpen: false
    property bool pickerOpen: false

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
    exclusiveZone: Theme.barHeight + Theme.barMargin
    implicitHeight: Theme.barHeight
    color: "transparent"

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
                Layout.fillWidth: true
                // Stop short of the center-locked clock (clock center =
                // bar center; half-width ~90 + gap).
                Layout.maximumWidth: root.width / 2 - 300
            }

            // Spacer: pins the right cluster to the right edge even when
            // the title hits its maximum width.
            Item {
                Layout.fillWidth: true
            }

            // TEMP red layout probe
            Rectangle {
                implicitWidth: 40
                implicitHeight: 30
                color: "#ff0000"
            }

            // Right: wallpaper picker button, then tray
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
                    onClicked: root.pickerOpen = !root.pickerOpen
                }
            }
            Tray {}
        }

        // Center: the clock is anchored to the pill itself — locked to
        // true center regardless of title width or module sizes.
        Clock {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.calendarOpen = !root.calendarOpen
        }
    }

    // Calendar dropdown — drops from under the bar center.
    PopupWindow {
        id: calendarPopup
        anchor.window: root
        anchor.edges: Edges.Bottom
        anchor.rect.x: Math.max(8, (root.width / 2) - 165)
        anchor.rect.y: Theme.barHeight + Theme.barMargin
        visible: root.calendarOpen
        implicitWidth: 330
        implicitHeight: 390
        color: "transparent"

        Calendar {
            anchors.fill: parent
            onCloseRequested: root.calendarOpen = false
        }
    }

    // Wallpaper picker — right-aligned under the bar, near its button.
    PopupWindow {
        id: pickerPopup
        anchor.window: root
        anchor.edges: Edges.Bottom
        anchor.rect.x: Math.max(8, root.width - 676)
        anchor.rect.y: Theme.barHeight + Theme.barMargin
        visible: root.pickerOpen
        implicitWidth: 660
        implicitHeight: 480
        color: "transparent"

        WallpaperPicker {
            anchors.fill: parent
            onCloseRequested: root.pickerOpen = false
        }
    }
}