import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "root:/"

// Mixer panel — output/input volume sliders with mute, the device
// lists, and the brightness slider. Opened on click from the bar's
// volume/brightness chips.
Rectangle {
    id: root

    color: Theme.surfaceContainer
    radius: 20
    border.color: Theme.outlineVariant
    border.width: 1

    // DEBUG (non-blocking): report presses without consuming them.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        onPositionChanged: (mouse) => console.log("mixer hover at",
            mouse.x.toFixed(0) + "," + mouse.y.toFixed(0))
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // Output
        Text {
            text: "OUTPUT"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
        }

        Text {
            Layout.fillWidth: true
            visible: MixerState.sinkName !== ""
            text: MixerState.sinkName
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: MixerState.sinkMuted ? "󰝟" : "󰕾"
                color: MixerState.sinkMuted ? Theme.error : Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MixerState.toggleSinkMuted()
                }
            }

            VolumeSlider {
                id: sinkSlider
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                value: MixerState.sinkVolume
                muted: MixerState.sinkMuted
                onMoved: MixerState.setSinkVolume(value)

                // Follow the PipeWire echo only while not dragging.
                Connections {
                    target: MixerState
                    function onSinkVolumeChanged() {
                        if (!sinkSlider.pressed)
                            sinkSlider.value = MixerState.sinkVolume;
                    }
                }
            }

            Text {
                text: Math.round(MixerState.sinkVolume * 100) + "%"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.outlineVariant
        }

        // Input
        Text {
            text: "INPUT"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
        }

        Text {
            Layout.fillWidth: true
            visible: MixerState.sourceName !== ""
            text: MixerState.sourceName
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "󰍬"
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MixerState.toggleSourceMuted()
                }
            }

            VolumeSlider {
                id: sourceSlider
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                value: MixerState.sourceVolume
                muted: MixerState.sourceMuted
                onMoved: MixerState.setSourceVolume(value)

                Connections {
                    target: MixerState
                    function onSourceVolumeChanged() {
                        if (!sourceSlider.pressed)
                            sourceSlider.value = MixerState.sourceVolume;
                    }
                }
            }

            Text {
                text: Math.round(MixerState.sourceVolume * 100) + "%"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.outlineVariant
        }

        // Devices
        Text {
            text: "OUTPUT DEVICES"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            Repeater {
                model: MixerState.sinks

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: devText.implicitHeight + 8
                    radius: 8
                    color: MixerState.sink && MixerState.sink.id === modelData.id
                        ? Theme.primaryContainer ?? Theme.surfaceContainerHigh
                        : "transparent"

                    Text {
                        id: devText
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: Text.AlignVCenter
                        text: "• " + (modelData.name || "unknown")
                        color: MixerState.sink && MixerState.sink.id === modelData.id
                            ? Theme.primary : Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MixerState.setSinkById(modelData.id)
                    }
                }
            }
        }

        Text {
            text: "INPUT DEVICES"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            Repeater {
                model: MixerState.sources

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: srcDevText.implicitHeight + 8
                    radius: 8
                    color: MixerState.source && MixerState.source.id === modelData.id
                        ? Theme.surfaceContainerHigh
                        : "transparent"

                    Text {
                        id: srcDevText
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: Text.AlignVCenter
                        text: "• " + (modelData.name || "unknown")
                        color: MixerState.source && MixerState.source.id === modelData.id
                            ? Theme.primary : Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MixerState.setSourceById(modelData.id)
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.outlineVariant
        }

        // Brightness
        Text {
            text: "BRIGHTNESS"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "󰃟"
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            VolumeSlider {
                id: brightSlider
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                value: MixerState.brightnessLevel
                onMoved: MixerState.setBrightness(value)

                Connections {
                    target: MixerState
                    function onBrightnessLevelChanged() {
                        if (!brightSlider.pressed)
                            brightSlider.value = MixerState.brightnessLevel;
                    }
                }
            }

            Text {
                text: Math.round(MixerState.brightnessLevel * 100) + "%"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}