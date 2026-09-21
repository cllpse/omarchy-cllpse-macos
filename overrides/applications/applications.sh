#!/bin/bash
# Figma Desktop launcher entry
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

# See README.md (1)
_figma_dir=~/Applications/figma-desktop
_figma_entry=~/.local/share/applications/figma-desktop-appimage.desktop
_figma_tpl="$HERE/applications/figma-desktop-appimage.desktop.tpl"
if [[ -f $_figma_tpl ]]; then
  if [[ ! -d $_figma_dir ]]; then
    skip "Figma Desktop not installed at $_figma_dir — entry left alone"
  else
    # Un-wrap, if a wrapper is in the way. `integrate_desktop` is the marker:
    # it is in the app's launcher and in nothing else here.
    if [[ -f $_figma_dir/AppRun.real ]] &&
       grep -q 'integrate_desktop' "$_figma_dir/AppRun.real" 2>/dev/null &&
       ! grep -q 'integrate_desktop' "$_figma_dir/AppRun" 2>/dev/null; then
      say "removing the AppRun wrapper — the app's own launcher already resolves to a stable path"
      mv -f "$_figma_dir/AppRun.real" "$_figma_dir/AppRun"
      chmod +x "$_figma_dir/AppRun"
      skip "FIGMA_USE_WAYLAND comes from environment.d (step 7c) instead"
    elif [[ -f $_figma_dir/AppRun.real ]] &&
         grep -q 'integrate_desktop' "$_figma_dir/AppRun" 2>/dev/null; then
      # A fresh extraction restored the real AppRun and left our rename behind.
      rm -f "$_figma_dir/AppRun.real"
      skip "removed a stale AppRun.real left by an earlier wrapper"
    elif [[ -e $_figma_dir/AppRun ]] &&
         ! grep -q 'integrate_desktop' "$_figma_dir/AppRun" 2>/dev/null; then
# See README.md (2)
      skip "WARNING: $_figma_dir/AppRun is not the app's own launcher and there is"
      skip "  no AppRun.real to restore — re-extract the AppImage over that directory"
    fi

    if [[ ! -x $_figma_dir/AppRun ]]; then
      skip "WARNING: $_figma_dir/AppRun is missing or not executable — entry left alone"
    else
      _figma_rendered=$(sed "s|{{ home }}|$HOME|g" "$_figma_tpl")
      if [[ -f $_figma_entry ]] && [[ $(cat "$_figma_entry") == "$_figma_rendered" ]]; then
        skip "figma-desktop-appimage.desktop already current"
      else
        say "Figma Desktop entry -> $_figma_entry"
        mkdir -p ~/.local/share/applications
        backup "$_figma_entry"
        printf '%s\n' "$_figma_rendered" > "$_figma_entry"
        update-desktop-database ~/.local/share/applications 2>/dev/null || true
        skip "Name=Figma Desktop, StartupWMClass=figma-desktop (the app gets both wrong)"
      fi
    fi
  fi
fi

