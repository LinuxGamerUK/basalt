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
    property string brightnessScreen: ""
    property string networkScreen: ""
    property string settingsScreen: ""

    readonly property bool anythingOpen: pickerScreen !== "" || calendarScreen !== ""
        || notificationsScreen !== "" || launcherScreen !== "" || mixerScreen !== ""
        || brightnessScreen !== "" || networkScreen !== "" || settingsScreen !== ""

    function togglePicker(screen) {
        settingsScreen = "";
        calendarScreen = "";
        notificationsScreen = "";
        launcherScreen = "";
        mixerScreen = "";
        brightnessScreen = "";
        networkScreen = "";
        root.pickerScreen = (root.pickerScreen === screen) ? "" : screen;
    }

    function toggleCalendar(screen) {
        settingsScreen = "";
        pickerScreen = "";
        notificationsScreen = "";
        launcherScreen = "";
        mixerScreen = "";
        brightnessScreen = "";
        networkScreen = "";
        root.calendarScreen = (root.calendarScreen === screen) ? "" : screen;
    }

    function toggleNotifications(screen) {
        settingsScreen = "";
        pickerScreen = "";
        calendarScreen = "";
        launcherScreen = "";
        mixerScreen = "";
        brightnessScreen = "";
        networkScreen = "";
        root.notificationsScreen = (root.notificationsScreen === screen) ? "" : screen;
    }

    function toggleLauncher(screen) {
        settingsScreen = "";
        pickerScreen = "";
        calendarScreen = "";
        notificationsScreen = "";
        mixerScreen = "";
        brightnessScreen = "";
        networkScreen = "";
        root.launcherScreen = (root.launcherScreen === screen) ? "" : screen;
    }

    function toggleMixer(screen) {
        settingsScreen = "";
        pickerScreen = "";
        calendarScreen = "";
        notificationsScreen = "";
        launcherScreen = "";
        brightnessScreen = "";
        networkScreen = "";
        root.mixerScreen = (root.mixerScreen === screen) ? "" : screen;
    }

    function toggleBrightness(screen) {
        settingsScreen = "";
        pickerScreen = "";
        calendarScreen = "";
        notificationsScreen = "";
        launcherScreen = "";
        mixerScreen = "";
        networkScreen = "";
        root.brightnessScreen = (root.brightnessScreen === screen) ? "" : screen;
    }

    function toggleNetwork(screen) {
        settingsScreen = "";
        pickerScreen = "";
        calendarScreen = "";
        notificationsScreen = "";
        launcherScreen = "";
        mixerScreen = "";
        brightnessScreen = "";
        root.networkScreen = (root.networkScreen === screen) ? "" : screen;
    }

    function toggleSettings(screen) {
        pickerScreen = "";
        calendarScreen = "";
        notificationsScreen = "";
        launcherScreen = "";
        mixerScreen = "";
        brightnessScreen = "";
        networkScreen = "";
        root.settingsScreen = (root.settingsScreen === screen) ? "" : screen;
    }

    function closeAll() {
        pickerScreen = "";
        calendarScreen = "";
        notificationsScreen = "";
        launcherScreen = "";
        mixerScreen = "";
        brightnessScreen = "";
        networkScreen = "";
        settingsScreen = "";
    }
}