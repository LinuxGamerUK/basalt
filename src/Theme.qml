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
    // Scale-aware: everything derives from uiScale (settings.json), so the
    // whole shell expands/contracts for different resolutions/DPIs without
    // touching any QML. Width is anchor-driven per screen (auto);
    // height/chips/fonts scale here.
    property real uiScale: 1.0
    readonly property int barHeight: Math.round(44 * uiScale)
    // House: tight bar — 2px floating pad on every side.
    readonly property int barMargin: Math.round(2 * uiScale)
    readonly property int barRadius: Math.round(22 * uiScale)
    readonly property int chipRadius: Math.round(14 * uiScale)
    readonly property int chipHeight: Math.round(30 * uiScale)
    readonly property int padding: Math.round(18 * uiScale)
    readonly property int spacing: Math.round(10 * uiScale)

    // ---- typography ----
    // House rule: JetBrains Mono Nerd Font Propo — base 14pt, scaled.
    readonly property string fontFamily: "JetBrainsMono Nerd Font Propo"
    readonly property int fontSize: Math.round(14 * uiScale)

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
        const broadcast = Qt.resolvedUrl("theme/broadcast.toml").toString().replace(/^file:\/\//, "");
        // Pick the palette once for both the shell and the broadcast.
        const base = wp !== ""
            ? ["matugen", "image", wp, "--prefer", "closest-to-fallback"]
            : ["matugen", "color", "hex", (settings.sourceColor || sourceColor)];
        if (matugenProc.running) {
            // Busy — re-run when the current generation finishes, so a
            // wallpaper picked mid-refresh is never lost.
            root.refreshQueued = true;
            return;
        }
        matugenProc.command = base.concat(["-c", cfg]);
        broadcastProc.command = base.concat(["-c", broadcast]);
        matugenProc.running = true;
        broadcastProc.running = true;
    }

    // Theme broadcast — writes ghostty/fish/starship/fastfetch theme files
    // under ~/.config/basalt/themes via the same palette.
    Process {
        id: broadcastProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
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
                // Resolution scaling — applies live, geometry rebinds.
                if (typeof root.settings.uiScale === "number") {
                    root.uiScale = root.settings.uiScale;
                }
                root.refresh();
                // Persisted wallpaper — applied at every shell start, i.e.
                // at login / Hyprland launch. This is the default-wallpaper
                // mechanism.
                if (root.settings.wallpaper) {
                    root.applyWallpaperFile(root.settings.wallpaper);
                }
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
        onExited: {
            if (root.refreshQueued) {
                root.refreshQueued = false;
                root.refresh();
            }
        }
    }

    // Settings writer — merges one key into settings.json (python3, local).
    // Operations are SERIALIZED: a write/apply/refresh landing while its
    // process is busy gets queued, not dropped (quickshell ignores
    // running=true on a busy Process).
    property var writeQueue: []
    property bool refreshQueued: false

    Process {
        id: writeProc
        property string key: ""
        property string value: ""
        stdout: StdioCollector {}
        onExited: {
            if (root.onSettingsSaved) {
                const f = root.onSettingsSaved;
                root.onSettingsSaved = null;
                f();
            }
            if (root.writeQueue.length > 0) {
                const next = root.writeQueue.shift();
                root.runWrite(next.key, next.value, next.then);
            }
        }
    }

    // Wallpaper applier — src/scripts/set-wallpaper.sh (hyprpaper).
    Process {
        id: wallProc
        stdout: StdioCollector {}
        onExited: {
            if (root.wallQueue.length > 0) {
                const path = root.wallQueue.shift();
                root.runWallpaper(path);
            }
        }
    }
    property var wallQueue: []

    function runWallpaper(path) {
        const script = Qt.resolvedUrl("scripts/set-wallpaper.sh").toString().replace(/^file:\/\//, "");
        wallProc.command = ["bash", script, path, settings.wallpaper || ""];
        wallProc.running = true;
    }

    function runWrite(key, value, then) {
        root.onSettingsSaved = then || null;
        writeProc.key = key;
        writeProc.value = value;
        writeProc.command = ["python3", "-c",
            "import json, sys, os\n" +
            "p = sys.argv[1]\n" +
            "s = {}\n" +
            "try:\n    s = json.load(open(p))\n" +
            "except Exception:\n    pass\n" +
            "s[sys.argv[2]] = sys.argv[3]\n" +
            "os.makedirs(os.path.dirname(p), exist_ok=True)\n" +
            "json.dump(s, open(p, 'w'))",
            Quickshell.env("HOME") + "/.config/basalt/settings.json",
            key, value];
        writeProc.running = true;
    }

    function saveSetting(key, value, then) {
        if (writeProc.running) {
            root.writeQueue.push({ key: key, value: value, then: then });
            return;
        }
        runWrite(key, value, then);
    }

    function applyWallpaperFile(path) {
        if (wallProc.running) {
            root.wallQueue.push(path);
            return;
        }
        runWallpaper(path);
    }

    // From the picker: persist, apply through hyprpaper, regenerate the
    // palette from the new wallpaper — the whole Material You payoff.
    function applyWallpaper(path) {
        saveSetting("wallpaper", path, () => {
            applyWallpaperFile(path);
            refresh();
        });
    }

    property var onSettingsSaved: null

    Component.onCompleted: settingsProc.running = true
}