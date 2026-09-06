import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "root:/"

// Brightness panel — a compact slider for the sysfs backlight. Opened
// on click from the bar's brightness chip (separate from the audio
// mixer — clicking the sun should give the sun, not the sound).
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
                font.pixelSize: Theme.fontSize + 4
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
                    height: 12
                    radius: 6
                    color: Theme.surfaceContainerHigh

                    Rectangle {
                        width: brightSlider.visualPosition * parent.width
                        height: parent.height
                        radius: 6
                        color: Theme.primary
                    }
                }

                handle: Rectangle {
                    x: brightSlider.leftPadding + brightSlider.visualPosition * brightSlider.availableWidth - width / 2
                    y: brightSlider.topPadding + brightSlider.availableHeight / 2 - height / 2
                    width: 20
                    height: 20
                    radius: 10
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
                Layout.preferredWidth: 46
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}