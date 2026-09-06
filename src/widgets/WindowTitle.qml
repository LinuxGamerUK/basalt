import QtQuick
import Quickshell.Hyprland

import "root:/"

// Active window title chip. Empty (hidden) when no window is focused.
Rectangle {
    id: chip

    readonly property string title: {
        const tl = Hyprland.activeToplevel;
        return tl ? (tl.title ?? "") : "";
    }

    visible: title !== ""
    implicitWidth: titleText.implicitWidth + 28
    implicitHeight: Theme.chipHeight
    radius: Theme.chipRadius
    color: Theme.surfaceContainer

    Text {
        id: titleText
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        text: chip.title
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }
}
