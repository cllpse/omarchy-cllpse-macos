#!/bin/bash
# Post-update repair hook
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

# See README.md (1)
say "post-update repair -> ~/.config/omarchy/hooks/post-update.d/cllpse-macos-repair.sh"
mkdir -p ~/.config/omarchy/hooks/post-update.d
ln -sfn "$HERE/hooks/post-update.d/cllpse-macos-repair.sh" \
  ~/.config/omarchy/hooks/post-update.d/cllpse-macos-repair.sh

