// Native D-Bus menus (tray right-click) require QApplication mode.
//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "widgets"
import "filemgr"
import "."

// Basalt shell root — one identical bar per screen; workspaces are
// filtered per-screen inside each Bar. modelData/screen live on Bar.qml
// itself — do NOT redeclare them inline here (shadowing breaks the
// Variants injection).
ShellRoot {
    // Launcher IPC — `qs ipc call launcher toggle` from the Hyprland
    // keybind. Opens on the focused monitor (house per-screen rule).
    IpcHandler {
        target: "launcher"

        function toggle() {
            const focused = Hyprland.focusedMonitor
                ? Hyprland.focusedMonitor.name : "";
            if (focused !== "") {
                Ui.toggleLauncher(focused);
            }
        }
    }

    // Mixer IPC — `qs ipc call mixer toggle`: opens the mixer on the
    // focused monitor (also lets synthetic pointer drags be tested).
    IpcHandler {
        target: "mixer"

        function toggle() {
            const focused = Hyprland.focusedMonitor
                ? Hyprland.focusedMonitor.name : "";
            if (focused !== "") {
                Ui.toggleMixer(focused);
            }
        }
    }

    // Brightness IPC — `basalt-ipc brightness set <level 0-1>`: drives
    // the same serialized queue the panel drag uses. Also the hook for
    // XF86MonBrightness keybinds later.
    IpcHandler {
        target: "brightness"

        function set(level: string): void {
            const v = parseFloat(level);
            if (!isNaN(v)) MixerState.setBrightness(v);
        }

        function toggle(): void {
            const focused = Hyprland.focusedMonitor
                ? Hyprland.focusedMonitor.name : "";
            if (focused !== "") {
                Ui.toggleBrightness(focused);
            }
        }
    }

    // Files IPC — `qs ipc call files toggle` (works only when the
    // basalt module has the file manager enabled: the window's backend
    // binary resolves `flea` from PATH).
    IpcHandler {
        target: "files"

        function toggle() {
            const focused = Hyprland.focusedMonitor
                ? Hyprland.focusedMonitor.name : "";
            if (focused !== "") {
                FilesState.toggleOnScreen(focused);
            }
        }

        function dbg(): string {
            return FilesState.diag.length > 0 ? FilesState.diag : "(no notes yet)";
        }
    }

    // Files window — one per screen (house per-screen rule), created
    // hidden; the backend process spawns on first open and drains on
    // last close. Visibility is shared state via FilesState.
    Variants {
        model: Quickshell.screens

        delegate: Component {
            FilesWindow {}
        }
    }

    // Click-catcher — created first so it maps at the BOTTOM of the
    // layer: bars and popups always stack above it. Its MouseArea is
    // active only while a popup is open — desktop clicks close any open
    // popup (house rule) without ever blocking normal use.
    Variants {
        model: Quickshell.screens

        delegate: Component {
            ClickCatcher {}
        }
    }

    // Ember — OpenRGB theme sync, one per shell (the sync is global).
    Ember {}

    Variants {
        model: Quickshell.screens

        delegate: Component {
            NotificationToasts {}
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Osd {}
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Launcher {}
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Bar {}
        }
    }
}