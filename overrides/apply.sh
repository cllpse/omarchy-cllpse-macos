#!/bin/bash
# Apply the cllpse-macos theme + every system-level override it needs.
# Idempotent, no sudo. Re-run any time. See revert.sh to undo.
#
#   1. symlink both themes + the window-switcher plugin into ~/.config/omarchy/
#   2. install the SF fonts + fontconfig drop-ins (UI font + hintnone)
#   3. point monospace at SF Mono (omarchy font set)
#   4. point GTK / GNOME apps at SF Pro / SF Mono (gsettings)
#   5. force hintnone for GTK/GNOME (gsettings) + Ghostty (freetype-load-flags)
#   5b. strip GTK window buttons (gsettings button-layout)
#   6. hypr overrides: OMARCHY_MENU_FONT (shell popups) + decoration (rounding, blur)
#   7. install bat / lazygit theme configs, merge Cursor settings, add fzf colours to .bashrc
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

# ── 0. record pre-existing state ─────────────────────────────────────────────
# revert.sh restores what this machine had before apply.sh first ran, rather
# than hardcoding Omarchy's stock font/theme — those are only right on a machine
# that was already stock. Written once and never overwritten, so re-running
# apply.sh can't clobber the original with our own values.
#
# Values that are already ours are refused outright: on a machine where apply.sh
# has run before, `omarchy font current` reports SF Mono, and recording that
# would quietly turn revert into a no-op.
STATE="$HOME/.local/state/cllpse-macos"
mkdir -p "$STATE"

record_prior() { # $1 state-file  $2 value  $3 value-to-refuse
  [[ -e $1 ]] && return 0                      # first apply wins, never overwrite
  [[ -z $2 || $2 == "$3" ]] && return 0         # nothing to record, or it's ours
  printf '%s\n' "$2" >"$1"
  skip "recorded pre-existing $(basename "$1"): $2"
}

record_prior "$STATE/previous-font" \
  "$(omarchy font current 2>/dev/null || true)" "SFMono Nerd Font Mono"

prior_theme="$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || true)"
case "$prior_theme" in omarchy-cllpse-theme-*) prior_theme="" ;; esac
record_prior "$STATE/previous-theme" "$prior_theme" ""

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
sync_fenced ~/.config/ghostty/config "$HERE/ghostty/ghostty.conf"

# ── 5b. GTK window buttons -> none ───────────────────────────────────────────
# Hyprland draws no titlebars; the min/max/close a GTK/libadwaita app shows are
# its own client-side decoration, laid out from this key (Nautilus, Files, the
# GNOME apps). ':' = nothing either side of the divider. Omarchy's default is
# 'appmenu:close'. Electron/Qt draw their own controls and ignore this — Cursor
# is handled in step 7. `gsettings reset` (revert.sh) restores the default.
say "gsettings: GTK window buttons -> none"
gsettings set org.gnome.desktop.wm.preferences button-layout ':'

# ── 6. hypr overrides ────────────────────────────────────────────────────────
# Each block is appended at the END of its file, which is what makes it win on
# load order — see the notes in the snippets themselves.
sync_fenced ~/.config/hypr/hyprland.lua  "$HERE/hypr/hyprland-env.lua"
sync_fenced ~/.config/hypr/looknfeel.lua "$HERE/hypr/looknfeel-decoration.lua"
sync_fenced ~/.config/hypr/bindings.lua  "$HERE/hypr/window-switcher-bindings.lua"
sync_fenced ~/.config/hypr/input.lua     "$HERE/hypr/input-tuning.lua"

# Bibata is referenced by hyprland-env.lua and the gsettings below. No sudo
# here, so warn rather than install.
if [[ ! -d /usr/share/icons/Bibata-Modern-Ice && ! -d ~/.local/share/icons/Bibata-Modern-Ice ]]; then
  skip "cursor theme Bibata-Modern-Ice not found — install it with: yay -S bibata-cursor-theme-bin"
  skip "  (AUR, so pacman -S will not find it; the cursor setting below is applied regardless)"
fi
say "gsettings: cursor theme -> Bibata-Modern-Ice @ 22"
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'
gsettings set org.gnome.desktop.interface cursor-size 22

# ── 7. apps Omarchy doesn't theme ───────────────────────────────────────────
say "bat -> ~/.config/bat/config (--theme=ansi)"
mkdir -p ~/.config/bat; backup ~/.config/bat/config
cp "$HERE/bat/config" ~/.config/bat/config

