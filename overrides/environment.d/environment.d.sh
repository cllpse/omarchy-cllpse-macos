#!/bin/bash
# session environment drop-ins
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

# See README.md
for _stale in 10-cllpse-macos-font-rendering.conf; do
  if [[ -e ~/.config/environment.d/$_stale ]]; then
    rm -f ~/.config/environment.d/"$_stale"
    skip "removed retired drop-in $_stale  (takes effect on next login)"
  fi
done

if [[ -d "$HERE/environment.d" ]]; then
  say "environment.d drop-ins -> ~/.config/environment.d/"
  mkdir -p ~/.config/environment.d
  for f in "$HERE"/environment.d/*.conf; do
    [[ -e $f ]] || continue
    if cmp -s "$f" ~/.config/environment.d/"$(basename "$f")"; then
      skip "$(basename "$f") already current"
    else
      cp "$f" ~/.config/environment.d/"$(basename "$f")"
      say "installed $(basename "$f")  (takes effect on next login)"
    fi
  done
fi

