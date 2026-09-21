#!/bin/bash
# fontconfig drop-ins: UI font + hintnone
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

say "Installing fontconfig drop-ins -> ~/.config/fontconfig/conf.d/"
mkdir -p ~/.config/fontconfig/conf.d
rm -f ~/.config/fontconfig/conf.d/99-sf-pro.conf     # legacy name
rm -f ~/.config/fontconfig/conf.d/11-hinting-none.conf   # interim name
cp "$HERE/fontconfig/conf.d/99-cllpse-macos-ui-font.conf" ~/.config/fontconfig/conf.d/99-cllpse-macos-ui-font.conf
cp "$HERE/fontconfig/conf.d/11-cllpse-macos-hinting.conf" ~/.config/fontconfig/conf.d/11-cllpse-macos-hinting.conf
fc-cache -f >/dev/null 2>&1
