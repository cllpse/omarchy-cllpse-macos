#!/bin/bash
# keyd: identity config + Figma modifier remap (sudo)
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

# See README.md (1)
if command -v keyd >/dev/null 2>&1; then
  say "keyd -> ~/.local/bin/cllpse-figma-keyd + /etc/keyd/default.conf (sudo)"
  mkdir -p ~/.local/bin
  install -m755 "$HERE/keyd/cllpse-figma-keyd" ~/.local/bin/cllpse-figma-keyd

# See README.md (2)
  if [[ -e /etc/keyd/default.conf ]] && ! head -1 /etc/keyd/default.conf | grep -q 'installed by overrides/apply.sh'; then
    skip "/etc/keyd/default.conf exists and is not ours — left alone"
    skip "  merge overrides/keyd/default.conf by hand, or move yours aside and re-run"
  elif ! keyd check "$HERE/keyd/default.conf" >/dev/null 2>&1; then
# See README.md (3)
    skip "overrides/keyd/default.conf does not parse — left /etc alone. Run:"
    skip "  keyd check overrides/keyd/default.conf"
  else
    sudo install -Dm644 "$HERE/keyd/default.conf" /etc/keyd/default.conf
    sudo systemctl enable --now keyd >/dev/null 2>&1 \
      && skip "keyd service enabled and started" \
      || skip "could not enable keyd — start it yourself: sudo systemctl enable --now keyd"

# See README.md (4)
    keyd reload >/dev/null 2>&1 || sudo systemctl restart keyd >/dev/null 2>&1 || true
  fi

# See README.md (5)
  if id -nG | tr ' ' '\n' | grep -qx keyd; then
    skip "already in the keyd group"
  else
    sudo usermod -aG keyd "$USER" \
      && skip "added $USER to the keyd group — this session reaches it via newgrp" \
      || skip "could not add $USER to the keyd group — run: sudo usermod -aG keyd $USER"
  fi

# See README.md (6)
  if [[ -x ~/.local/bin/cllpse-figma-keyd ]] && command -v keyd >/dev/null 2>&1; then
    if ~/.local/bin/cllpse-figma-keyd on >/dev/null 2>&1; then
      ~/.local/bin/cllpse-figma-keyd off >/dev/null 2>&1 || true
      skip "Figma remap reaches keyd (layer bound and released)"
    else
      skip "the Figma remap could NOT be bound — run it by hand to see why:"
      skip "  ~/.local/bin/cllpse-figma-keyd on"
    fi
  fi
else
  skip "keyd not installed — Figma keeps Ctrl+click / Ctrl+scroll on the pinky"
  skip "  install it with: sudo pacman -S keyd, then re-run this script"
fi
