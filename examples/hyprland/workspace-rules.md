# Basalt — optional Hyprland workspace rules

Basalt's workspace bar expects the layout **1–5 on your primary screen,
6–10 on the external**. Hyprland creates workspaces on whichever monitor
is focused when they're opened, so without rules they drift — the bar
self-heals that at runtime, but you can make the deterministic and skip
the dance entirely by declaring persistent workspace rules.

Copy the block for your config dialect into your Hyprland config and
reload (`hyprctl reload` for Lua mode). Adapt the output names to yours —
`hyprctl monitors` lists them.

## Lua config (Hyprland 0.53+ with Lua config, e.g. Quattro-style)

```lua
-- Primary (internal panel): workspaces 1-5, default = 1
for i = 1, 5 do
  hl.workspace_rule({
    workspace  = tostring(i),
    monitor    = "eDP-1",
    default    = i == 1,
    persistent = true,
  })
end

-- External: workspaces 6-10, whatever port it's plugged into
for _, output in ipairs({ "DP-1", "DP-3", "DP-2", "DP-4" }) do
  for i = 6, 10 do
    hl.workspace_rule({
      workspace  = tostring(i),
      monitor    = output,
      default    = i == 6,
      persistent = true,
    })
  end
end
```

## Classic `hyprland.conf`

```ini
workspace = 1,  monitor:eDP-1, default:true,  persistent:true
workspace = 2,  monitor:eDP-1, persistent:true
workspace = 3,  monitor:eDP-1, persistent:true
workspace = 4,  monitor:eDP-1, persistent:true
workspace = 5,  monitor:eDP-1, persistent:true

# External (include every port you might use)
workspace = 6,  monitor:DP-1, default:true,  persistent:true
workspace = 7,  monitor:DP-1, persistent:true
workspace = 8,  monitor:DP-1, persistent:true
workspace = 9,  monitor:DP-1, persistent:true
workspace = 10, monitor:DP-1, persistent:true
workspace = 6,  monitor:DP-3, default:true,  persistent:true
workspace = 7,  monitor:DP-3, persistent:true
workspace = 8,  monitor:DP-3, persistent:true
workspace = 9,  monitor:DP-3, persistent:true
workspace = 10, monitor:DP-3, persistent:true
```

## Notes

- **Lua-mode trap:** legacy `hyprctl dispatch movetoworkspace N` is dead
  under the Lua config ("')' expected"). Use
  `hyprctl dispatch 'hl.dsp.window.move({ workspace = "6" })'` — and
  remember it silently no-ops when no window is focused.
- Rules with `persistent = true` re-home an already-created workspace
  when they load — you do not need to log out.
- `default = true` is what the workspace-switch keys use on an idle
  monitor; more than one workspace can be the default for its monitor.
- Fully verified on NixOS laptops with Hyprland 0.55–0.56 (home.nix
  layout: external at 2560x0, scale 1.0, DP-1 ↔ eDP-1).
