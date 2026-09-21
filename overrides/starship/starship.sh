#!/bin/bash
# starship: colours baked per theme-set
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

# See README.md (1)
say "starship -> ~/.config/omarchy/hooks/theme-set.d/starship-colors.sh"
mkdir -p ~/.config/omarchy/hooks/theme-set.d
ln -sfn "$HERE/hooks/theme-set.d/starship-colors.sh" ~/.config/omarchy/hooks/theme-set.d/starship-colors.sh
backup ~/.config/starship.toml
"$HERE/hooks/theme-set.d/starship-colors.sh" || skip "starship-colors.sh produced nothing this run — left ~/.config/starship.toml untouched"
