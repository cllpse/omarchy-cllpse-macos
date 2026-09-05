#!/bin/bash
# Apply the cllpse-macos theme + every system-level override it needs.
# Idempotent, no sudo. Re-run any time. See revert.sh to undo.
#
#   1. symlink both themes + the window-switcher plugin into ~/.config/omarchy/
#   2. install the SF fonts + fontconfig drop-ins (UI font + hintnone)
#   3. point monospace at SF Mono (omarchy font set)
#   4. point GTK / GNOME apps at SF Pro / SF Mono (gsettings)
#   5. force hintnone for GTK/GNOME (gsettings) + Ghostty (freetype-load-flags)
#   6. hypr overrides: OMARCHY_MENU_FONT (shell popups) + decoration (rounding, blur)
#   7. install bat / lazygit theme configs, add fzf colours to .bashrc
#   8. apply the theme (refreshes whichever cllpse-macos theme is active; dark otherwise)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
MARK='cllpse-macos overrides'

say()  { printf '\033[34m▸\033[0m %s\n' "$*"; }
skip() { printf '  \033[2m– %s\033[0m\n' "$*"; }
backup() { [[ -s $1 && ! -e $1.pre-cllpse ]] && { cp "$1" "$1.pre-cllpse"; skip "backed up $1 -> $1.pre-cllpse"; } || true; }

# Current contents of the fenced block in $3 — the lines between, but not
# including, the $1/$2 marker lines.
# NB: the awk variables are openm/closem, not open/close — `close` is a gawk
# builtin and `-v close=...` is a fatal error, which silently emptied the target.
fenced_body() { # $1 open-marker  $2 close-marker  $3 target
  awk -v openm="$1" -v closem="$2" '$0 == openm { f = 1; next } $0 == closem { f = 0 } f' "$3"
}

# Sync a snippet into $1 wrapped in fence markers: replace the block in place if
# it's already there, append it if it isn't. Replacing (rather than the older
# append-once) is what makes a re-run pick up edits to the snippet — otherwise an
# already-applied machine silently keeps the version it first installed.
# Comment leader matches the target: "--" for *.lua, "#" otherwise — a "#" line
# is a syntax error in Lua.
sync_fenced() { # $1 target  $2 snippet-file
  local c='#'; [[ $1 == *.lua ]] && c='--'
  local open="$c >>> $MARK >>>" close="$c <<< $MARK <<<"
  [[ -e $1 ]] || : >"$1"

  if ! grep -qF "$MARK" "$1" 2>/dev/null; then
    { printf '\n%s\n' "$open"; cat "$2"; printf '%s\n' "$close"; } >>"$1"
    say "appended overrides block to $1"
    return
  fi

  if diff -q <(fenced_body "$open" "$close" "$1") "$2" >/dev/null 2>&1; then
    skip "$1 overrides block already up to date"
    return
  fi

  local tmp; tmp=$(mktemp)
  if ! awk -v openm="$open" -v closem="$close" -v snip="$2" '
    $0 == openm  { print; while ((getline line < snip) > 0) print line; close(snip); f = 1; next }
    $0 == closem { f = 0; print; next }
    !f           { print }
  ' "$1" >"$tmp"; then
    rm -f "$tmp"; printf 'error: could not rewrite %s — left untouched\n' "$1" >&2; return 1
  fi
  # Never let a failed/empty rewrite clobber a real config file.
  if [[ ! -s $tmp ]]; then
    rm -f "$tmp"; printf 'error: refusing to write empty %s — left untouched\n' "$1" >&2; return 1
  fi
  # Write through the original file rather than mv, to keep its mode and inode.
  cat "$tmp" >"$1"
  rm -f "$tmp"
  say "updated overrides block in $1"
}

# ── 1. symlinks ──────────────────────────────────────────────────────────────
say "Linking themes into ~/.config/omarchy/themes/"
mkdir -p ~/.config/omarchy/themes
ln -sfn "$REPO/omarchy-cllpse-theme/omarchy-cllpse-theme-dark"  ~/.config/omarchy/themes/omarchy-cllpse-theme-dark
ln -sfn "$REPO/omarchy-cllpse-theme/omarchy-cllpse-theme-light" ~/.config/omarchy/themes/omarchy-cllpse-theme-light

say "Linking the window-switcher plugin into ~/.config/omarchy/plugins/"
mkdir -p ~/.config/omarchy/plugins
ln -sfn "$REPO/omarchy-cllpse-switcher" ~/.config/omarchy/plugins/io.eject.window-switcher

