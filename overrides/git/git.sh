#!/bin/bash
# git overrides: route git diff through hunk
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

# See README.md
mkdir -p ~/.config/git
if [[ ! -e ~/.config/git/config && -r /usr/share/omarchy/config/git/config ]]; then
  say "git -> seeded ~/.config/git/config from Omarchy's stock copy"
  cp /usr/share/omarchy/config/git/config ~/.config/git/config
fi
sync_fenced ~/.config/git/config "$HERE/git/pager.conf"
