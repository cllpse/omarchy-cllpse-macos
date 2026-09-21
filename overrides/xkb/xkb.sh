#!/bin/bash
# xkb: Danish letters on the Preonic M0 layer
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

# See README.md (1)
say "xkb: installing us-danish-letters -> ~/.config/xkb/symbols/"
mkdir -p ~/.config/xkb/symbols
cp "$HERE/xkb/symbols/us-danish-letters" ~/.config/xkb/symbols/us-danish-letters
