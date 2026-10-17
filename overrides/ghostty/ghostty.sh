#!/bin/bash
# Ghostty overrides: font family and size, and a few preferences
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

sync_fenced ~/.config/ghostty/config "$HERE/ghostty/ghostty.conf"

# The unfocused-cursor shader, where ghostty.conf's custom-shader line looks for
# it (relative to the config file). A link, so an edit here reaches the next
# Ghostty window without a re-apply.
mkdir -p ~/.config/ghostty/shaders
ln -sfn "$HERE/ghostty/unfocused-cursor.glsl" ~/.config/ghostty/shaders/cllpse-unfocused-cursor.glsl
