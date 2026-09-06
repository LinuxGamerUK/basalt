import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

import "root:/"

// Network panel — the connection state, the ethernet device, and the
// wifi networks with signal strength. Opened on click from the bar's
// network chip.
Rectangle {
    id: root

    color: Theme.surfaceContainer
    radius: 20
    border.color: Theme.outlineVariant
    border.width: 1

    // The ethernet device (if any) — the first non-wifi managed device.
    readonly property var ethDevice: {
        const devs = Networking.devices.values.filter(
            d => d.nmManaged && d.type !== DeviceType.Wifi);
        return devs.length > 0 ? devs[0] : null;
    }

    // The wifi device + its scanner (if any).
    readonly property var wifiDevice: {
        const devs = Networking.devices.values.filter(
            d => d.type === DeviceType.Wifi && d.nmManaged);
        return devs.length > 0 ? devs[0] : null;
    }

    readonly property bool wifiUp: Networking.wifiEnabled

    // The wifi scanner is off by default in QuickShell — enable it as
    // soon as the panel opens (and keep it on while open) so the
    // network list populates.
    onVisibleChanged: {
        if (visible && wifiDevice !== null) {
            wifiDevice.scannerEnabled = true;
        }
    }

    // Re-assert the scanner enablement when a wifi device appears.
    Connections {
        target: Networking
        ignoreUnknownSignals: true
        function onItemRegistered() {}
    }

    function signalIcon(strength) {
        if (strength > 80) return "󰤨";
        if (strength > 60) return "󰤥";
        if (strength > 40) return "󰤢";
        if (strength > 20) return "󰤟";
        return "󰤯";
    }

    function netStateIcon(device) {
        if (!device) return "󰌙";
        if (device.connected) {
            return device.type === DeviceType.Wifi
                ? "󰤨" : "󰈀";
        }
        return "󰌙";
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        Text {
            text: "NETWORK"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
        }

        // Ethernet
        Text {
            Layout.fillWidth: true
            visible: ethDevice !== null
            text: ethDevice !== null
                ? "󰈀 " + (ethDevice.name || "ethernet")
                    + (ethDevice.connected ? "  ·  connected" : "  ·  disconnected")
                    + (ethDevice.address !== "" ? "  ·  " + ethDevice.address : "")
                : ""
            color: ethDevice !== null && ethDevice.connected
                ? Theme.primary : Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        // Wifi device state
        Text {
            Layout.fillWidth: true
            visible: wifiDevice !== null
            text: wifiDevice !== null
                ? "󰤨 " + (wifiDevice.name || "wifi")
                    + "  ·  " + (wifiDevice.connected ? "connected" : "not connected")
                    + (wifiDevice.address !== "" && wifiDevice.connected
                        ? "  ·  " + wifiDevice.address : "")
                : ""
            color: wifiDevice !== null && wifiDevice.connected
                ? Theme.primary : Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        // The current connection — the connected network's name.
        Text {
            Layout.fillWidth: true
            visible: wifiDevice !== null && wifiDevice.connected
            text: {
                const nets = wifiDevice !== null
                    ? wifiDevice.networks.values : [];
                const conn = nets.filter(n => n.connected);
                return conn.length > 0
                    ? "󰖟 " + (conn[0].name || "connected")
                    : "";
            }
            color: Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.outlineVariant
        }

        // Wifi networks — visible when a wifi device exists and wifi is on.
        Text {
            visible: wifiDevice !== null && root.wifiDevice.scannerEnabled
            text: "WIFI NETWORKS"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 3
            font.bold: true
        }

        ListView {
            id: netList

            visible: wifiDevice !== null && root.wifiDevice.scannerEnabled
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitHeight: Math.min(contentHeight, 260)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: 3

            model: wifiDevice !== null ? root.wifiDevice.networks.values : []

            delegate: Rectangle {
                id: netRow

                required property var modelData
                required property int index

                width: netList.width
                implicitHeight: netRowLayout.implicitHeight + 10
                radius: 8
                color: netMouse.containsMouse
                    ? Theme.surfaceContainerHigh : "transparent"

                RowLayout {
                    id: netRowLayout
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                        text: netRow.modelData.connected
                            ? "󰤨"
                            : root.signalIcon(netRow.modelData.signalStrength ?? 0)
                        color: netRow.modelData.connected
                            ? Theme.primary : Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Text {
                        Layout.fillWidth: true
                        text: netRow.modelData.name || "hidden network"
                        color: netRow.modelData.connected
                            ? Theme.primary : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                        font.bold: netRow.modelData.connected
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Text {
                        visible: (netRow.modelData.security ?? 0) > 0
                        text: "󰌂"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 4
                    }

                    Text {
                        visible: netRow.modelData.known
                        text: "󰄬"
                        color: Theme.primary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 4
                    }
                }

                MouseArea {
                    id: netMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!netRow.modelData.connected) {
                            netRow.modelData.connect();
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: netList.count === 0
                text: "No networks found"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }
        }

        Text {
            visible: wifiDevice !== null && !root.wifiDevice.scannerEnabled
            text: "wifi scanner disabled"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 3
        }
    }
}