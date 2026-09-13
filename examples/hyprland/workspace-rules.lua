-- Basalt: persistent workspace layout — 1-5 primary / 6-10 external.
-- Copy into your Hyprland Lua config (after your hl.monitor blocks).
-- Full explanation: examples/hyprland/workspace-rules.md

for i = 1, 5 do
  hl.workspace_rule({
    workspace  = tostring(i),
    monitor    = "eDP-1",
    default    = i == 1,
    persistent = true,
  })
end

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
