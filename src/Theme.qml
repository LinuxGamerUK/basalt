pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Material 3 dark tonal palette.
//
// Two sources, in order:
//   1. matugen — Material You palette generated from the wallpaper
//      (settings.json "wallpaper") or a source color ("sourceColor",
//      default: the house cyan). Computed locally; no network.
//   2. the static fallbacks below — used whenever matugen fails or no
//      settings exist yet.
//
// NOTE: no `on*` property names — QML reserves onXxx for signal handlers.
Singleton {
    id: root

    // ---- tonal surfaces (dark scheme) ----
    property color surfaceDim: "#121218"
    property color surface: "#1a1a22"
    property color surfaceContainer: "#1f1f28"
    property color surfaceContainerHigh: "#292934"

    // ---- content ----
    property color text: "#e3e2e8"
    property color textSecondary: "#a9a9b6"
    property color textOnPrimary: "#00363d"

    // ---- accents ----
    property color primary: "#4fd8e0"
    property color secondary: "#00d68f"
    property color errorColor: "#ffb4ab"

    // ---- lines ----
    property color outline: "#5c5c68"
    property color outlineVariant: "#2f2f3a"

    // ---- geometry ----
    readonly property int barHeight: 44
    readonly property int barMargin: 8
    readonly property int barRadius: 22
    readonly property int chipRadius: 14
    readonly property int chipHeight: 30
    readonly property int padding: 18
    readonly property int spacing: 10

    // ---- typography ----
    // House rule: JetBrains Mono Nerd Font Propo, size 14 — everywhere.
    readonly property string fontFamily: "JetBrainsMono Nerd Font Propo"
    readonly property int fontSize: 14

    // ---- theming source ----
    property string sourceColor: "#4fd8e0"
    property var settings: ({})

    function applyPalette(p) {
        if (!p) return;
        if (p.primary) primary = p.primary;
        if (p.textOnPrimary) textOnPrimary = p.textOnPrimary;
        if (p.secondary) secondary = p.secondary;
        if (p.text) text = p.text;
        if (p.textSecondary) textSecondary = p.textSecondary;
        if (p.surfaceDim) surfaceDim = p.surfaceDim;
        if (p.surface) surface = p.surface;
        if (p.surfaceContainer) surfaceContainer = p.surfaceContainer;
        if (p.surfaceContainerHigh) surfaceContainerHigh = p.surfaceContainerHigh;
        if (p.outline) outline = p.outline;
        if (p.outlineVariant) outlineVariant = p.outlineVariant;
        if (p.errorColor) errorColor = p.errorColor;
    }

    function refresh() {
        const wp = settings.wallpaper || "";
        const cfg = Qt.resolvedUrl("theme/matugen.toml").toString().replace(/^file:\/\//, "");
        if (wp !== "") {
            matugenProc.command = ["matugen", "image", wp, "-c", cfg];
        } else {
            matugenProc.command = ["matugen", "color", "hex", (settings.sourceColor || sourceColor), "-c", cfg];
        }
        matugenProc.running = true;
    }

    Process {
        id: settingsProc
        command: ["bash", "-c", "cat \"$HOME/.config/basalt/settings.json\" 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.settings = JSON.parse(this.text);
                } catch (e) {
                    root.settings = {};
                }
                root.refresh();
            }
        }
    }

    Process {
        id: matugenProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.applyPalette(JSON.parse(this.text));
                } catch (e) {
                    // keep the static fallback palette
                }
            }
        }
    }

    Component.onCompleted: settingsProc.running = true
}