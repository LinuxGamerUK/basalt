#!/usr/bin/env bash
# usage: hyprland-theme.sh [palette.json]
# Applies the live palette to Hyprland's window borders via the request
# socket's eval + hl.config (lua mode rejects `hyprctl keyword` entirely;
# eval works and takes the gradient's colors array form).
#
# Monitor/hostname independent, purely local. No network.
set -euo pipefail

palette="${1:-$HOME/.config/basalt/themes/palette.json}"
[ -f "$palette" ] || exit 0

python3 - "$palette" <<'PYEOF'
import json, os, socket, sys

p = json.load(open(sys.argv[1]))
sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
if not sig:
    sys.exit(0)

def hexn(v, alpha):
    # Hyprland's RAW gradient form needs 8-digit ARGB (alpha first) —
    # 6-digit values parse as invalid and the borders vanish.
    v = (v or "").strip().lstrip("#")
    return ("0x" + alpha + v) if v else ""

primary = hexn(p.get("primary"), "ee")
secondary = hexn(p.get("secondary"), "ee")
outline = hexn(p.get("outline_variant"), "aa")
if not primary:
    sys.exit(0)

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(f"/run/user/1000/hypr/{sig}/.socket.sock")
lua = (
    "hl.config({ general = { col = { "
    f"active_border = {{ colors = {{ '{primary}', '{secondary}' }}, angle = 45 }}, "
    f"inactive_border = {{ colors = {{ '{outline}' }} }} "
    "} } })"
)
s.sendall(("eval " + lua + "\n").encode())
try:
    s.recv(4096)
except Exception:
    pass
s.close()
PYEOF