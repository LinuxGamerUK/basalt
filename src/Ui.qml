pragma Singleton

import QtQuick
import Quickshell

// UI state shared across the shell: which popups are open, and the
// click-outside catcher's close-all hook. House rule: any click outside
// an open popup closes it.
Singleton {
    id: root

    property bool pickerOpen: false
    property bool calendarOpen: false
    readonly property bool anythingOpen: pickerOpen || calendarOpen

    function closeAll() {
        pickerOpen = false;
        calendarOpen = false;
    }
}