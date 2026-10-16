#!/bin/bash
# T3 Code: all 57 colours from the theme, none left to its generator
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads the same as in the other steps.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

# See README.md
if command -v t3code >/dev/null 2>&1; then
  say "T3 Code -> ~/.config/omarchy/themed/t3code.json.tpl (every colour from the theme)"
  mkdir -p ~/.config/omarchy/themed
  ln -sfn "$HERE/themed/t3code.json.tpl" ~/.config/omarchy/themed/t3code.json.tpl
  # Ours is every line of Omarchy's template plus the 32 tokens it leaves out,
  # and it shadows Omarchy's whole: a line Omarchy adds or changes later would
  # never reach T3 Code. Blank lines are dropped on both sides, since an empty
  # pattern in -f matches every line.
  _stock="${OMARCHY_PATH:-/usr/share/omarchy}/default/themed/t3code.json.tpl"
  if [[ -f $_stock ]] &&
     grep -v '^$' "$_stock" | grep -qvxF -f <(grep -v '^$' "$HERE/themed/t3code.json.tpl"); then
    skip "Omarchy's t3code.json.tpl has lines ours lacks — merge them in (t3code/README.md)"
  fi
  skip "renders at the next theme set: step 8 in a full run, else omarchy-theme-refresh"
else
  skip "T3 Code not installed — skipped its template (Omarchy menu: Install > AI > T3 Code)"
fi
