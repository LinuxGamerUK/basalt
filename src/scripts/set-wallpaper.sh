#!/usr/bin/env bash
# usage: set-wallpaper.sh <image-path> [previous-image-path]
# Applies a wallpaper through hyprpaper (Hyprland's native wallpaper
# daemon), spawning the daemon first if it is not running. Everything is
# local — this is the only thing Basalt does with wallpapers.
set -euo pipefail

img="${1:?image path required}"
prev="${2:-}"

if ! pgrep -x hyprpaper >/dev/null 2>&1; then
    hyprpaper >/dev/null 2>&1 &
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        pgrep -x hyprpaper >/dev/null 2>&1 && break
        sleep 0.2
    done
fi

hyprctl hyprpaper preload "$img" >/dev/null
hyprctl hyprpaper wallpaper ",$img" >/dev/null
if [ -n "$prev" ] && [ "$prev" != "$img" ]; then
    hyprctl hyprpaper unload "$prev" >/dev/null 2>&1 || true
fi