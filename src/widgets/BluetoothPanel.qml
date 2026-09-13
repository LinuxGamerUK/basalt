import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth

import "root:/"

// Bluetooth panel — adapter power toggle, scan-and-connect, and the
// paired ("remembered") device list. Opened on click from the bar's
// bluetooth chip; visual language matches NetworkPanel — rectangles,
// Theme text, ContactHand rows. Backend is bluez via Quickshell's
// Bluetooth module (the same D-Bus surface blueman sits on; blueman
// stays available for anything deeper like device services).
Rectangle {
    id: root

    color: Theme.surfaceContainer
    radius: 20
    border.color: Theme.outlineVariant
    border.width: 1

    readonly property var adapter: Bluetooth.defaultAdapter

    // Paired/bonded = "trusted / remembered" — these reconnect on demand.
    readonly property var knownDevices: {
        const all = Bluetooth.devices.values.filter(
            d => d.adapter !== null
                && adapter !== null
                && d.adapter.dbusPath === adapter.dbusPath
                && (d.paired || d.bonded));
        // Connected first, then most-recently-usable (name is the only
        // stable order bluez gives us on top of connection state).
        return all.sort((a, b) => {
            if (b.connected !== a.connected) return b.connected ? 1 : -1;
            return (a.name || a.address).localeCompare(b.name || b.address);
        });
    }

    readonly property var foundDevices: {
        if (adapter === null || !adapter.discovering) return [];
        return Bluetooth.devices.values.filter(
            d => d.adapter !== null
                && d.adapter.dbusPath === adapter.dbusPath
                && !d.paired && !d.bonded);
    }

    readonly property var pairingDevices: {
        return Bluetooth.devices.values.filter(
            d => d.adapter !== null
                && (d.pairing || d.state === BluetoothDeviceState.Connecting));
    }

    function deviceIcon(dev) {
        const t = (dev.icon || "");
        if (t.includes("audio")) return "󰂃";
        if (t.includes("input-headset") || t.includes("headset")) return "󰟎";
        if (t.includes("input-keyboard") || t.includes("keyboard")) return "󰌄";
        if (t.includes("input-mouse") || t.includes("mouse")) return "󰍽";
        if (t.includes("phone")) return "󰄜";
        if (t.includes("computer")) return "󰟔";
        return "󰂯";
    }

    // Stopping scanning when the popup closes keeps the radio from
    // chattering in the background forever.
    onVisibleChanged: {
        if (!visible && adapter !== null && adapter.discovering) {
            adapter.discovering = false;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        Text {
            text: "BLUETOOTH"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
        }

        // No adapter — dim the whole panel and explain.
        Text {
            visible: adapter === null
            text: "no bluetooth adapter found"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }

        // rfkill — blocked-by-KILL-SWITCH adapters silently refuse every
        // DBus power write; surface it instead of eating the click.
        Text {
            visible: adapter !== null
                && adapter.state === BluetoothAdapterState.Blocked
            Layout.fillWidth: true
            text: " Bluetooth is rfkill-blocked — run:\n sudo rfkill unblock bluetooth\n"
            color: Theme.errorColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }

        // ── Power row ────────────────────────────────────────────────
        RowLayout {
            visible: adapter !== null
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: deviceIcon({ icon: "bluetooth" })
                color: adapter !== null && adapter.enabled
                    ? Theme.primary : Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            Text {
                Layout.fillWidth: true
                text: root.adapter !== null && root.adapter.enabled
                    ? "Bluetooth on"
                    : "Bluetooth off"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            // In-house Material switch (track + thumb) — matches the
            // custom slider language in the mixer/brightness panels.
            Rectangle {
                id: powerSwitch

                implicitWidth: 46
                implicitHeight: 26
                radius: 13
                color: isOn
                    ? Theme.primary
                    : Theme.surfaceContainerHigh
                border.color: Theme.outlineVariant
                border.width: 1
                opacity: root.adapter !== null && root.adapter.state
                    === BluetoothAdapterState.Disabling ? 0.5 : 1.0

                property bool isOn: root.adapter !== null
                    && root.adapter.enabled

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: parent.isOn
                        ? parent.width - width - 4
                        : 4
                    Behavior on x { NumberAnimation { duration: 120 } }

                    implicitWidth: 18
                    implicitHeight: 18
                    radius: 9
                    color: parent.isOn
                        ? Theme.textOnPrimary : Theme.textSecondary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.adapter !== null) {
                            root.adapter.enabled = !root.adapter.enabled;
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.outlineVariant
        }

        // ── Scan button ──────────────────────────────────────────────
        Rectangle {
            visible: adapter !== null && adapter.enabled
            Layout.fillWidth: true
            implicitHeight: 38
            radius: 12
            color: scanMouse.containsMouse
                ? Theme.surfaceContainerHigh
                : Theme.surfaceContainer
            border.color: root.adapter !== null && root.adapter.discovering
                ? Theme.primary : Theme.outlineVariant
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: root.adapter !== null && root.adapter.discovering
                    ? "󰑐  Scanning — click to stop"
                    : "󰍉  Search for devices"
                color: root.adapter !== null && root.adapter.discovering
                    ? Theme.primary : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            MouseArea {
                id: scanMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.adapter.discovering = !root.adapter.discovering
            }
        }

        // ── In-flight pairing/connection status strip ───────────────
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.pairingDevices.length > 0
            spacing: 4

            Repeater {
                model: root.pairingDevices

                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "󰑐"
                        color: Theme.primary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                        RotationAnimation on rotation {
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 1200
                            running: visible
                        }
                    }

                    Text {
                        text: modelData.pairing
                            ? (modelData.name || modelData.address) + " — pairing…"
                            : (modelData.name || modelData.address) + " — connecting…"
                        color: Theme.primary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
            }
        }

        // ── Paired / remembered devices ──────────────────────────────
        Text {
            visible: adapter !== null && adapter.enabled
            text: "DEVICES"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 3
            font.bold: true
        }

        ListView {
            id: knownList

            visible: adapter !== null && adapter.enabled
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitHeight: Math.min(contentHeight, 240)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: 3

            model: root.knownDevices

            delegate: Rectangle {
                id: knownRow

                required property var modelData
                required property int index

                width: knownList.width
                implicitHeight: knownRowLayout.implicitHeight + 10
                radius: 8
                color: knownMouse.containsMouse
                    ? Theme.surfaceContainerHigh : "transparent"

                RowLayout {
                    id: knownRowLayout
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                        text: root.deviceIcon(knownRow.modelData)
                        color: knownRow.modelData.connected
                            ? Theme.primary : Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: knownRow.modelData.name || knownRow.modelData.address
                            color: knownRow.modelData.connected
                                ? Theme.primary : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                            font.bold: knownRow.modelData.connected
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        // Battery — one line, theme-following.
                        Text {
                            visible: knownRow.modelData.batteryAvailable
                            text: "󰁹 "
                                + Math.round(knownRow.modelData.battery * 100)
                                + "%"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 4
                        }
                    }

                    Text {
                        text: knownRow.modelData.connected
                            ? "connected"
                            : "click to connect"
                        color: knownRow.modelData.connected
                            ? Theme.primary : Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 3
                    }

                    // Forget (untrust) — hover-revealed so the default
                    // view stays clean; a deliberate click target.
                    Text {
                        visible: knownMouse.containsMouse
                        text: "󰅜"
                        color: Theme.errorColor
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: knownRow.modelData.forget()
                        }
                    }
                }

                MouseArea {
                    id: knownMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (knownRow.modelData.connected) {
                            knownRow.modelData.disconnect();
                        } else {
                            knownRow.modelData.trusted = true;
                            knownRow.modelData.connect();
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.knownDevices.length === 0
                text: "No remembered devices yet"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }
        }

        // ── Discovered (new) devices ─────────────────────────────────
        Text {
            visible: adapter !== null && adapter.enabled
                && adapter.discovering && root.foundDevices.length > 0
            text: "AVAILABLE"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 3
            font.bold: true
        }

        ListView {
            id: foundList

            visible: adapter !== null && adapter.enabled
                && adapter.discovering && root.foundDevices.length > 0
            Layout.fillWidth: true
            implicitHeight: Math.min(contentHeight, 160)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: 3

            model: root.foundDevices

            delegate: Rectangle {
                id: foundRow

                required property var modelData
                required property int index

                width: foundList.width
                implicitHeight: foundRowLayout.implicitHeight + 10
                radius: 8
                color: foundMouse.containsMouse
                    ? Theme.surfaceContainerHigh : "transparent"

                RowLayout {
                    id: foundRowLayout
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                        text: root.deviceIcon(foundRow.modelData)
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Text {
                        Layout.fillWidth: true
                        text: foundRow.modelData.name || foundRow.modelData.address
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Text {
                        text: "pair to add"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 3
                    }
                }

                MouseArea {
                    id: foundMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        foundRow.modelData.trusted = true;
                        foundRow.modelData.pair();
                    }
                }
            }
        }
    }
}
