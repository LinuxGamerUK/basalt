# Basalt

A Material 3 desktop shell for NixOS — Hyprland + QuickShell.

**Charter — the non-negotiables:**

| Rule | Meaning |
|---|---|
| Zero telemetry | No beacons, no IDs, no opt-out-that-still-sends. Ever. |
| Zero network | The shell makes no network calls. Optional network features (e.g. weather) are off by default, manual-location-only, and documented in this README. |
| No remote execution | Nothing here ever downloads and executes code. Updates come from your flake input — you pin the commit. |
| Fully declarative | Home-manager + NixOS modules; the QML lives in your store; every change is a rebuild and a rollback. |
| Minimal | No bundled compositor configs, no terminal/file-browser opinions, no display-manager theming unless you ask. |

Inspired by the Material shells out there; built to a stricter charter.

## Status

v0.1 — top bar (per-screen workspaces, active window, tray, centered
date·time clock with calendar dropdown) + Material You palette via
matugen: generated locally from the wallpaper (`settings.json`
`"wallpaper": "<path>"`) or a source color (`"sourceColor": "#hex"`,
default: house cyan). Static dark palette as fallback. No network, ever.

Roadmap: **wallpaper selector** (writes the palette source + re-runs
matugen) → notifications + OSD → launcher → optional extras (lock screen,
media popup, settings UI).

## Try it

```nix
# flake input
inputs.basalt.url = "github:LinuxGamerUK/basalt";  # pinned by your lock
```

```nix
# home-manager
imports = [ inputs.basalt.homeManagerModules.default ];
programs.basalt.enable = true;
```

## License

MIT
