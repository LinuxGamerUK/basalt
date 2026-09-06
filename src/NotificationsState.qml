pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Basalt notification daemon + history.
//
// QuickShell IS the system notification server (org.freedesktop.Notifications)
// — no mako/dunst. Apps (Discord, Brave, everything) send over D-Bus and
// arrive here. Each toast is shown for 3s (house rule) in the top-right,
// and kept in an in-memory history with clear-all / clear-one.
Singleton {
    id: root

    // History: newest first. Capped so a chatty session can't grow forever.
    property var history: []
    property int maxHistory: 100
    // How many history entries have been seen (badge = history.length - seenCount).
    property int seenCount: 0
    readonly property int unread: Math.max(0, history.length - seenCount)
    // The daemon itself — toasts render from its tracked notifications.
    readonly property alias serverRef: server

    function markSeen() {
        seenCount = history.length;
    }

    function clearAll() {
        history = [];
        seenCount = 0;
    }

    function removeAt(index) {
        if (index < 0 || index >= history.length) return;
        const next = history.slice();
        next.splice(index, 1);
        history = next;
        if (seenCount > history.length) seenCount = history.length;
    }

    function push(entry) {
        const next = [entry].concat(history).slice(0, maxHistory);
        history = next;
    }

    NotificationServer {
        id: server
        keepOnReload: true

        // Advertise what we render.
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: (toast) => {
            // DEBUG: what actually arrives + the tracked-window state.
            console.log("toast: id=" + toast.id
                + " summary=" + (toast.summary || "")
                + " tracked=" + toast.tracked
                + " expire=" + toast.expireTimeout);
            Qt.callLater(() => console.log("tracked count:",
                server.trackedNotifications.values.length));
            // House rule: toasts live 3 seconds. NOTE: expireTimeout is
            // READ-ONLY in quickshell 0.3.1 — assigning it throws and
            // would abort this handler (the history push below never
            // ran). The toastExpireTimer enforces the 3s instead.
            root.push({
                id: toast.id,
                appName: toast.appName || "unknown",
                summary: toast.summary || "",
                body: toast.body || "",
                appIcon: toast.appIcon || "",
                image: toast.image || "",
                urgency: toast.urgency ?? 0,
                time: Qt.formatDateTime(new Date(), "HH:mm"),
            });
            // Auto-expire after 3s — the server tracks it; expire() to be
            // sure a zero/never-expire timeout still clears.
            Qt.callLater(() => {
                if (toast.tracked) {
                    toastExpireTimer.toast = toast;
                    toastExpireTimer.restart();
                }
            });
        }
    }

    Timer {
        id: toastExpireTimer
        property var toast: null
        interval: 3000
        onTriggered: {
            if (toast && toast.tracked) {
                toast.expire();
            }
            toast = null;
        }
    }
}