pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Io

// Mixer state — the default sink/source + the sysfs backlight, shared
// by the bar chips, the mixer panel, and the OSD. The brightness is
// polled from sysfs (it can change from any source); volume changes
// come reactively from Pipewire.
Singleton {
    id: root

    // Volume
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    PwObjectTracker {
        objects: [root.sink, root.source].filter(Boolean)
    }

    readonly property bool sinkReady: root.sink !== null && root.sink.audio !== null
    readonly property real sinkVolume: root.sinkReady ? root.sink.audio.volume : 0
    readonly property bool sinkMuted: root.sinkReady ? root.sink.audio.muted : false
    readonly property string sinkName: root.sink ? (root.sink.description || root.sink.name || "") : ""

    readonly property bool sourceReady: root.source !== null && root.source.audio !== null
    readonly property real sourceVolume: root.sourceReady ? root.source.audio.volume : 0
    readonly property bool sourceMuted: root.sourceReady ? root.source.audio.muted : false
    readonly property string sourceName: root.source ? (root.source.description || root.source.name || "") : ""

    // The devices: hardware sinks and sources (streams filtered out).
    readonly property var sinks: Pipewire.nodes.values
        .filter(n => n.isSink && !n.isStream)
        .map(n => ({ id: n.id, name: n.description || n.name }))
    readonly property var sources: Pipewire.nodes.values
        .filter(n => !n.isSink && !n.isStream)
        .map(n => ({ id: n.id, name: n.description || n.name }))

    // Switch the default output/input to a specific device node.
    function setSinkById(id) {
        const node = Pipewire.nodes.values.find(n => n.id === id);
        if (node) Pipewire.preferredDefaultAudioSink = node;
    }

    function setSourceById(id) {
        const node = Pipewire.nodes.values.find(n => n.id === id);
        if (node) Pipewire.preferredDefaultAudioSource = node;
    }

    function setSinkVolume(v) {
        if (root.sinkReady) root.sink.audio.volume = v;
        if (v > 0) setSinkMuted(false);
    }

    function toggleSinkMuted() {
        if (root.sinkReady) root.sink.audio.muted = !root.sink.audio.muted;
    }

    function setSourceVolume(v) {
        if (root.sourceReady) root.source.audio.volume = v;
    }

    function toggleSourceMuted() {
        if (root.sourceReady) root.source.audio.muted = !root.source.audio.muted;
    }

    // Brightness
    property int brightnessCur: -1
    property int brightnessMax: -1
    property bool warm: false
    readonly property real brightnessLevel: brightnessMax > 0
        ? brightnessCur / brightnessMax : 0

    Timer {
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
                    root.brightnessCur = cur;
                }
            }
        }
    }

    Process {
        id: brightSet
        stdout: StdioCollector {}
        onExited: root.flushBrightness()
    }

    // Serialized write queue: quickshell drops `running = true` on busy
    // processes, and a slider drag fires setBrightness ~30x/s — every
    // call after the first in a burst was silently lost, including the
    // final release position, so the sysfs kept a stale value and the
    // poll's echo yanked the handle away. Coalesce to the latest level
    // and flush exactly one brightnessctl per process exit.
    property real pendingBrightness: -1

    function setBrightness(level) {
        root.pendingBrightness = Math.max(0, Math.min(1, level));
        if (brightSet.running) return;
        root.flushBrightness();
    }

    function flushBrightness() {
        if (root.pendingBrightness < 0 || brightSet.running) return;
        const v = Math.round(root.pendingBrightness * 100);
        root.pendingBrightness = -1;
        // Plain linear set — no exponent/min-value curves: the sysfs echo
        // feeds the slider readback and must match the requested value.
        brightSet.command = ["brightnessctl", "set", v + "%"];
        brightSet.running = true;
    }

    // Warm-up: the OSD suppresses until 3 s after shell start.
    Timer {
        interval: 3000
        running: true
        repeat: false
        onTriggered: root.warm = true
    }
}