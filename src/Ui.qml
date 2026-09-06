pragma Singleton

import QtQuick
import Quickshell

// UI state shared across the shell, and the click-outside catcher's
// close-all hook.
//
// HOUSE RULE: a popup opens ONLY on the screen whose bar button was
// clicked. Clicking the same button again closes it. Clicking anywhere
// outside an open popup (any screen) closes it. Opening a popup on
// another screen moves it there unchanged — state is shared, not
// per-instance. One-at-a-time across all of them.
Singleton {
    id: root

    property string pickerScreen: ""
    property string calendarScreen: ""
    property string notificationsScreen: ""
    property string launcherScreen: ""
    property string mixerScreen: ""

    readonly property bool anythingOpen: pickerScreen !== "" || calendarScreen !== ""
        || notificationsScreen !== "" || launcherScreen !== "" || mixerScreen !== ""

    function togglePicker(screen) {
        calendarScreen = "";
        notificationsScreen = "";
        launcherScreen = "";
        mixerScreen = "";
        root.pickerScreen = (root.pickerScreen === screen) ? "" : screen;
    }

    function toggleCalendar(screen) {
        pickerScreen = "";
        notificationsScreen = "";
        launcherScreen = "";
        mixerScreen = "";
        root.calendarScreen = (root.calendarScreen === screen) ? "" : screen;
    }

    function toggleNotifications(screen) {
        pickerScreen = "";
        calendarScreen = "";
        launcherScreen = "";
        mixerScreen = "";
        root.notificationsScreen = (root.notificationsScreen === screen) ? "" : screen;
    }

    function toggleLauncher(screen) {
        pickerScreen = "";
        calendarScreen = "";
        notificationsScreen = "";
        mixerScreen = "";
        root.launcherScreen = (root.launcherScreen === screen) ? "" : screen;
    }

    function toggleMixer(screen) {
        pickerScreen = "";
        calendarScreen = "";
        notificationsScreen = "";
        launcherScreen = "";
        root.mixerScreen = (root.mixerScreen === screen) ? "" : screen;
    }

    function closeAll() {
        pickerScreen = "";
        calendarScreen = "";
        notificationsScreen = "";
        launcherScreen = "";
        mixerScreen = "";
    }
}