#!/bin/bash
# bat: ANSI theme
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

say "bat -> ~/.config/bat/config (--theme=ansi)"
mkdir -p ~/.config/bat; backup ~/.config/bat/config
cp "$HERE/bat/config" ~/.config/bat/config
