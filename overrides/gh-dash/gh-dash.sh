#!/bin/bash
# gh-dash: theme baked per theme-set
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

# See README.md
_ghdash_dir="${XDG_DATA_HOME:-$HOME/.local/share}/gh/extensions/gh-dash"
if [[ -d $_ghdash_dir ]]; then
  say "gh-dash -> ~/.config/omarchy/hooks/theme-set.d/gh-dash-colors.sh"
  mkdir -p ~/.config/omarchy/hooks/theme-set.d
  ln -sfn "$HERE/hooks/theme-set.d/gh-dash-colors.sh" ~/.config/omarchy/hooks/theme-set.d/gh-dash-colors.sh
  backup "${XDG_CONFIG_HOME:-$HOME/.config}/gh-dash/config.yml"
  "$HERE/hooks/theme-set.d/gh-dash-colors.sh" || skip "gh-dash-colors.sh produced nothing this run — left config.yml untouched"
else
  skip "gh-dash not installed — skipped its theme hook"
fi
