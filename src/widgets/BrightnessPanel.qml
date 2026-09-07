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

            VolumeSlider {
                id: brightSlider
                objectName: "brightness"
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
                Layout.preferredWidth: 46
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}