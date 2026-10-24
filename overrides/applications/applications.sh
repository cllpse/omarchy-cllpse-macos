#!/bin/bash
# Launcher entries: Figma Desktop, and T3 Code's window class
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


# See README.md (3)
# Derived from the package's own entry on every run, so a t3code-bin update to
# Exec, Name or the URL handlers comes through; only the class line differs.
_t3_pkg=/usr/share/applications/t3code.desktop
_t3_entry=~/.local/share/applications/t3code.desktop
_t3_class=com.t3tools.T3Code
if [[ ! -f $_t3_pkg ]]; then
  skip "T3 Code not installed — no entry to correct"
elif ! grep -q '^StartupWMClass=' "$_t3_pkg"; then
  skip "t3code.desktop declares no StartupWMClass any more — left alone, check applications/README.md (3)"
else
  _t3_rendered=$(sed "s|^StartupWMClass=.*|StartupWMClass=$_t3_class|" "$_t3_pkg")
  if [[ -f $_t3_entry ]] && [[ $(cat "$_t3_entry") == "$_t3_rendered" ]]; then
    skip "t3code.desktop already current"
  else
    say "T3 Code entry -> $_t3_entry (StartupWMClass=$_t3_class)"
    mkdir -p ~/.local/share/applications
    backup "$_t3_entry"
    printf '%s\n' "$_t3_rendered" > "$_t3_entry"
    update-desktop-database ~/.local/share/applications 2>/dev/null || true
  fi
  # An if, not `grep && skip`: as the script's last command a miss became its
  # exit status, and apply.sh's set -e stopped every full run here, before the
  # theme and all six sudo steps (2026-10-16 to 24).
  if grep -qx "StartupWMClass=$_t3_class" "$_t3_pkg"; then
    skip "t3code-bin now declares the right class itself — this section can go"
  fi
fi
