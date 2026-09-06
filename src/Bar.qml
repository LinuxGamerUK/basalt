import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pipewire

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
    readonly property bool launcherOpen: Ui.launcherScreen === root.screenName
    readonly property bool mixerOpen: Ui.mixerScreen === root.screenName
    readonly property bool brightnessOpen: Ui.brightnessScreen === root.screenName
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

            // Left: the launcher button, then this screen's workspaces,
            // then the window title chip
            Rectangle {
                id: launchBtn
                implicitWidth: Theme.chipHeight
                implicitHeight: Theme.chipHeight
                radius: height / 2
                color: root.launcherOpen ? Theme.primary : Theme.surfaceContainerHigh
                // The real NixOS snowflake — blue when closed, the white
                // variant on the accent fill while open. The colored SVG
                // is HM-managed at the local hicolor override; the white
                // resolves through the icon provider.
                Image {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: root.launcherOpen
                        ? "image://icon/nix-snowflake-white"
                        : "file://" + Quickshell.env("HOME")
                            + "/.local/share/icons/hicolor/scalable/apps/nix-snowflake.svg"
                    sourceSize.width: 40
                    sourceSize.height: 40
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Ui.toggleLauncher(root.screenName)
                }
            }
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

            // Right: volume + brightness chips, then tray, then the
            // picker and notifications buttons rightmost

            // Volume — the default sink; scroll ±5%, click toggles mute.
            PwObjectTracker {
                objects: Pipewire.defaultAudioSink
                    ? [Pipewire.defaultAudioSink]
                    : []
            }

            Rectangle {
                id: volumeChip

                readonly property var audio: Pipewire.defaultAudioSink?.audio ?? null
                readonly property real level: audio ? audio.volume : 0
                readonly property bool muted: audio ? audio.muted : false

                implicitWidth: 46
                implicitHeight: Theme.chipHeight - 6
                radius: height / 2
                color: mouse.containsMouse
                    ? Theme.surfaceContainerHigh : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 5

                    Text {
                        text: volumeChip.muted
                            ? "󰝟"
                            : (volumeChip.level > 0.5 ? "󰕾" : "󰖀")
                        color: volumeChip.muted
                            ? Theme.error : Theme.primary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Text {
                        text: Math.round(volumeChip.level * 100) + "%"
                        color: volumeChip.muted
                            ? Theme.textSecondary : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 3
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onClicked: Ui.toggleMixer(root.screenName)
                    onWheel: (wheel) => {
                        if (volumeChip.audio) {
                            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                            const next = Math.max(0, Math.min(1,
                                volumeChip.level + step));
                            volumeChip.audio.volume = next;
                            volumeChip.audio.muted = false;
                        }
                    }
                }
            }

            // Brightness — the sysfs backlight; scroll ±5%. Level is
            // 0% (dark) → 100% (bright), read by MixerState's poll; the
            // chip shows the accent fill until the first poll lands.

            Rectangle {
                id: brightnessChip

                readonly property real level: MixerState.brightnessLevel

                implicitWidth: 46
                implicitHeight: Theme.chipHeight - 6
                radius: height / 2
                color: brightMouse.containsMouse
                    ? Theme.surfaceContainerHigh : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 5

                    Text {
                        text: "󰃟"
                        color: Theme.primary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Text {
                        text: MixerState.brightnessCur >= 0
                            ? Math.round(brightnessChip.level * 100) + "%"
                            : "…"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 3
                    }
                }

                MouseArea {
                    id: brightMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Ui.toggleBrightness(root.screenName)
                    onWheel: (wheel) => {
                        const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                        const next = Math.max(0, Math.min(1,
                            brightnessChip.level + step));
                        MixerState.setBrightness(next);
                    }
                }
            }

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

    // Mixer — audio devices + input/output volumes + brightness. Opened
    // on click from either chip, right-aligned under the bar.
    PopupWindow {
        id: mixerPopup
        anchor.window: root
        anchor.edges: Edges.Bottom
        anchor.rect.x: Math.max(8, root.width - 416)
        anchor.rect.y: Theme.barHeight + Theme.barMargin * 2
        visible: root.mixerOpen
        implicitWidth: Math.round(400 * Theme.uiScale)
        implicitHeight: Math.round(520 * Theme.uiScale)
        color: Qt.rgba(0, 0, 0, 0)

        Mixer {
            anchors.fill: parent
        }
    }

    // Brightness panel — the sun chip's own popup.
    PopupWindow {
        id: brightnessPopup
        anchor.window: root
        anchor.edges: Edges.Bottom
        anchor.rect.x: Math.max(8, root.width - 386)
        anchor.rect.y: Theme.barHeight + Theme.barMargin * 2
        visible: root.brightnessOpen
        implicitWidth: Math.round(370 * Theme.uiScale)
        implicitHeight: Math.round(120 * Theme.uiScale)
        color: Qt.rgba(0, 0, 0, 0)

        BrightnessPanel {
            anchors.fill: parent
        }
    }
}