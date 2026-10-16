#!/bin/bash
# T3 Code: its primary colour from the accent, not a hue-shift of it
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads the same as in the other steps.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

# See README.md
if command -v t3code >/dev/null 2>&1; then
  say "T3 Code -> ~/.config/omarchy/themed/t3code.json.tpl (primary = the accent)"
  mkdir -p ~/.config/omarchy/themed
  ln -sfn "$HERE/themed/t3code.json.tpl" ~/.config/omarchy/themed/t3code.json.tpl
  # Ours is Omarchy's template plus three messageAction lines, and it shadows
  # Omarchy's whole: a key Omarchy adds later would never reach T3 Code.
  _stock="${OMARCHY_PATH:-/usr/share/omarchy}/default/themed/t3code.json.tpl"
  if [[ -f $_stock ]] &&
     ! diff -q <(sed '/"messageAction/d' "$HERE/themed/t3code.json.tpl") "$_stock" >/dev/null; then
    skip "Omarchy's t3code.json.tpl has changed since ours was copied from it — diff and re-copy (t3code/README.md)"
  fi
  skip "renders at the next theme set: step 8 in a full run, else omarchy-theme-refresh"
else
  skip "T3 Code not installed — skipped its template (Omarchy menu: Install > AI > T3 Code)"
fi
