#!/usr/bin/env bash
# usage: set-wallpaper.sh <image-path> [previous-image-path]
# Applies a wallpaper through hyprpaper (Hyprland's native wallpaper
# daemon), spawning the daemon first if it is not running. Everything is
# local — this is the only thing Basalt does with wallpapers.
#
# NOTE: hyprpaper >= 0.8 dropped the old `preload` hyprctl command — the
# wallpaper command loads the image directly from the path. Do NOT
# reintroduce preload.
#
# Monitor names are resolved dynamically from `hyprctl monitors -j` —
# never hardcode output names (eDP-1/DP-1 are machine-specific).
set -euo pipefail

img="${1:?image path required}"
prev="${2:-}"

# Guard: the path must exist (the new protocol validates it at apply).
if [ ! -f "$img" ]; then
    echo "set-wallpaper: image not found: $img" >&2
    exit 1
fi

if ! pgrep -x hyprpaper >/dev/null 2>&1; then
    hyprpaper >/dev/null 2>&1 &
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        pgrep -x hyprpaper >/dev/null 2>&1 && break
        sleep 0.2
    done
fi

# Apply to every monitor currently present — dynamic, machine-agnostic.
monitors="$(hyprctl monitors -j 2>/dev/null | python3 -c 'import json,sys; print("\n".join(m["name"] for m in json.load(sys.stdin)))')"
if [ -z "$monitors" ]; then
    # Fallback: the comma-global form applies to all monitors.
    hyprctl hyprpaper wallpaper ",$img" >/dev/null 2>&1 || true
else
    while IFS= read -r mon; do
        hyprctl hyprpaper wallpaper "$mon,$img" >/dev/null 2>&1 || true
    done <<EOF
$monitors
EOF
fi

if [ -n "$prev" ] && [ "$prev" != "$img" ]; then
    hyprctl hyprpaper unload "$prev" >/dev/null 2>&1 || true
fi