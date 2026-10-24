#!/bin/bash
# fontconfig drop-ins: UI font, SF autohint
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

say "Installing the fontconfig drop-ins -> ~/.config/fontconfig/conf.d/"
mkdir -p ~/.config/fontconfig/conf.d
rm -f ~/.config/fontconfig/conf.d/99-sf-pro.conf     # legacy name
# Hinting is the system's hintslight (/etc/fonts/conf.d/10-hinting-slight.conf).
# These two forced hintnone until 2026-10-12; removed so a machine that has
# either goes back to the system's.
rm -f ~/.config/fontconfig/conf.d/11-cllpse-macos-hinting.conf ~/.config/fontconfig/conf.d/11-hinting-none.conf
cp "$HERE/fontconfig/conf.d/99-cllpse-macos-ui-font.conf" ~/.config/fontconfig/conf.d/99-cllpse-macos-ui-font.conf
# SF carries no hints, so slight only acts on it through the autohinter.
cp "$HERE/fontconfig/conf.d/99-cllpse-macos-autohint.conf" ~/.config/fontconfig/conf.d/99-cllpse-macos-autohint.conf
fc-cache -f >/dev/null 2>&1
# fontconfig skips a drop-in it cannot parse and says so only on stderr, so
# check the result rather than the copy. Not `| grep -q`: under pipefail its
# early exit fails the pipeline.
[[ $(fc-match -v 'SFProText Nerd Font Propo' 2>/dev/null) == *'autohint: True'* ]] ||
  skip "SF is not autohinted: a drop-in did not parse? fc-match -v 'SFProText Nerd Font Propo' 2>&1 | grep -i error"
