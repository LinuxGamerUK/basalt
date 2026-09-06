pragma Singleton

import QtQuick

// Material 3 dark tonal palette — static for v0.1.
// Seed: the house Hyprland border gradient (cyan #33ccff → green #00ff99).
// matugen-driven dynamic color lands in phase C4 and swaps these values.
QtObject {
    // tonal surfaces (dark scheme)
    readonly property color surfaceDim: "#121218"
    readonly property color surface: "#1a1a22"
    readonly property color surfaceContainer: "#1f1f28"
    readonly property color surfaceContainerHigh: "#292934"

    // content — NOTE: no `on*` property names (QML reserves onXxx for
    // signal handlers; onSurface/onPrimary were illegal)
    readonly property color text: "#e3e2e8"
    readonly property color textSecondary: "#a9a9b6"
    readonly property color textOnPrimary: "#00363d"

    // accents
    readonly property color primary: "#4fd8e0"
    readonly property color secondary: "#00d68f"
    readonly property color errorColor: "#ffb4ab"

    // lines
    readonly property color outline: "#5c5c68"
    readonly property color outlineVariant: "#2f2f3a"

    // geometry
    readonly property int barHeight: 44
    readonly property int barMargin: 8
    readonly property int barRadius: 22
    readonly property int chipRadius: 14
    readonly property int chipHeight: 30
    readonly property int padding: 18
    readonly property int spacing: 10

    // typography
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
}
