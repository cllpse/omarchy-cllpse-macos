#!/bin/bash
# SF + Comic Code font installation
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

say "Installing SF fonts -> ~/.local/share/fonts/SF/"
mkdir -p ~/.local/share/fonts/SF
cp -u "$HERE"/fonts/*.otf ~/.local/share/fonts/SF/

# See README.md
say "Installing Comic Code -> ~/.local/share/fonts/ComicCode/"
mkdir -p ~/.local/share/fonts/ComicCode
cp -u "$HERE"/fonts/comic-code/*.otf ~/.local/share/fonts/ComicCode/
