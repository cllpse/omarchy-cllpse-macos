#!/bin/bash
# ytm-player: Textual palette baked per theme-set
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

# See README.md (1)
if command -v ytm >/dev/null 2>&1; then
  say "ytm-player -> ~/.config/omarchy/themed/ + theme-set.d/ytm-player.sh"
  mkdir -p ~/.config/omarchy/themed ~/.config/omarchy/hooks/theme-set.d ~/.config/ytm-player
  ln -sfn "$HERE/themed/ytm-player.toml.tpl" ~/.config/omarchy/themed/ytm-player.toml.tpl
  ln -sfn "$HERE/hooks/theme-set.d/ytm-player.sh" ~/.config/omarchy/hooks/theme-set.d/ytm-player.sh
  backup ~/.config/ytm-player/config.toml
  "$HERE/hooks/theme-set.d/ytm-player.sh" || skip "ytm-player hook produced nothing this run — step 8's theme-set renders it"

# See README.md (2)
  "$HERE/ytm/config-prefs.py" || skip "ytm config-prefs.py failed — left ~/.config/ytm-player/config.toml alone"

# See README.md (3)
  say "ytm sign-in -> ~/.local/bin/cllpse-ytm-signin"
  mkdir -p ~/.local/bin
  ln -sfn "$HERE/ytm/cllpse-ytm-signin" ~/.local/bin/cllpse-ytm-signin

# See README.md (4)
  python3 -c 'import secretstorage' 2>/dev/null ||
    skip "python-secretstorage missing — ytm cannot read the Chromium keyring (sudo pacman -S python-secretstorage)"
  if [[ -s ~/.config/ytm-player/auth.json ]]; then
    skip "ytm-player is signed in"
  else
    skip "ytm-player is NOT signed in — run: cllpse-ytm-signin"
  fi
else
  skip "ytm-player not installed — skipped its theme template and hook (yay -S ytm-player)"
fi
