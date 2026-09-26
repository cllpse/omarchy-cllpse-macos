#!/bin/bash
# App icons for the menu
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

# See README.md
mkdir -p ~/.config/omarchy/hooks/theme-set.d
ln -sfn "$HERE/hooks/theme-set.d/app-icons.sh" ~/.config/omarchy/hooks/theme-set.d/app-icons.sh
if [[ -d "$HERE/icons/icons" ]]; then
  _n=$(find "$HERE/icons/icons" -maxdepth 1 \( -name '*.svg' -o -name '*.png' \) | wc -l)
  # Counted, not written down: the verbatim half grows, and a hardcoded figure
  # here would be a second place to remember.
  _c=$(find "$HERE/icons/verbatim" -maxdepth 1 -name '*.svg' 2>/dev/null | wc -l)
  say "app icons -> ~/.icons/cllpse-flat/apps/ ($_n hand-placed) + ~/.icons/cllpse-color/apps/ ($_c verbatim)"
else
  _n=0
  skip "no icons/icons/ — the repainted half has nothing to sync"
fi
"$HERE/hooks/theme-set.d/app-icons.sh" || skip "app-icons.sh produced nothing this run"
# An `if`, not `(( … )) && skip`. As the LAST command in this script that idiom
# leaks its own false test as the script's exit status, and apply.sh runs under
# `set -e` -- so a perfectly normal run with icons present aborted the whole
# apply at this step. It was harmless while 20 more steps followed it.
if (( _n == 0 )); then
  skip "icons/icons/ is empty — every app keeps its vendor icon"
fi

