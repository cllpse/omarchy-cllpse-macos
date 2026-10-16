#!/bin/bash
# TorrentTUI: download folder + ANSI theme
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads the same as in the other steps.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

# See README.md
if command -v torrenttui >/dev/null 2>&1; then
  say "TorrentTUI -> ~/.config/torrenttui/config.toml (downloads to ~/Downloads, ANSI theme)"
  mkdir -p ~/.config/torrenttui; backup ~/.config/torrenttui/config.toml
  cp "$HERE/torrenttui/config.toml" ~/.config/torrenttui/config.toml
else
  skip "TorrentTUI not installed — skipped its config (it is a release binary: torrenttui/README.md)"
fi
