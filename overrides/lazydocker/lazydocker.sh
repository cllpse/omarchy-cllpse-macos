#!/bin/bash
# lazydocker: ANSI gocui theme
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

# lazydocker. Same four gocui theme keys, and the same ANSI vocabulary, as
# lazygit above.
if command -v lazydocker >/dev/null 2>&1; then
  say "lazydocker -> ~/.config/lazydocker/config.yml (ANSI theme)"
  mkdir -p ~/.config/lazydocker
  backup ~/.config/lazydocker/config.yml
  cp "$HERE/lazydocker/config.yml" ~/.config/lazydocker/config.yml
else
  skip "lazydocker not installed — skipped ~/.config/lazydocker/config.yml"
fi
