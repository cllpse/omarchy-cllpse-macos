#!/bin/bash
# lsd: config + colours
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

if command -v lsd >/dev/null 2>&1; then
  say "lsd -> ~/.config/lsd/{config,colors}.yaml (ANSI theme)"
  mkdir -p ~/.config/lsd
  backup ~/.config/lsd/config.yaml; backup ~/.config/lsd/colors.yaml
  cp "$HERE/lsd/config.yaml"  ~/.config/lsd/config.yaml
  cp "$HERE/lsd/colors.yaml"  ~/.config/lsd/colors.yaml
else
  skip "lsd not installed — skipped ~/.config/lsd theme files"
fi
