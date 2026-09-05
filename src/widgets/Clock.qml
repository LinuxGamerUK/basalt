import QtQuick
import Quickshell

// Clock chip — date + time, seconds precision for a live sweep.
Rectangle {
    id: chip
    height: Theme.chipHeight
    radius: Theme.chipRadius
    color: Theme.surfaceContainerHigh

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Text {
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "ddd dd MMM  ·  HH:mm")
        color: Theme.onSurface
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }
}
