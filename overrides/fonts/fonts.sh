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

# --remove-destination: a changed face replaces the installed file rather than
# rewriting it in place. Running apps have the old one memory-mapped, and
# rewriting it under them crashes them: Ghostty died inside FreeType's
# autohinter the moment the rebuilt SF Pro landed on 2026-10-24. Unlinked, the
# old file lives on for them until they restart.
say "Installing SF fonts -> ~/.local/share/fonts/SF/"
mkdir -p ~/.local/share/fonts/SF
cp -u --remove-destination "$HERE"/fonts/*.otf ~/.local/share/fonts/SF/

# See README.md
say "Installing Comic Code -> ~/.local/share/fonts/ComicCode/"
mkdir -p ~/.local/share/fonts/ComicCode
cp -u --remove-destination "$HERE"/fonts/comic-code/*.otf ~/.local/share/fonts/ComicCode/
