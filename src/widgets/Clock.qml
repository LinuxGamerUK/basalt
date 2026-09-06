import QtQuick
import Quickshell

import "root:/"

// Clock chip — date and time, dot-separated, centered in the bar.
// Clicking it drops the calendar.
Rectangle {
    id: chip

    signal clicked()

    implicitWidth: timeText.implicitWidth + 28
    implicitHeight: Theme.chipHeight
    radius: Theme.chipRadius
    color: Theme.surfaceContainerHigh

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Text {
        id: timeText
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "ddd dd MMM  ·  HH:mm")
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