# ── 2. fonts ─────────────────────────────────────────────────────────────────
say "Installing SF fonts -> ~/.local/share/fonts/SF/"
mkdir -p ~/.local/share/fonts/SF
cp -u "$HERE"/fonts/*.otf ~/.local/share/fonts/SF/

say "Installing fontconfig drop-ins -> ~/.config/fontconfig/conf.d/"
mkdir -p ~/.config/fontconfig/conf.d
rm -f ~/.config/fontconfig/conf.d/99-sf-pro.conf     # legacy name
rm -f ~/.config/fontconfig/conf.d/11-hinting-none.conf   # interim name
cp "$HERE/fontconfig/conf.d/99-cllpse-macos-ui-font.conf" ~/.config/fontconfig/conf.d/99-cllpse-macos-ui-font.conf
cp "$HERE/fontconfig/conf.d/11-cllpse-macos-hinting.conf" ~/.config/fontconfig/conf.d/11-cllpse-macos-hinting.conf
fc-cache -f >/dev/null 2>&1

# ── 3. monospace font (Omarchy's own mechanism) ──────────────────────────────
if [[ "$(omarchy font current 2>/dev/null)" == "SFMono Nerd Font Mono" ]]; then
  skip "omarchy font already SFMono Nerd Font Mono"
else
  say 'omarchy font set "SFMono Nerd Font Mono"'
  omarchy font set "SFMono Nerd Font Mono" >/dev/null 2>&1 || true
fi
say "fc-match check"
for q in monospace sans-serif; do printf '    %-11s -> %s\n' "$q" "$(fc-match "$q")"; done

# ── 4. GTK / GNOME fonts ─────────────────────────────────────────────────────
say "gsettings: GTK/GNOME fonts -> SF Pro / SF Mono"
gsettings set org.gnome.desktop.interface font-name           'SFProText Nerd Font Propo 11'
gsettings set org.gnome.desktop.interface document-font-name  'SFProText Nerd Font Propo 12'
gsettings set org.gnome.desktop.interface monospace-font-name 'SFMono Nerd Font Mono 10'

# ── 5. font hinting -> none ──────────────────────────────────────────────────
# fontconfig side is the 11-cllpse-macos-hinting.conf drop-in from step 2.
# GTK/GNOME and Ghostty each read their own knob:
say "gsettings: GTK/GNOME font-hinting -> none"
gsettings set org.gnome.desktop.interface font-hinting 'none'
sync_fenced ~/.config/ghostty/config "$HERE/ghostty/hinting.conf"

# ── 6. hypr overrides ────────────────────────────────────────────────────────
sync_fenced ~/.config/hypr/hyprland.lua  "$HERE/hypr/omarchy-menu-font.lua"
sync_fenced ~/.config/hypr/looknfeel.lua "$HERE/hypr/looknfeel-decoration.lua"

# ── 7. apps Omarchy doesn't theme ───────────────────────────────────────────
say "bat -> ~/.config/bat/config (--theme=ansi)"
mkdir -p ~/.config/bat; backup ~/.config/bat/config
cp "$HERE/bat/config" ~/.config/bat/config

say "lazygit -> ~/.config/lazygit/config.yml (ANSI theme)"
mkdir -p ~/.config/lazygit; backup ~/.config/lazygit/config.yml
cp "$HERE/lazygit/config.yml" ~/.config/lazygit/config.yml

sync_fenced ~/.bashrc "$HERE/bash/fzf.sh"

# ── 8. apply theme ───────────────────────────────────────────────────────────
# `omarchy theme set` COPIES the theme folder into
# ~/.local/state/omarchy/current/theme/ — it does not symlink it. So this step
# is also what publishes any edit made to a theme folder (new background, changed
# shell.*.toml) to the live desktop; without it the running shell keeps serving
# the copy made by the last theme-set.
#
# Re-running must not yank a light-mode user back to dark, so an already-active
# cllpse-macos theme is refreshed in place; anything else defaults to dark.
current_theme="$(cat ~/.local/state/omarchy/current/theme.name 2>/dev/null || true)"
case "$current_theme" in
  omarchy-cllpse-theme-dark | omarchy-cllpse-theme-light)
    say "omarchy theme set $current_theme  (already active — refreshing the copy)"
    omarchy theme set "$current_theme" >/dev/null 2>&1 || true
    ;;
  *)
    say "omarchy theme set omarchy-cllpse-theme-dark"
    omarchy theme set omarchy-cllpse-theme-dark >/dev/null 2>&1 || true
    ;;
esac

echo
say "Done. Follow-ups:"
echo "    • log out / back in (or reboot) for OMARCHY_MENU_FONT (shell popups)"
echo "    • open a new shell for the fzf colours"
echo "    • restart Ghostty / Foot windows for SF Mono + hintnone"
echo "    • relaunch running GTK/Qt apps + the bar for hintnone"
echo "    • light theme:  omarchy theme set omarchy-cllpse-theme-light"
