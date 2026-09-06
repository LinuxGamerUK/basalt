pragma Singleton

import QtQuick
import Quickshell

// UI state shared across the shell, and the click-outside catcher's
// close-all hook.
//
// HOUSE RULE: a popup opens ONLY on the screen whose bar button was
// clicked ("pickerScreen"/"calendarScreen"/"notificationsScreen" hold
// that screen's name). Clicking the same button again closes it.
// Clicking anywhere outside an open popup (any screen) closes it.
// Opening a popup on another screen moves it there unchanged — state is
// shared, not per-instance.
Singleton {
    id: root

    property string pickerScreen: ""   // screen name showing the picker, "" = closed
    property string calendarScreen: "" // screen name showing the calendar, "" = closed
    property string notificationsScreen: "" // screen name showing the history, "" = closed

    readonly property bool anythingOpen: pickerScreen !== "" || calendarScreen !== "" || notificationsScreen !== ""

    // Toggle the picker for a specific screen.
    function togglePicker(screen) {
        if (calendarScreen !== "") calendarScreen = "";
        if (notificationsScreen !== "") notificationsScreen = "";
        root.pickerScreen = (root.pickerScreen === screen) ? "" : screen;
    }

    function toggleCalendar(screen) {
        if (pickerScreen !== "") pickerScreen = "";
        if (notificationsScreen !== "") notificationsScreen = "";
        root.calendarScreen = (root.calendarScreen === screen) ? "" : screen;
    }

    function toggleNotifications(screen) {
        if (pickerScreen !== "") pickerScreen = "";
        if (calendarScreen !== "") calendarScreen = "";
        root.notificationsScreen = (root.notificationsScreen === screen) ? "" : screen;
    }

    function closeAll() {
        pickerScreen = "";
        calendarScreen = "";
        notificationsScreen = "";
    }
}