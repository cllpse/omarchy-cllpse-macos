#!/bin/bash
# Chrome + Electron apps: fontconfig's hinting back
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

# Each is the file that app's own launcher reads. Chromium's flag is in
# chromium/chromium-flags.conf, Figma's in figma/figma.sh (AppRun reads none).
FLAG_FILES=(
  ~/.config/chrome-flags.conf           # Google Chrome (/usr/bin/google-chrome-stable)
  ~/.config/code-flags.conf             # VS Code (/usr/bin/code)
  ~/.config/claude-desktop-flags.conf   # Claude (/usr/bin/claude-desktop)
  ~/.config/t3code-flags.conf           # T3 Code (/usr/bin/t3code)
  ~/.config/electron-flags.conf         # system Electron: Cursor (electron42), Obsidian (electron43)
)

say "Chrome + Electron apps: --disable-font-subpixel-positioning"
for f in "${FLAG_FILES[@]}"; do
  sync_fenced "$f" "$HERE/font-flags/font-flags.conf"
done

# The Electron wrappers read electron-flags.conf only when there is no
# per-version file, so one of those would silently shadow the flag.
for e in /usr/bin/electron[0-9]*; do
  [[ -e $e ]] || continue
  n=$(basename "$e")
  if [[ -f ~/.config/$n-flags.conf ]] && ! grep -qxF -e '--disable-font-subpixel-positioning' ~/.config/"$n"-flags.conf; then
    say "~/.config/$n-flags.conf shadows electron-flags.conf: add --disable-font-subpixel-positioning to it"
  fi
done
