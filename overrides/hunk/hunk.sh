#!/bin/bash
# hunk: colours baked per theme-set
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

# See README.md
if command -v hunk >/dev/null 2>&1; then
  say "hunk -> ~/.config/omarchy/hooks/theme-set.d/hunk-colors.sh"
  mkdir -p ~/.config/omarchy/hooks/theme-set.d ~/.config/hunk
  ln -sfn "$HERE/hooks/theme-set.d/hunk-colors.sh" ~/.config/omarchy/hooks/theme-set.d/hunk-colors.sh
  backup ~/.config/hunk/config.toml
  "$HERE/hooks/theme-set.d/hunk-colors.sh" || skip "hunk-colors.sh produced nothing this run — left ~/.config/hunk/config.toml untouched"
else
  skip "hunk not installed — skipped its theme hook (mise use -g hunk)"
fi
