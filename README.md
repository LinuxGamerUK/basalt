# Basalt

**A Material 3 desktop environment for NixOS.**

Dark, dense, and declarative — a QuickShell-based shell (top bar, panels,
launcher) built natively for Hyprland and home-manager, where every pixel is
an expression in your configuration and every change is a rollback.

---

## Why "Basalt"

Basalt is the stone of foundations: dark, dense, and formed under pressure.
It is the most common rock in the Earth's crust for the same reason it has
carried everything from Roman roads to brutalist architecture — it asks for
nothing, it is indifferent to fashion, and it holds up whatever you build on
it.

That is the entire design brief. A desktop should be a foundation: calm,
heavy with function, and honest about what it is. No noise. No phone-home.
Just rock.

## The charter

Basalt has a short, non-negotiable list of rules:

- **Zero telemetry.** Nothing phones home — ever. No usage stats, no update
  checks, no crash reporting, no anonymous identifiers. The shell makes
  **no network requests at all**. Optional network features (none yet)
  would be off by default, documented here, and never geo-locating.
- **No remote execution.** Basalt never downloads or executes code. Updates
  arrive through your flake lock, pinned by you, and are rollback-able like
  everything else in NixOS.
- **Declarative everything.** The QML ships from your Nix store. Your
  configuration is a rebuild, not a stateful mutation.
- **Minimal.** No bundled compositor config, no terminal opinions, no
  display-manager theming you didn't ask for.

## Features

- **Floating Material 3 top bar** — one identical bar per screen, 2px
  floating pad, resolution-aware
- **Static workspace layout** — 1–5 on your primary screen, 6–10 on any
  external monitor, enforced by the shell (pills materialize where they
  belong and self-heal if a workspace drifts); clickable, with a secondary
  accent ring for workspaces that have windows
- **Active window title** with a 25-character cap
- **Center-locked date·time clock** with a Material calendar dropdown
- **System tray**
- **Wallpaper picker** — folder selector + thumbnail grid; picking a
  wallpaper sets it through hyprpaper, persists it across reboots, and
  re-themes the entire desktop from its accent colors, live
- **System-wide live theming** — one wallpaper drives one Material You
  palette into the shell, ghostty (hot-reloaded config), fish (per-prompt
  palette), starship (a Powerline prompt with the palette injected), and
  fastfetch — all updated the moment you pick, no restarts
- **Powerline prompt theme** — starship ships a catppuccin-powerline-style
  preset (os → user@host → directory → git → languages → time) with the
  live palette; fish autosuggestions render as ghost text
- **House interaction rules** — clicking anywhere outside an open popup
  closes it; popups open only on the screen whose button was clicked, with
  shared state across screens
- **Material You theming** — the palette is generated *locally* by
  [matugen](https://github.com/InioX/matugen) from your wallpaper (or any
  source color), with a hand-tuned dark palette as the fallback
- **JetBrains Mono Nerd Font Propo** typography by default

## Requirements

- **NixOS** with flakes — Basalt is built first and foremost for NixOS and
  is primarily tested on `nixos-unstable`
