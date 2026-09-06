import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

import "root:/"

// Volume / brightness OSD — explicitly triggered by the media-key binds
// (`qs ipc call osd volume|brightness` chained after wpctl /
// brightnessctl). No reactive triggers: Arctis Sound Manager adjusts
// channel volumes constantly, and reactive volumeChanged would stomp the
// brightness display with the volume card. The level binds to
// MixerState so held keys animate it live.
PanelWindow {
    id: root

    property var modelData
    screen: modelData
    // Primary screen only — a global event like the toasts.
    readonly property bool primaryScreen: root.modelData
        ? root.modelData.name === (Theme.settings.primaryScreen || "eDP-1")
        : false
    visible: primaryScreen && osdVisible

    // OSD state
    property bool osdVisible: false
    property string osdMode: "volume" // "volume" | "brightness"
    property bool osdMuted: false

    // Level: volume = the MixerState sink (live, held keys animate it);
    // brightness = the MixerState poll (updates within ~250 ms).
    readonly property real osdLevel: osdMode === "volume"
        ? MixerState.sinkVolume
        : MixerState.brightnessLevel

    IpcHandler {
        target: "osd"

        function volume() {
            root.osdMode = "volume";
            root.osdMuted = MixerState.sinkMuted;
            root.osdVisible = true;
            hideTimer.restart();
        }

        function brightness() {
            root.osdMode = "brightness";
            root.osdMuted = false;
            root.osdVisible = true;
            hideTimer.restart();
        }
    }

    anchors {
        bottom: true
        left: true
        right: true
    }
    margins.bottom: Theme.barHeight + Theme.barMargin * 2 + 16
    aboveWindows: true
    focusable: false
    exclusiveZone: -1
    color: Qt.rgba(0, 0, 0, 0)
    implicitWidth: 300
    implicitHeight: 78

    Timer {
        id: hideTimer
        interval: 2000
        onTriggered: root.osdVisible = false
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: 260
        implicitHeight: 64
        radius: 20
        color: Theme.surfaceContainer
        border.color: Theme.outlineVariant
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 14
            spacing: 12

            Text {
                text: root.osdMode === "volume"
                    ? (root.osdMuted ? "󰝟" : "󰕾")
                    : "󰃟"
                color: root.osdMode === "volume" && root.osdMuted
                    ? Theme.error : Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 8
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 10
                radius: 5
                color: Theme.surfaceContainerHigh

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(10, parent.width * Math.max(0, Math.min(1, root.osdLevel)))
                    radius: 5
                    color: root.osdMode === "volume" && root.osdMuted
                        ? Theme.error : Theme.primary
                }
            }

            Text {
                text: root.osdMode === "volume" && root.osdMuted
                    ? "MUTED"
                    : Math.round(root.osdLevel * 100) + "%"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
                Layout.preferredWidth: 52
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}