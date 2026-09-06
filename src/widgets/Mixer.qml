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

            Slider {
                id: sinkSlider
                Layout.fillWidth: true
                from: 0
                to: 1
                value: 0
                onMoved: {
                    MixerState.setSinkVolume(value);
                    console.log("sinkSlider MOVED to", value);
                }

                // Imperative value sync: a reactive value-binding here
                // yanks the handle back mid-drag on every PipeWire echo
                // (the classic two-way-binding fight). Follow the server
                // only while the user is not holding the handle.
                Component.onCompleted: value = MixerState.sinkVolume

                onPressed: console.log("sinkSlider PRESSED at", value)
                onPressedChanged: if (!pressed) console.log("sinkSlider RELEASED at", value)

                Connections {
                    target: MixerState
                    function onSinkVolumeChanged() {
                        if (!sinkSlider.pressed)
                            sinkSlider.value = MixerState.sinkVolume;
                    }
                }

                background: Rectangle {
                    x: sinkSlider.leftPadding
                    y: sinkSlider.topPadding + sinkSlider.availableHeight / 2 - height / 2
                    width: sinkSlider.availableWidth
                    height: 10
                    radius: 5
                    color: Theme.surfaceContainerHigh

                    Rectangle {
                        width: sinkSlider.visualPosition * parent.width
                        height: parent.height
                        radius: 5
                        color: MixerState.sinkMuted ? Theme.error : Theme.primary
                    }
                }

                handle: Rectangle {
                    x: sinkSlider.leftPadding + sinkSlider.visualPosition * sinkSlider.availableWidth - width / 2
                    y: sinkSlider.topPadding + sinkSlider.availableHeight / 2 - height / 2
                    width: 18
                    height: 18
                    radius: 9
                    color: Theme.text
                    border.color: Theme.primary
                    border.width: 2
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

            Slider {
                id: sourceSlider
                Layout.fillWidth: true
                from: 0
                to: 1
                value: 0
                onMoved: {
                    MixerState.setSourceVolume(value);
                    console.log("sourceSlider MOVED to", value);
                }

                Component.onCompleted: value = MixerState.sourceVolume

                Connections {
                    target: MixerState
                    function onSourceVolumeChanged() {
                        if (!sourceSlider.pressed)
                            sourceSlider.value = MixerState.sourceVolume;
                    }
                }

                background: Rectangle {
                    x: sourceSlider.leftPadding
                    y: sourceSlider.topPadding + sourceSlider.availableHeight / 2 - height / 2
                    width: sourceSlider.availableWidth
                    height: 10
                    radius: 5
                    color: Theme.surfaceContainerHigh

                    Rectangle {
                        width: sourceSlider.visualPosition * parent.width
                        height: parent.height
                        radius: 5
                        color: Theme.primary
                    }
                }

                handle: Rectangle {
                    x: sourceSlider.leftPadding + sourceSlider.visualPosition * sourceSlider.availableWidth - width / 2
                    y: sourceSlider.topPadding + sourceSlider.availableHeight / 2 - height / 2
                    width: 18
                    height: 18
                    radius: 9
                    color: Theme.text
                    border.color: Theme.primary
                    border.width: 2
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

            Slider {
                id: brightSlider
                Layout.fillWidth: true
                from: 0
                to: 1
                value: MixerState.brightnessLevel
                onMoved: MixerState.setBrightness(value)

                background: Rectangle {
                    x: brightSlider.leftPadding
                    y: brightSlider.topPadding + brightSlider.availableHeight / 2 - height / 2
                    width: brightSlider.availableWidth
                    height: 10
                    radius: 5
                    color: Theme.surfaceContainerHigh

                    Rectangle {
                        width: brightSlider.visualPosition * parent.width
                        height: parent.height
                        radius: 5
                        color: Theme.primary
                    }
                }

                handle: Rectangle {
                    x: brightSlider.leftPadding + brightSlider.visualPosition * brightSlider.availableWidth - width / 2
                    y: brightSlider.topPadding + brightSlider.availableHeight / 2 - height / 2
                    width: 18
                    height: 18
                    radius: 9
                    color: Theme.text
                    border.color: Theme.primary
                    border.width: 2
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