say "lazygit -> ~/.config/lazygit/config.yml (ANSI theme)"
mkdir -p ~/.config/lazygit; backup ~/.config/lazygit/config.yml
cp "$HERE/lazygit/config.yml" ~/.config/lazygit/config.yml

# Cursor — deep-merge our editor prefs into settings.json with jq: our keys win,
# any key we don't set is kept. Omarchy owns workbench.colorTheme (it rewrites it
# to "Omarchy" on every `omarchy theme set`, via omarchy-theme-set-vscode), so
# cursor/settings.json deliberately omits it. Cursor is the only editor of this
# family installed here; VS Code / VSCodium would each want their own merge.
cursor_settings=~/.config/Cursor/User/settings.json
if [[ -x /usr/bin/cursor || -d ${cursor_settings%/*} ]]; then
  mkdir -p "${cursor_settings%/*}"
  if [[ -s $cursor_settings ]] && ! jq -e . "$cursor_settings" >/dev/null 2>&1; then
    skip "Cursor settings.json has comments / trailing commas jq won't parse —"
    skip "  merge $HERE/cursor/settings.json in by hand"
  else
    backup "$cursor_settings"
    _merged=$(mktemp)
    if [[ -s $cursor_settings ]]; then
      jq -s '.[0] * .[1]' "$cursor_settings" "$HERE/cursor/settings.json" >"$_merged" 2>/dev/null || true
    else
      jq . "$HERE/cursor/settings.json" >"$_merged" 2>/dev/null || true
    fi
    if [[ -s $_merged ]]; then
      mv "$_merged" "$cursor_settings"
      say "Cursor -> $cursor_settings (jq merge)"
    else
      rm -f "$_merged"
      skip "Cursor settings merge produced nothing — left settings.json untouched"
    fi
  fi
else
  skip "Cursor not installed — skipped settings.json merge"
fi

sync_fenced ~/.bashrc "$HERE/bash/shell.sh"

# ── 7b. display scaling + text size ──────────────────────────────────────────
# Restore overrides/display.conf (written by ./overrides/save-display.sh). Any
# key left empty is skipped, and a missing file skips the step entirely.
#
# These are a machine preference, not part of the macOS look -- re-running
# apply.sh reasserts them, so if you retune the text size or scale by hand, run
# save-display.sh to make that the saved state rather than having the next
# apply.sh pull you back.
if [[ -f "$HERE/display.conf" ]]; then
  # shellcheck source=overrides/display-lib.sh
  source "$HERE/display-lib.sh"

  want_text="$(conf_get text-size "$HERE/display.conf")"
  want_mon="$(conf_get monitor-scale "$HERE/display.conf")"
  want_gdk="$(conf_get gdk-scale "$HERE/display.conf")"

  # Record the machine's own values once, so revert.sh can put them back.
  record_prior "$STATE/previous-text-size"     "$(read_text_size)"                  "$want_text"
  record_prior "$STATE/previous-monitor-scale" "$(read_scale omarchy_monitor_scale)" "$want_mon"
  record_prior "$STATE/previous-gdk-scale"     "$(read_scale omarchy_gdk_scale)"     "$want_gdk"

  if [[ -n $want_text && "$(read_text_size)" != "$want_text" ]]; then
    say "omarchy display text size $want_text  (shell + GTK factor + terminals)"
    omarchy display text size "$want_text" >/dev/null 2>&1 || true
  else
    skip "text size already $want_text"
  fi

  for pair in "omarchy_monitor_scale:$want_mon" "omarchy_gdk_scale:$want_gdk"; do
    var="${pair%%:*}"; val="${pair#*:}"
    [[ -n $val ]] || continue
    if [[ "$(read_scale "$var")" == "$val" ]]; then
      skip "$var already $val"
    elif write_scale "$var" "$val"; then
      say "$var -> $val  (monitors.lua; takes effect on the next Hyprland reload)"
    else
      skip "$var not found in ~/.config/hypr/monitors.lua — left alone"
    fi
  done
fi

# ── 7c. session environment drop-ins ─────────────────────────────────────────
# Read by the systemd user session (uwsm starts Hyprland through it), so these
# survive application updates in a way a wrapper script inside an app directory
# does not. Applies from the next login.
if [[ -d "$HERE/environment.d" ]]; then
  say "environment.d drop-ins -> ~/.config/environment.d/"
  mkdir -p ~/.config/environment.d
  for f in "$HERE"/environment.d/*.conf; do
    [[ -e $f ]] || continue
    if cmp -s "$f" ~/.config/environment.d/"$(basename "$f")"; then
      skip "$(basename "$f") already current"
    else
      cp "$f" ~/.config/environment.d/"$(basename "$f")"
      say "installed $(basename "$f")  (takes effect on next login)"
    fi
  done
fi

# ── 7d. Chromium scale ───────────────────────────────────────────────────────
# Two settings that only make sense together: the flag pins the device pixel
# ratio to 1 (20% under DP-2's 1.25), and the preference puts page zoom back on
# top. Page size is the product of the two — 110% ships, so 0.8 x 1.1 = 0.88;
# 125% would be exactly 1:1 with native. Browser UI stays at 0.8 either way,
# since zoom does not touch it. See the header of each file.
#
# The flag file is Omarchy's, so it takes a fenced block like every other
# shared config here; the launcher skips "#" lines, which makes the markers
# inert. Drop any bare copy of the flag first: it predates the fenced block on
# this machine and would otherwise be passed twice.
if [[ -f "$HERE/chromium/chromium-flags.conf" ]]; then
  if [[ -f ~/.config/chromium-flags.conf ]] &&
     grep -q '^--force-device-scale-factor=' ~/.config/chromium-flags.conf &&
     ! grep -q "$MARK" ~/.config/chromium-flags.conf; then
    sed -i '/^--force-device-scale-factor=/d' ~/.config/chromium-flags.conf
    skip "dropped a pre-existing --force-device-scale-factor line"
  fi
  sync_fenced ~/.config/chromium-flags.conf "$HERE/chromium/chromium-flags.conf"
fi

# There is no command-line flag for default page zoom — see the script header
# for what was checked and for the log-scale the preference is stored in.
if [[ -x "$HERE/chromium/default-zoom.py" ]]; then
  say "Chromium default page zoom -> ${CLLPSE_CHROMIUM_ZOOM:-110}%"
  "$HERE/chromium/default-zoom.py" "${CLLPSE_CHROMIUM_ZOOM:-110}" || true
fi

# ── 8. apply theme ───────────────────────────────────────────────────────────
# `omarchy theme set` COPIES the theme folder into
# ~/.local/state/omarchy/current/theme/ — it does not symlink it. So this step
# is also what publishes any edit made to a theme folder (new background, changed
# shell.*.toml) to the live desktop; without it the running shell keeps serving
# the copy made by the last theme-set.
#
# Re-running must not yank a light-mode user back to dark, so an already-active
# cllpse-macos theme is refreshed in place; anything else defaults to dark.
# `omarchy theme set` does not keep the current wallpaper: choose_theme_background
# advances to the NEXT one in the folder every call (next_index = index + 1), so
# without this a re-run walks the background forward each time. Remember it by
# name and put it back afterwards if the new theme still has a file by that name.
prev_bg="$(basename "$(readlink -f ~/.local/state/omarchy/current/background 2>/dev/null || true)" 2>/dev/null || true)"

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

restored_bg="$HOME/.local/state/omarchy/current/theme/backgrounds/$prev_bg"
if [[ -n $prev_bg && -f $restored_bg ]]; then
  if [[ "$(basename "$(readlink -f ~/.local/state/omarchy/current/background 2>/dev/null || true)" 2>/dev/null || true)" != "$prev_bg" ]]; then
    omarchy theme bg set "$restored_bg" >/dev/null 2>&1 || true
    skip "kept the current background ($prev_bg)"
  fi
fi

echo
say "Done. Follow-ups:"
echo "    • log out / back in (or reboot) for OMARCHY_MENU_FONT (shell popups)"
echo "    • open a new shell for the fzf colours"
echo "    • restart Ghostty / Foot windows for SF Mono + hintnone"
echo "    • relaunch running GTK/Qt apps + the bar for hintnone"
echo "    • light theme:  omarchy theme set omarchy-cllpse-theme-light"
echo "    • boot splash / login screen (needs sudo, not run by this script):"
echo "        omarchy plymouth set by theme omarchy-cllpse-theme-dark   # or -light"
