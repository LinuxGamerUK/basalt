import QtQuick
import QtQuick.Layouts
import Quickshell.Io

import "root:/"

// Basalt settings — power actions, appearance, extensions. Opened from
// the bar's gear chip. House rules: per-screen popup, click-outside
// closes, one panel at a time.
Rectangle {
    id: root

    color: Theme.surfaceContainer
    radius: 20
    border.color: Theme.outlineVariant
    border.width: 1

    // Destructive power actions carry a 2-step confirm: the first press
    // arms the button for 3 seconds, the second executes.
    property string armedAction: ""
    Timer {
        id: armTimer
        interval: 3000
        onTriggered: root.armedAction = ""
    }

    Process {
        id: powerProc
        stdout: StdioCollector {}
    }

    function requestPower(action, needsConfirm) {
        if (!needsConfirm || root.armedAction === action) {
            root.armedAction = "";
            powerProc.command = ["systemctl", action];
            powerProc.running = true;
        } else {
            root.armedAction = action;
            armTimer.restart();
        }
    }

    // Shared toggle control — pure MouseArea (Controls' buttons proved
    // unreliable inside Quickshell windows on Hyprland), state-driven
    // from the owner so no binding ever breaks.
    component ToggleRow: RowLayout {
        id: row
        property string label: ""
        property bool checked: false
        signal toggled()

        Text {
            Layout.fillWidth: true
            text: row.label
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }

        Item {
            implicitWidth: 46
            implicitHeight: 24

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: row.checked ? Theme.primary : Theme.surfaceContainerHigh
                border.color: Theme.outlineVariant
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Rectangle {
                x: row.checked ? parent.width - width - 3 : 3
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                radius: 9
                color: row.checked ? Theme.textOnPrimary : Theme.text
                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: row.toggled()
            }
        }
    }

    component SectionLabel: Text {
        text: ""
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 3
        font.bold: true
    }

    component PowerButton: Rectangle {
        id: pbtn
        property string label: ""
        property string action: ""
        property bool needsConfirm: true
        readonly property bool armed: root.armedAction === action

        Layout.preferredWidth: 96
        implicitHeight: 34
        radius: 8
        color: pma.containsMouse || armed
            ? Theme.surfaceContainerHigh : "transparent"
        border.color: root.armedAction === action
            ? Theme.errorColor : Theme.outlineVariant
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 150 } }

        Text {
            anchors.centerIn: parent
            text: root.armedAction === pbox.action && pbox.needsConfirm
                ? "Confirm?" : pbtn.label
            color: root.armedAction === p.action ? Theme.errorColor : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
        }

        MouseArea {
            id: pma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.requestPower(pbtn.action, pbtn.needsConfirm)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        Text {
            text: "SETTINGS"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
        }

        SectionLabel { text: "POWER" }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            PowerButton { label: "⏻ Off"; action: "poweroff"; needsConfirm: true }
            PowerButton { label: "󰜉 Reboot"; action: "reboot"; needsConfirm: true }
            PowerButton { label: "⏾ Sleep"; action: "suspend"; needsConfirm: false }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.outlineVariant
        }

        SectionLabel { text: "APPEARANCE" }
        ToggleRow {
            Layout.fillWidth: true
            label: "Transparent bar (accent islands)"
            checked: Theme.transparentBar
            onToggled: Theme.setTransparentBar(!Theme.transparentBar)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.outlineVariant
        }

        SectionLabel { text: "EXTENSIONS" }
        ToggleRow {
            Layout.fillWidth: true
            label: "Ember — OpenRGB theme sync"
            checked: Theme.emberEnabled
            onToggled: Theme.setEmberEnabled(!Theme.emberEnabled)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.outlineVariant
        }

        // Wallpaper
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 38
            radius: 8
            color: wma.containsMouse
                ? Theme.surfaceContainerHigh : Theme.surfaceContainer
            border.color: Theme.outlineVariant
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10

                Text {
                    text: ""
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                Text {
                    Layout.fillWidth: true
                    text: "Wallpaper"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                Text {
                    text: ""
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                }
            }

            MouseArea {
                id: wma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Ui.togglePicker(root.screenName)
            }
        }

        Item { Layout.fillHeight: true }
    }
}