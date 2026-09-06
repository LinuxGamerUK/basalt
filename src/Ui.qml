pragma Singleton

import QtQuick
import Quickshell

// UI state shared across the shell, and the click-outside catcher's
// close-all hook.
//
// HOUSE RULE: a popup opens ONLY on the screen whose bar button was
// clicked ("pickerScreen"/"calendarScreen"/"notificationsScreen"/
// "launcherScreen" hold that screen's name). Clicking the same button
// again closes it. Clicking anywhere outside an open popup (any screen)
// closes it. Opening a popup on another screen moves it there unchanged —
// state is shared, not per-instance. The launcher is the exception in
// TRIGGER (keybind or button) but follows the same one-at-a-time rule.
Singleton {
    id: root

    property string pickerScreen: ""   // screen name showing the picker, "" = closed
    property string calendarScreen: "" // screen name showing the calendar, "" = closed
    property string notificationsScreen: "" // screen name showing the history, "" = closed
    property string launcherScreen: "" // screen name showing the launcher, "" = closed

    readonly property bool anythingOpen: pickerScreen !== "" || calendarScreen !== ""
        || notificationsScreen !== "" || launcherScreen !== ""

    // Toggle the picker for a specific screen.
    function togglePicker(screen) {
        if (calendarScreen !== "") calendarScreen = "";
        if (notificationsScreen !== "") notificationsScreen = "";
        if (launcherScreen !== "") launcherScreen = "";
        root.pickerScreen = (root.pickerScreen === screen) ? "" : screen;
    }

    function toggleCalendar(screen) {
        if (pickerScreen !== "") pickerScreen = "";
        if (notificationsScreen !== "") notificationsScreen = "";
        if (launcherScreen !== "") launcherScreen = "";
        root.calendarScreen = (root.calendarScreen === screen) ? "" : screen;
    }

    function toggleNotifications(screen) {
        if (pickerScreen !== "") pickerScreen = "";
        if (calendarScreen !== "") calendarScreen = "";
        if (launcherScreen !== "") launcherScreen = "";
        root.notificationsScreen = (root.notificationsScreen === screen) ? "" : screen;
    }

    function toggleLauncher(screen) {
        if (pickerScreen !== "") pickerScreen = "";
        if (calendarScreen !== "") calendarScreen = "";
        if (notificationsScreen !== "") notificationsScreen = "";
        root.launcherScreen = (root.launcherScreen === screen) ? "" : screen;
    }

    function closeAll() {
        pickerScreen = "";
        calendarScreen = "";
        notificationsScreen = "";
        launcherScreen = "";
    }
}