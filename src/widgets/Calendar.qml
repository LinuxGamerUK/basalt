import QtQuick
import QtQuick.Layouts
import Quickshell

import "root:/"

// Material calendar dropdown: month grid with today highlighted.
Rectangle {
    id: root

    signal closeRequested

    color: Theme.surfaceContainer
    radius: 20
    border.color: Theme.outlineVariant
    border.width: 1

    property date today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth() // 0-11

    function daysInMonth(y, m) {
        return new Date(y, m + 1, 0).getDate();
    }

    function monthLabel(y, m) {
        return Qt.formatDateTime(new Date(y, m, 1), "MMMM yyyy");
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        // Header: month name + nav chevrons
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: root.monthLabel(root.viewYear, root.viewMonth)
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
            }

            Rectangle {
                width: 26; height: 26; radius: 13
                color: Theme.surfaceContainerHigh
                Text {
                    anchors.centerIn: parent
                    text: "‹"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.viewMonth -= 1;
                        if (root.viewMonth < 0) {
                            root.viewMonth = 11;
                            root.viewYear -= 1;
                        }
                    }
                }
            }

            Rectangle {
                width: 26; height: 26; radius: 13
                color: Theme.surfaceContainerHigh
                Text {
                    anchors.centerIn: parent
                    text: "›"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.viewMonth += 1;
                        if (root.viewMonth > 11) {
                            root.viewMonth = 0;
                            root.viewYear += 1;
                        }
                    }
                }
            }
        }

        // Weekday header (weeks start Monday)
        RowLayout {
            Layout.fillWidth: true
            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                Text {
                    required property var modelData
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
            }
        }

        // Day grid
        Grid {
            id: grid
            Layout.fillWidth: true
            columns: 7
            spacing: 2

            Repeater {
                model: 42

                delegate: Item {
                    required property int index

                    readonly property int offset: (new Date(root.viewYear, root.viewMonth, 1).getDay() + 6) % 7
                    readonly property int day: index - offset + 1
                    readonly property int maxDay: root.daysInMonth(root.viewYear, root.viewMonth)
                    readonly property bool valid: day >= 1 && day <= maxDay
                    readonly property bool isToday: valid
                        && root.viewYear === root.today.getFullYear()
                        && root.viewMonth === root.today.getMonth()
                        && day === root.today.getDate()

                    width: (grid.width - 12) / 7
                    height: 36

                    Rectangle {
                        anchors.centerIn: parent
                        width: 32; height: 32; radius: 16
                        visible: parent.isToday
                        color: Theme.primary
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: parent.valid
                        text: parent.day
                        color: parent.isToday ? Theme.textOnPrimary
                             : (parent.valid ? Theme.text : Theme.outline)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.bold: parent.isToday
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.closeRequested()
                    }
                }
            }
        }
    }
}