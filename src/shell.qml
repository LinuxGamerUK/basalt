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

    // Gabbro IPC — `qs ipc call gabbro toggle` (works only when the
    // basalt module has the file manager enabled: the window's backend
    // binary resolves `gabbro` from PATH).
    IpcHandler {
        target: "gabbro"

        function toggle() {
            const focused = Hyprland.focusedMonitor
                ? Hyprland.focusedMonitor.name : "";
            if (focused !== "") {
                GabbroState.toggleOnScreen(focused);
            }
        }

        function dbg(): string {
            return GabbroState.diag.length > 0 ? GabbroState.diag : "(no notes yet)";
        }

        function open(path: string): void {
            const focused = Hyprland.focusedMonitor
                ? Hyprland.focusedMonitor.name : "";
            if (focused !== "") {
                GabbroState.pendingPath = path;
                GabbroState.screen = focused;
                GabbroState.bumpSeq();
            }
        }

        function view(mode: string): void {
            const focused = Hyprland.focusedMonitor
                ? Hyprland.focusedMonitor.name : "";
            if (focused !== "") {
                GabbroState.pendingView = mode;
                GabbroState.screen = focused;
                GabbroState.bumpSeq();
            }
        }
    }

    // Gabbro window (the file manager) — one per screen (house per-screen rule), created
    // hidden; the backend process spawns on first open and drains on
    // last close. Visibility is shared state via GabbroState.
    Variants {
        model: Quickshell.screens

        delegate: Component {
            GabbroWindow {}
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