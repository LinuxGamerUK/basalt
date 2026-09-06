import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

import "root:/"

// Volume / brightness OSD — reacts to system changes (the media keys
// drive wpctl / brightnessctl; the OSD just displays what happened).
// Shows for 2 seconds after the last change, then hides.
//
// Volume: QuickShell Pipewire, the default sink's audio node.
// Brightness: polled from the sysfs backlight (a 250 ms timer — cheap,
// and it catches changes from any source, not just our binds).
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
    property real osdLevel: 0 // 0..1
    property bool osdMuted: false

    function show(mode, level, muted) {
        osdMode = mode;
        osdLevel = level;
        osdMuted = muted;
        osdVisible = true;
        hideTimer.restart();
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

    // Volume: the default sink's audio node reacts to wpctl changes.
    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    Connections {
        target: Pipewire.defaultAudioSink?.audio ?? null
        ignoreUnknownSignals: true
        function onVolumeChanged() { root.showVolume(); }
        function onMutedChanged() { root.showVolume(); }
    }

    function showVolume() {
        const audio = Pipewire.defaultAudioSink?.audio;
        if (!audio) return;
        root.show("volume", audio.volume, audio.muted);
    }

    // Brightness: poll the sysfs backlight. The OSD only fires for
    // changes after the shell has warmed up (3 s) — so the startup read
    // and anything else non-interactive stays silent.
    property int brightnessCur: -1
    property int brightnessMax: -1
    property bool warm: false

    Timer {
        id: brightWatch
        interval: 250
        running: true
        repeat: true
        onTriggered: brightProc.running = true
    }

    Process {
        id: brightProc
        command: ["bash", "-c",
            "echo \"$(cat /sys/class/backlight/*/brightness 2>/dev/null | head -1) $(cat /sys/class/backlight/*/max_brightness 2>/dev/null | head -1)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split(/\s+/);
                const cur = parseInt(parts[0] || "-1");
                const max = parseInt(parts[1] || "0");
                if (isNaN(cur) || cur < 0 || isNaN(max) || max <= 0) return;
                root.brightnessMax = max;
                if (root.brightnessCur !== cur) {
                    const changed = root.brightnessCur > 0;
                    root.brightnessCur = cur;
                    if (changed && root.warm) {
                        root.show("brightness", cur / max, false);
                    }
                }
            }
        }
    }

    // Warm-up: suppress the OSD until 3 s after shell start so the first
    // polls and background restores never trigger it.
    Timer {
        interval: 3000
        running: true
        repeat: false
        onTriggered: root.warm = true
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