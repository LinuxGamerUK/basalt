import QtQuick

import "root:/"

// Custom slider built on MouseArea — QtQuick Controls' Slider did not
// receive button events reliably inside QuickShell popups on Hyprland
// (motion yes, buttons no), while MouseAreas demonstrably do. Full
// click-to-set + drag support, same visual language as before.
Rectangle {
    id: root

    // Bindings provided by the user of the component:
    property real value: 0          // 0..1, bound to/from the owner
    property real from: 0
    property real to: 1
    property bool muted: false
    property string objectName: ""
    readonly property bool pressed: ma.pressed
    signal moved(real value)

    readonly property real norm: (value - from) / (to - from)

    implicitWidth: 200
    implicitHeight: 24
    radius: height / 2
    color: "transparent"

    // Track
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 10
        radius: 5
        color: Theme.surfaceContainerHigh

        // Fill
        Rectangle {
            width: root.norm * parent.width
            height: parent.height
            radius: 5
            color: root.muted ? Theme.errorColor : Theme.primary
        }
    }

    // Handle
    Rectangle {
        x: root.norm * (root.width - width)
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        radius: 9
        color: Theme.text
        border.color: Theme.surface
        border.width: 2
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -6   // forgiving grab zone
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onPressed: (mouse) => {
            console.log("vslider[" + (root.objectName || "?") + "] press",
                "local", mouse.x.toFixed(0) + "," + mouse.y.toFixed(0));
            root._apply(mouse.x);
        }
        onPositionChanged: (mouse) => {
            if (pressed) {
                console.log("vslider[" + (root.objectName || "?") + "] drag",
                    mouse.x.toFixed(0) + "," + mouse.y.toFixed(0));
                root._apply(mouse.x);
            }
        }
    }

    function _apply(localX) {
        const frac = Math.max(0, Math.min(1, localX / width));
        root.value = root.from + frac * (root.to - root.from);
        root.moved(root.value);
    }
}
