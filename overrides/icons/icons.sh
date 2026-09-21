#!/bin/bash
# Flat app icons for the menu
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

# See README.md (1)
mkdir -p ~/.config/omarchy/hooks/theme-set.d
ln -sfn "$HERE/hooks/theme-set.d/app-icons.sh" ~/.config/omarchy/hooks/theme-set.d/app-icons.sh
if [[ -d "$HERE/icons/fallbacks" ]]; then
  _n=$(find "$HERE/icons/fallbacks" -maxdepth 1 \( -name '*.svg' -o -name '*.png' \) | wc -l)
  say "app icons -> ~/.icons/cllpse-flat/apps/ ($_n hand-placed) + ~/.icons/cllpse-color/apps/ (from the switcher submodule)"
else
  _n=0
  skip "no icons/fallbacks/ — the repainted half has nothing to sync"
fi
"$HERE/hooks/theme-set.d/app-icons.sh" || skip "app-icons.sh produced nothing this run"
(( _n == 0 )) && skip "icons/fallbacks/ is empty — every app keeps its vendor icon"