- **[Hyprland](https://hyprland.org)** — the compositor Basalt is built
  against
- **[home-manager](https://github.com/nix-community/home-manager)** (flake)
- **quickshell ≥ 0.3.1** — the flake pins an nixpkgs rev that carries it
  (0.3.0 lacks the Hyprland IPC API Basalt is built on)
- **[matugen](https://github.com/InioX/matugen)** — in nixpkgs; generates
  the Material You palette locally
- **[hyprpaper](https://github.com/hyprwm/hyprpaper)** — in nixpkgs; the
  wallpaper engine the picker drives (the module ships a systemd user
  service for it)

## Installation

Add Basalt as a flake input:

```nix
inputs.basalt.url = "github:LinuxGamerUK/basalt";
```

Wire the home-manager module into your NixOS configuration:

```nix
# in the module list of your nixosConfigurations host:
home-manager.sharedModules = [ inputs.basalt.homeManagerModules.default ];
```

Enable it in your home-manager configuration:

```nix
programs.basalt.enable = true;

# Optional — systemd user target the shell binds to.
# Default: "graphical-session.target". If you start Hyprland from a tty
# (so graphical-session is never reached), use:
programs.basalt.systemdTarget = "default.target";
```

Then rebuild (`nixos-rebuild switch --flake .#your-host`). The shell runs
as a `systemd --user` service; the unit has its start limit disabled, so it
retries through the pre-compositor window at login and converges the moment
your session is up.

## Theming

Everything lives in one file, `~/.config/basalt/settings.json`:

```json
{ "sourceColor": "#4fd8e0" }
```

Or pick a wallpaper directly from the bar's wallpaper button — the palette
is regenerated from the image and applied everywhere on the fly:

```json
{ "wallpaper": "/home/you/Pictures/wallpaper.jpg" }
```

matugen runs locally; nothing leaves your machine. The accent is extracted
from the wallpaper's most saturated color (`--prefer saturation`), so each
wallpaper carries its own theme. You can also pin the screen that carries
workspaces 1–5:

```json
{ "primaryScreen": "eDP-1" }
```

### What gets themed

The same palette fans out to every themed surface through matugen's
template engine (`src/theme/broadcast.toml`):

| Surface | Mechanism | Latency |
|---|---|---|
| Basalt shell | palette applied in-process | instant |
| ghostty | `~/.config/ghostty/config` rewritten (settings + colors inline); ghostty hot-applies file changes | instant |
| fish | `~/.config/basalt/themes/palette.fish` sourced before every prompt | next prompt |
| starship | `~/.config/basalt/themes/starship.toml` re-read every prompt (`STARSHIP_CONFIG` pinned in the fish init) | next prompt |
| fastfetch | palette include re-read every invocation | next run |

The generated files live under `~/.config/basalt/themes/` (mutable — the
broadcast owns them; Nix-store-backed configs cannot be written). The
starship prompt config is the catppuccin-powerline structure with every
color mapped to Material roles, and fish colors are set through
fish's own color variables.

## Resolution scaling

The bar spans its screen automatically (anchored edge to edge); its height,
chips, fonts, and popups derive from a single scale factor so the shell
expands and contracts on different resolutions or DPIs:

```json
{ "uiScale": 1.25 }
```

Defaults to `1.0`. Width is always anchored to the screen; `uiScale` scales
everything else (bar height, chip sizes, font size, popup dimensions), and
re-applies live on change.

## Notes for Hyprland lua-config users

If your Hyprland is configured through `hyprland.lua` (lua mode), a few
things behave differently than stock Hyprland — these bit us, so they are
documented:

- String dispatches through the IPC socket are wrapped unquoted into
  `hl.dispatch(...)` and fail to parse. Use raw `hl.dsp.*` expressions,
  e.g. `hyprctl dispatch 'hl.dsp.exit()'`.
- `persistent = true` on `hl.workspace_rule` does not currently hold:
  empty workspaces are reaped. Basalt's static layout renders missing
  workspaces identically and materializes them on click, so the bar stays
  correct regardless.
- The Hyprland request socket accepts **one request per connection**.
- Move a window and its destination workspace **atomically**
  (`window.move` with the workspace following, then pin the workspace
  home). Moving the window while its workspace is separately in flight
  desyncs the window's monitor binding — the window renders in one place
  and interacts in another.

## Quickshell gotchas (for widget authors)

Bitten and learned the hard way — they are baked into Basalt's code:

- `Variants` delegates must be `delegate: Component { YourType {} }` with
  the component declaring `property var modelData` itself. Redeclaring
  `required property var modelData` **inline on the delegate** shadows the
  class property and silently breaks the injection — it has bitten this
  project three separate times.
- Each QML file imports its own modules; a root-level `import` does not
  cascade to widgets in subdirectories.
- `RowLayout` sizes children from implicit sizes — explicit width/height
  is stomped to 0.
- A layer-shell surface **always consumes pointer input** over its whole
  region (a disabled MouseArea changes nothing). A click-catcher must map
  only while it is needed, on the top layer.
- `Hyprland.workspaces` / workspace `toplevels` are ObjectModels — iterate
  `.values`, never `.length`/`.count`.

## Roadmap

- Notifications + OSD (volume/brightness)
- Launcher
- Lock screen, media popup, settings UI

## Version history

- **v0.2.0 — 2026-09-06** (this tag): wallpaper picker + system-wide live
  theming (shell, ghostty hot-reload, fish, starship powerline,
  fastfetch), house interaction rules (click-outside closes popups,
  per-screen popups), workspace on-click + has-windows ring, resolution
  scaling, atomic workspace moves
- **v0.1.0 — 2026-09-06**: Material top bar — per-screen workspaces,
  window title, clock + calendar, tray

## License

[MIT](LICENSE) — copy it, fork it, ship it, learn from it.