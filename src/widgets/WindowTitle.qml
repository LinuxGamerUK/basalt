import QtQuick
import Quickshell.Hyprland

import "root:/"

// Active window title chip. Empty (hidden) when no window is focused.
Rectangle {
    id: chip

    readonly property string title: {
        const toplevels = Hyprland.toplevels;
        for (let i = 0; i < toplevels.length; i++) {
            if (toplevels[i].active) {
                return toplevels[i].title;
            }
        }
        return "";
    }

    visible: title !== ""
    height: Theme.chipHeight
    radius: Theme.chipRadius
    color: Theme.surfaceContainer

    Text {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        text: chip.title
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 12
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }
}
