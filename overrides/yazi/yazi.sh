#!/bin/bash
# yazi: ANSI theme + syntect previewer hook
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

# See README.md (1)
if command -v yazi >/dev/null 2>&1; then
  say "yazi -> ~/.config/yazi/theme.toml (ANSI theme)"
  mkdir -p ~/.config/yazi
  backup ~/.config/yazi/theme.toml
  cp "$HERE/yazi/theme.toml" ~/.config/yazi/theme.toml
else
  skip "yazi not installed — skipped ~/.config/yazi/theme.toml"
fi

# See README.md (2)
if command -v yazi >/dev/null 2>&1; then
  say "yazi previewer -> ~/.config/omarchy/hooks/theme-set.d/yazi-syntax.sh"
  mkdir -p ~/.config/omarchy/hooks/theme-set.d ~/.config/yazi
  ln -sfn "$HERE/hooks/theme-set.d/yazi-syntax.sh" ~/.config/omarchy/hooks/theme-set.d/yazi-syntax.sh
  "$HERE/hooks/theme-set.d/yazi-syntax.sh" || skip "yazi-syntax.sh produced nothing this run — left the .tmTheme untouched"
fi
