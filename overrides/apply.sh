#!/bin/bash
# Apply the cllpse-macos theme + every system-level override it needs.
# Idempotent. Re-run any time. See revert.sh to undo.
# No sudo except the LAST step (Chromium managed policy) — everything else is user-level.
#
#   1. symlink both themes + the window-switcher plugin into ~/.config/omarchy/
#   2. install the SF fonts + fontconfig drop-ins (UI font + hintnone)
#   3. point monospace at SF Mono (omarchy font set)
#   4. point GTK / GNOME apps at SF Pro / SF Mono (gsettings)
#   5. force hintnone for GTK/GNOME (gsettings) + Ghostty (freetype-load-flags)
#   5b. strip GTK window buttons (gsettings button-layout)
#   6. hypr overrides: OMARCHY_MENU_FONT (shell popups) + decoration (rounding, blur)
#   7. install bat / lazygit / lsd / yazi / lazydocker / gh-dash / hunk theme
#      configs, merge Cursor settings, add fzf +
#      lsd colours and the tool aliases to .bashrc, git diff pager to git config
#   7f. flat app icons for the menu (hand-placed SVGs in icons/fallbacks/)
#   7f2. post-update repair hook: re-link what an Omarchy update could take out
#   7h. Omarchy shell.json: window-switcher plugin, transparent bar, bar layout,
#       disabled first-party plugins
#   8. apply the theme (refreshes whichever cllpse-macos theme is active; dark otherwise)
#   9. Chromium context-menu declutter: spellcheck/translate/password/autofill/
#      Print/Cast/QR/Reading-list off (managed policy, sudo) — last, so the one
#      password prompt in the script comes after all the other work is done

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
# $3 (optional) distinguishes a second fenced block in a file that already
# carries one under the plain $MARK — e.g. bindings.lua fences in both
# window-switcher-bindings.lua (no $3) and keybind-unbinds.lua ($3=keybinds).
sync_fenced() { # $1 target  $2 snippet-file  $3 marker-suffix
  local mark="$MARK"; [[ -n ${3:-} ]] && mark="$MARK: $3"
  local c='#'; [[ $1 == *.lua ]] && c='--'
  local open="$c >>> $mark >>>" close="$c <<< $mark <<<"
  [[ -e $1 ]] || : >"$1"

  if ! grep -qF "$mark" "$1" 2>/dev/null; then
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
ln -sfn "$REPO/omarchy-cllpse-switcher" ~/.config/omarchy/plugins/cllpse.window-switcher

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

# ── 5c. xkb: Danish letters on the Preonic's M0 layer ────────────────────────
# Static, single-group symbols file (no toggle, no compose) - see the file
# itself for why level 1 on these keys is dead weight. Referenced by
# hyprland-env.lua's kb_layout below.
say "xkb: installing us-danish-letters -> ~/.config/xkb/symbols/"
mkdir -p ~/.config/xkb/symbols
cp "$HERE/xkb/symbols/us-danish-letters" ~/.config/xkb/symbols/us-danish-letters

# ── 6. hypr overrides ────────────────────────────────────────────────────────
# Each block is appended at the END of its file, which is what makes it win on
# load order — see the notes in the snippets themselves.
sync_fenced ~/.config/hypr/hyprland.lua  "$HERE/hypr/hyprland-env.lua"
sync_fenced ~/.config/hypr/looknfeel.lua "$HERE/hypr/looknfeel-decoration.lua"
sync_fenced ~/.config/hypr/bindings.lua  "$HERE/hypr/window-switcher-bindings.lua"
sync_fenced ~/.config/hypr/input.lua     "$HERE/hypr/input-tuning.lua"

# ── 6b. keybind allowlist ────────────────────────────────────────────────────
# keybind-scan.lua sandboxes the live ~/.config/hypr/hyprland.lua (dofile'd
# under a fake hl/o -- no interaction with the running Hyprland session, see
# the script itself) to enumerate every bind currently in effect: Omarchy
# defaults, the active theme, and the overrides just synced above.
#
# Two files, two lifecycles:
#   keybind-current.conf    regenerated from that scan on EVERY apply --
#                            reference only, never hand-edit, diff it against
#                            the allowlist below to see what Omarchy
#                            added/changed
#   keybind-allowlist.conf  seeded from -current once, then yours -- delete
#                            a line to have the next apply unbind it;
#                            apply.sh never rewrites it again once it exists
CURRENT="$HERE/hypr/keybind-current.conf"
ALLOWLIST="$HERE/hypr/keybind-allowlist.conf"

say "keybind-current.conf: rescanning every bind currently in effect"
tmp=$(mktemp)
lua "$HERE/hypr/keybind-scan.lua" dump >"$tmp"
if [[ ! -s $tmp ]]; then
  rm -f "$tmp"
  printf 'error: keybind scan produced nothing — leaving keybind files untouched\n' >&2
else
  {
    echo "# Every Hyprland keybind currently in effect, one per line as"
    echo "# \"keys<TAB>description\". Regenerated on every apply -- do not"
    echo "# hand-edit, edits here are discarded. Diff this against"
    echo "# keybind-allowlist.conf to see what's new/changed; edit that file"
    echo "# to actually prune something."
    echo "#"
    cat "$tmp"
  } >"$CURRENT"
  rm -f "$tmp"

  if [[ -e $ALLOWLIST ]]; then
    skip "keybind-allowlist.conf already exists — not reseeding (edit it directly to prune)"
  else
    say "seeding keybind-allowlist.conf from keybind-current.conf"
    {
      echo "# Your keybind whitelist. Delete a line to have the next apply run"
      echo "# unbind it. apply.sh never rewrites this file once it exists --"
      echo "# delete it yourself and re-apply to reseed from"
      echo "# keybind-current.conf."
      echo "#"
      grep -v '^#' "$CURRENT"
    } >"$ALLOWLIST"
  fi
fi

if [[ -e $ALLOWLIST ]]; then
  say "keybind-unbinds.lua: diffing keybind-current.conf against keybind-allowlist.conf"
  {
    echo "-- Generated by apply.sh from keybind-allowlist.conf. Do not hand-edit --"
    echo "-- edits here are overwritten on the next apply; edit"
    echo "-- keybind-allowlist.conf instead."
    lua "$HERE/hypr/keybind-scan.lua" unbinds "$ALLOWLIST"
  } >"$HERE/hypr/keybind-unbinds.lua"
  sync_fenced ~/.config/hypr/bindings.lua "$HERE/hypr/keybind-unbinds.lua" keybinds
fi

# macOS-parity shortcuts. Must be synced AFTER keybind-unbinds.lua above:
# some of these repurpose a combo (SUPER+LEFT/RIGHT, SUPER+SHIFT+LEFT/RIGHT)
# that the allowlist diff just unbound from its old WM meaning -- these
# bindings need to be the last word for that combo, not the unbind.
sync_fenced ~/.config/hypr/bindings.lua "$HERE/hypr/macos-shortcuts.lua" macos-shortcuts

# Window navigation/arrangement on CTRL+ALT instead of SUPER -- see the
# header comment in window-management-mod.lua for why (the Preonic
# keyboard's Gui-triggered symbol overrides were eating SUPER+UP/SHIFT+UP
# before Hyprland ever saw them). Also synced after keybind-unbinds.lua,
# same reasoning as macos-shortcuts.lua above, though these don't actually
# share a chord with anything being unbound.
sync_fenced ~/.config/hypr/bindings.lua "$HERE/hypr/window-management-mod.lua" window-management-mod

# Bibata is referenced by hyprland-env.lua and the gsettings below. No sudo
# here, so warn rather than install.
if [[ ! -d /usr/share/icons/Bibata-Modern-Ice && ! -d ~/.local/share/icons/Bibata-Modern-Ice ]]; then
  skip "cursor theme Bibata-Modern-Ice not found — install it with: yay -S bibata-cursor-theme-bin"
  skip "  (AUR, so pacman -S will not find it; the cursor setting below is applied regardless)"
fi
say "gsettings: cursor theme -> Bibata-Modern-Ice @ 24"
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'
gsettings set org.gnome.desktop.interface cursor-size 24

# ── 7. apps Omarchy doesn't theme ───────────────────────────────────────────
say "bat -> ~/.config/bat/config (--theme=ansi)"
mkdir -p ~/.config/bat; backup ~/.config/bat/config
cp "$HERE/bat/config" ~/.config/bat/config

say "lazygit -> ~/.config/lazygit/config.yml (ANSI theme)"
mkdir -p ~/.config/lazygit; backup ~/.config/lazygit/config.yml
cp "$HERE/lazygit/config.yml" ~/.config/lazygit/config.yml

if command -v lsd >/dev/null 2>&1; then
  say "lsd -> ~/.config/lsd/{config,colors}.yaml (ANSI theme)"
  mkdir -p ~/.config/lsd
  backup ~/.config/lsd/config.yaml; backup ~/.config/lsd/colors.yaml
  cp "$HERE/lsd/config.yaml"  ~/.config/lsd/config.yaml
  cp "$HERE/lsd/colors.yaml"  ~/.config/lsd/colors.yaml
else
  skip "lsd not installed — skipped ~/.config/lsd theme files"
fi

# yazi. Its own preset theme is already ANSI-based, so this is not undoing a
# hardcoded palette -- it pins the accent to blue so yazi agrees with the other
# TUIs, and flattens the chrome onto `reset`. See yazi/theme.toml.
if command -v yazi >/dev/null 2>&1; then
  say "yazi -> ~/.config/yazi/theme.toml (ANSI theme)"
  mkdir -p ~/.config/yazi
  backup ~/.config/yazi/theme.toml
  cp "$HERE/yazi/theme.toml" ~/.config/yazi/theme.toml
else
  skip "yazi not installed — skipped ~/.config/yazi/theme.toml"
fi

# lazydocker. Same four gocui theme keys, and the same ANSI vocabulary, as
# lazygit above.
if command -v lazydocker >/dev/null 2>&1; then
  say "lazydocker -> ~/.config/lazydocker/config.yml (ANSI theme)"
  mkdir -p ~/.config/lazydocker
  backup ~/.config/lazydocker/config.yml
  cp "$HERE/lazydocker/config.yml" ~/.config/lazydocker/config.yml
else
  skip "lazydocker not installed — skipped ~/.config/lazydocker/config.yml"
fi

# gh-dash. MERGED, not copied: its config.yml also holds the user's own
# prSections / issuesSections / layout, which this repo has no business owning.
# Only the `theme` key is replaced. PyYAML round-trips the file, so comments and
# key order in the parts we don't touch are not preserved -- acceptable here
# because gh-dash generates that file itself, but it is why this is a merge
# rather than a deep-merge of every key.
_ghdash_dir="${XDG_DATA_HOME:-$HOME/.local/share}/gh/extensions/gh-dash"
_ghdash_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/gh-dash/config.yml"
if [[ -d $_ghdash_dir ]] && command -v python3 >/dev/null 2>&1; then
  mkdir -p "${_ghdash_cfg%/*}"
  backup "$_ghdash_cfg"
  if python3 - "$_ghdash_cfg" "$HERE/gh-dash/theme.yml" <<'PYGH'
import sys, io
try:
    import yaml
except ImportError:
    sys.exit(3)
cfg_path, theme_path = sys.argv[1], sys.argv[2]
try:
    with io.open(cfg_path, encoding="utf-8") as f:
        cfg = yaml.safe_load(f) or {}
except FileNotFoundError:
    cfg = {}
if not isinstance(cfg, dict):
    sys.exit(4)
with io.open(theme_path, encoding="utf-8") as f:
    frag = yaml.safe_load(f) or {}
# Replace only the colors sub-tree, so a `theme.ui` block the user set survives.
theme = cfg.get("theme")
if not isinstance(theme, dict):
    theme = {}
theme["colors"] = frag["theme"]["colors"]
cfg["theme"] = theme
with io.open(cfg_path, "w", encoding="utf-8") as f:
    yaml.safe_dump(cfg, f, sort_keys=False, default_flow_style=False, allow_unicode=True)
PYGH
  then
    say "gh-dash -> $_ghdash_cfg (ANSI theme, merged)"
  else
    skip "gh-dash theme merge failed (PyYAML missing or config unparseable) —"
    skip "  merge $HERE/gh-dash/theme.yml in by hand"
  fi
else
  skip "gh-dash not installed — skipped its theme merge"
fi

# Starship has no Omarchy-aware theming of its own and no config "import"
# mechanism to point at a themed file the way Ghostty/Alacritty/foot do, so
# instead of a themed/*.tpl this hooks into `omarchy-hook theme-set`
# (~/.config/omarchy/hooks/theme-set.d/), called on every `omarchy theme set`
# — see the hook script itself for why. Backed up like bat/lazygit/lsd above
# since it replaces the user's ~/.config/starship.toml outright; run once now
# so the currently active theme's colour reaches it without waiting for the
# next theme switch.
say "starship -> ~/.config/omarchy/hooks/theme-set.d/starship-colors.sh"
mkdir -p ~/.config/omarchy/hooks/theme-set.d
ln -sfn "$HERE/hooks/theme-set.d/starship-colors.sh" ~/.config/omarchy/hooks/theme-set.d/starship-colors.sh
backup ~/.config/starship.toml
"$HERE/hooks/theme-set.d/starship-colors.sh" || skip "starship-colors.sh produced nothing this run — left ~/.config/starship.toml untouched"

# hunk — the one tool here that cannot use the terminal palette (its validator
# takes hex only, and every built-in theme is a bundled Shiki theme), so its
# colours are BAKED from the active colors.toml on every theme-set, the same
# hook mechanism starship uses above. The hook writes config.toml whole, so
# back it up once before the first run.
# yazi's previewer — syntect reads a .tmTheme, which is hex-only, so the
# previewer's syntax colours are baked per theme like hunk's. Unlike the rest of
# yazi/theme.toml (ANSI, no regeneration), this one needs the hook. See the
# syntect_theme note in yazi/theme.toml for what the trade buys.
if command -v yazi >/dev/null 2>&1; then
  say "yazi previewer -> ~/.config/omarchy/hooks/theme-set.d/yazi-syntax.sh"
  mkdir -p ~/.config/omarchy/hooks/theme-set.d ~/.config/yazi
  ln -sfn "$HERE/hooks/theme-set.d/yazi-syntax.sh" ~/.config/omarchy/hooks/theme-set.d/yazi-syntax.sh
  "$HERE/hooks/theme-set.d/yazi-syntax.sh" || skip "yazi-syntax.sh produced nothing this run — left the .tmTheme untouched"
fi

if command -v hunk >/dev/null 2>&1; then
  say "hunk -> ~/.config/omarchy/hooks/theme-set.d/hunk-colors.sh"
  mkdir -p ~/.config/omarchy/hooks/theme-set.d ~/.config/hunk
  ln -sfn "$HERE/hooks/theme-set.d/hunk-colors.sh" ~/.config/omarchy/hooks/theme-set.d/hunk-colors.sh
  backup ~/.config/hunk/config.toml
  "$HERE/hooks/theme-set.d/hunk-colors.sh" || skip "hunk-colors.sh produced nothing this run — left ~/.config/hunk/config.toml untouched"
else
  skip "hunk not installed — skipped its theme hook (mise use -g hunk)"
fi

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

# git: route `git diff` through hunk (see git/pager.conf for why it needs no
# guard). Fenced rather than copied, because ~/.config/git/config is Omarchy's
# stock file plus the user's own [user] block -- identity that must not come
# from this repo. Seed from the stock copy first if the user has none, so a
# fresh machine doesn't end up with a git config consisting only of our block
# (the `sync_fenced` trap in README.md's gaps table).
mkdir -p ~/.config/git
if [[ ! -e ~/.config/git/config && -r /usr/share/omarchy/config/git/config ]]; then
  say "git -> seeded ~/.config/git/config from Omarchy's stock copy"
  cp /usr/share/omarchy/config/git/config ~/.config/git/config
fi
sync_fenced ~/.config/git/config "$HERE/git/pager.conf"

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

# ── 7f. Flat app icons for the menu ──────────────────────────────────────────
# The Omarchy menu draws icons two ways. Non-app rows render `row.icon` as TEXT
# in a Nerd Font, tinted `foreground` — that is the flat, theme-tracking look.
# App rows instead render a plain Image of whatever the desktop entry's `Icon=`
# resolves to (Menu.qml:1253), with no recolouring at all, so every app shows
# its vendor's full-colour logo. Measured on this machine: 48 of 52 visible
# entries resolve to a colour icon.
#
# There is no setting for this. The only lever short of forking the first-party
# menu plugin is to make `Icon=` resolve to a file we control — and
# AppLibrary.qml makes that easy, because it consults its OWN index (a find over
# every XDG icon dir, svg pass then png, first hit per name) BEFORE Qt's themed
# lookup, and `$HOME/.icons` is the first directory in both passes. A file
# dropped there outranks every installed theme. It carries no index.theme, so
# GTK and Qt never see it: the override reaches the Omarchy shell and nothing
# else.
#
# Nothing is generated. icons/fallbacks/ holds hand-placed SVGs (or PNGs), one
# per desktop-entry `Icon=` value; see that directory's README for the naming
# and silhouette contract. An app with no file there simply keeps its vendor
# icon. The sync is a theme-set hook rather than a step here because app icons
# are never recoloured by the shell — a synced file has a fixed colour and must
# be rewritten per theme. Run once now so the icons exist before step 8; step
# 8's `omarchy theme set` then re-runs it and restarts the shell, which is what
# drops Qt's URL-keyed image cache and makes a colour change actually land.
if [[ -d "$HERE/icons/fallbacks" ]]; then
  _n=$(find "$HERE/icons/fallbacks" -maxdepth 1 \( -name '*.svg' -o -name '*.png' \) | wc -l)
  say "app icons -> ~/.icons/cllpse-flat/apps/ ($_n hand-placed)"
  mkdir -p ~/.config/omarchy/hooks/theme-set.d
  ln -sfn "$HERE/hooks/theme-set.d/app-icons.sh" ~/.config/omarchy/hooks/theme-set.d/app-icons.sh
  "$HERE/hooks/theme-set.d/app-icons.sh" || skip "app-icons.sh produced nothing this run"
  (( _n == 0 )) && skip "icons/fallbacks/ is empty — every app keeps its vendor icon"
else
  skip "no icons/fallbacks/ — skipped the app icons"
fi

# ── 7f2. Post-update repair hook ─────────────────────────────────────────────
# Everything this script installs lives either in directories that are ours
# alone (~/.icons/, ~/.local/, ~/.config/hypr/) or as symlinks inside
# directories Omarchy ships and manages (~/.config/omarchy/{hooks,themes,
# plugins}/). The first group no Omarchy command touches. The second is exposed:
# Omarchy ships its own content into those paths — config/omarchy/hooks/
# theme-set.d/ carries .sample files — so a refresh, a migration, or a future
# install step that repopulates one of them takes our symlink with it, silently.
# The icons would simply revert to vendor logos at the next theme change with
# nothing to say why.
#
# omarchy-update calls `omarchy-hook post-update` (omarchy-update:49), so a hook
# dropped here re-links everything once per update at no scheduling cost. It is
# idempotent, so it runs unconditionally rather than trying to detect damage.
say "post-update repair -> ~/.config/omarchy/hooks/post-update.d/cllpse-macos-repair.sh"
mkdir -p ~/.config/omarchy/hooks/post-update.d
ln -sfn "$HERE/hooks/post-update.d/cllpse-macos-repair.sh" \
  ~/.config/omarchy/hooks/post-update.d/cllpse-macos-repair.sh

# ── 7h. Omarchy shell: switcher, transparent bar, bar layout, disabled plugins ─
# Targeted key writes into ~/.config/omarchy/shell.json, Omarchy's own
# machine-level shell config. Deliberately still not a whole-file copy or a deep
# merge: the file also carries `idle`, `version` and any other plugin's own
# widget config, none of which this repo has an opinion about, and `plugins[]`
# is an array a deep merge would replace rather than append to.
#
#   plugins[]         step 1 symlinks the switcher into ~/.config/omarchy/
#                     plugins/, but that only INSTALLS it — Omarchy enables a
#                     plugin from this array, keyed by the manifest id (the
#                     folder name is cosmetic). Without the entry the plugin
#                     sits there and the HUD never loads, with nothing to say so.
#   bar.transparent   Omarchy ships false; the macOS look wants the bar reading
#                     the wallpaper through the shell's background-alpha.
#   bar.layout        the widget set and its order, from omarchy/shell-bar.json.
#   bar.centerAnchor  which center widget is pinned to the true screen centre.
#   disabledPlugins   first-party non-widget plugins to turn off.
#
# The last three used to be left alone as personal. They are owned now because
# they are the same kind of decision as everything else here — which chrome the
# desktop shows — and because two of them are already half-made elsewhere in
# this repo: the keybind sweep unbinds SUPER+CTRL+V, SUPER+CTRL+E and the three
# reminder binds, so clipboard / emojis / reminders were already unreachable
# while still loading. Note the consequence: a bar rearranged in a settings GUI
# after an apply is reset by the next one. Edit shell-bar.json, don't re-drag.
#
# disabledPlugins[] only reaches FIRST-PARTY NON-WIDGET plugins — panels and
# services (PluginRegistry.qml:148-165). A bar widget has no off state there;
# it is disabled by not being in bar.layout, which is how the OmaSettings widget
# is switched off. A third-party plugin is enabled iff its id appears anywhere
# in shell.json, so dropping it from the layout is the whole uninstall.
#
# Two things the layout is NOT allowed to clobber. The tray's `pinned` /
# `hidden` arrays are genuinely per-machine — they name tray items that exist on
# this box — so whatever the live file has is carried over onto our tray entry
# rather than replaced; shell-bar.json keeps the entry bare on purpose. And
# bar.centerAnchor names omarchy.clock, which is not in the layout: with the
# anchor absent Bar.qml's `hasAnchor` is false and the whole center section just
# centres as a block (Bar.qml:1538), so the key is inert — kept at Omarchy's
# stock value so that re-adding a clock restores the anchoring for free.
#
# The pre-existing values are recorded once for revert.sh, on the same terms as
# the font and theme above: a value that already matches what we would write is
# refused, so a re-run can't turn revert into a no-op.
#
# Picked up by step 8's theme-set, which restarts the shell — a hyprctl reload
# does not.
shell_json=~/.config/omarchy/shell.json
switcher_id=cllpse.window-switcher
bar_json="$HERE/omarchy/shell-bar.json"
if [[ ! -f $shell_json ]]; then
  skip "no $shell_json — skipped the switcher enable, bar transparency and layout"
elif [[ ! -f $bar_json ]]; then
  skip "no $bar_json — skipped the shell.json writes"
else
  _want=$(mktemp)
  if jq --arg id "$switcher_id" --slurpfile bar "$bar_json" '
        $bar[0] as $b
        # The live tray entry, wherever it currently sits, for its pinned/hidden.
        | ([ (.bar.layout // {}) | .[]? | .[]? ]
           | map(select(.id == "omarchy.tray")) | first) as $tray
        | .plugins = ((.plugins // [])
            | if any(.id == $id) then . else . + [{ id: $id }] end)
        | .bar.transparent = true
        | .bar.centerAnchor = $b.bar.centerAnchor
        | .bar.layout = ($b.bar.layout | with_entries(.value |= map(
            if .id == "omarchy.tray" and $tray != null
            then . + ($tray | { pinned, hidden } | with_entries(select(.value != null)))
            else . end)))
        | .disabledPlugins = $b.disabledPlugins
      ' "$shell_json" >"$_want" 2>/dev/null && [[ -s $_want ]]; then

    # Everything the block above would change, as one compact blob, so revert
    # has a single thing to put back. Compared against what we are about to
    # write rather than against shell-bar.json, so the tray carry-over doesn't
    # read as a difference and get recorded on an already-applied machine.
    _subset='{ layout: .bar.layout, centerAnchor: .bar.centerAnchor, disabled: .disabledPlugins }'
    record_prior "$STATE/previous-bar-layout" \
      "$(jq -cS "$_subset" "$shell_json" 2>/dev/null || true)" \
      "$(jq -cS "$_subset" "$_want" 2>/dev/null || true)"
    record_prior "$STATE/previous-bar-transparent" \
      "$(jq -r '.bar.transparent // empty' "$shell_json" 2>/dev/null || true)" "true"

    if jq -e --slurpfile want "$_want" '. == $want[0]' "$shell_json" >/dev/null 2>&1; then
      skip "shell.json already has the switcher, transparent bar, layout and disabled plugins"
    else
      backup "$shell_json"
      # cat, not mv: keeps shell.json's own inode and 0600 mode.
      cat "$_want" >"$shell_json"
      say "shell.json -> $switcher_id enabled, bar.transparent = true, bar layout + disabledPlugins applied"
    fi
  else
    skip "shell.json isn't parseable JSON — left untouched, enable the switcher by hand"
  fi
  rm -f "$_want"
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
# Filename of whatever wallpaper is live right now, or empty if there is none.
current_bg_name() {
  basename "$(readlink -f ~/.local/state/omarchy/current/background 2>/dev/null || true)" 2>/dev/null || true
}

prev_bg="$(current_bg_name)"

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
  if [[ "$(current_bg_name)" != "$prev_bg" ]]; then
    omarchy theme bg set "$restored_bg" >/dev/null 2>&1 || true
    skip "kept the current background ($prev_bg)"
  fi
fi

# ── 9. Chromium context-menu declutter: managed policy (needs sudo) ────────
# LAST on purpose. This is the only step that needs sudo, so it runs after
# everything else rather than stalling a run halfway through on a password
# prompt. It used to sit between 7f2 and 7h.
# Spellcheck / Translate / password-save-prompt / Autofill / Print / Cast /
# QR-code / Reading-list all end up here, not in a Preferences file.
# An earlier version of this step wrote the first five as plain Preferences
# keys instead — a plain pref only changes the *default*, so Settings still
# showed the toggle as changeable, and per Chrome's own docs a bare
# `translate.enabled` pref (unlike the `TranslateEnabled` policy) never
# suppresses the manual "Translate to…" context-menu entry, only the
# automatic offer. Confirmed live on this machine: the pref round-tripped
# correctly and the menu item was still there. (It also silently failed for
# four of the five keys regardless — `browser.enable_spellchecking`,
# `translate.enabled` and both `autofill.*` keys have dots in their real pref
# name, and Chromium's JsonPrefStore nests dotted names into nested objects
# on write/read; writing them as flat top-level keys with a literal dot in
# the JSON key name — as that version did — creates a key Chromium never
# reads. Only `credentials_enable_service`, with no dot, actually landed.)
# The enterprise-policy names for all five (`TranslateEnabled`,
# `SpellcheckEnabled`, `PasswordManagerEnabled`, `AutofillAddressEnabled`,
# `AutofillCreditCardEnabled`) are confirmed present in this machine's
# installed Chromium binary. Policy also has no "must be closed to write"
# trap: `chromium --refresh-platform-policy --no-startup-window` reloads the
# whole managed directory live, so a running Chromium picks this up with no
# relaunch — the same mechanism Omarchy uses for its own color.json.
#
# That refresh used to come for free: omarchy-theme-set-browser runs it on
# every theme-set, and this step sat BEFORE step 8. Now that it runs after,
# step 8's refresh has already happened by the time this file is written, so
# the refresh is invoked explicitly below. It mirrors that script's own
# refresh_running_browser: `pgrep -x chromium`, where -x matches the process
# NAME — unlike -f, which matches whole command lines and would happily match
# this script for containing the string.
#
# Mirrors Omarchy's own /etc/chromium/policies/managed/ guard verbatim (see
# omarchy-theme-set-browser-policy): only write into a policy directory that
# already exists, since Chromium (or another Chromium-family browser sharing
# this path) being absent means the directory won't exist either, and
# creating one would hand a browser a managed-policy root it doesn't
# otherwise have. `install` (no -D) leaves ownership at root:root under sudo,
# which also matters here: a one-time Omarchy migration purges anything in
# this directory NOT owned by root.
#
# DevTools is deliberately NOT in this list. DeveloperToolsAvailability=2 was
# here originally, as part of the context-menu declutter, but it is the one key
# whose blast radius went well past the menu: it blocks Inspect everywhere,
# including your own local dev servers. Dropping the key restores Chromium's
# own default (0 — DevTools available except on force-installed extensions)
# rather than asserting a value, which is what a managed policy should do for a
# setting we have no opinion about. "Inspect" comes back in the context menu as
# a consequence; there is no lever that separates the two.
if [[ -f "$HERE/chromium/policies-managed.json" &&
      -d /etc/chromium/policies/managed && ! -L /etc/chromium/policies/managed ]]; then
  dest=/etc/chromium/policies/managed/cllpse-macos.json
  if [[ -f $dest ]] && cmp -s "$HERE/chromium/policies-managed.json" "$dest"; then
    skip "Chromium managed policy already current"
  else
    say "Chromium managed policy -> $dest (sudo)"
    sudo install -m644 "$HERE/chromium/policies-managed.json" "$dest"
    if command -v chromium >/dev/null 2>&1 && pgrep -x chromium >/dev/null; then
      chromium --refresh-platform-policy --no-startup-window &>/dev/null || true
      skip "reloaded the running Chromium's managed policy (no relaunch needed)"
    fi
  fi
fi

echo
say "Done. Follow-ups:"
echo "    • log out / back in (or reboot) for OMARCHY_MENU_FONT (shell popups)"
echo "    • open a new shell for the fzf colours"
echo "    • restart Ghostty / Foot windows for SF Mono + hintnone"
echo "    • relaunch running GTK/Qt apps + the bar for hintnone"
echo "    • light theme:  omarchy theme set omarchy-cllpse-theme-light"
echo "    • the spellcheck/translate/password/autofill/Print/Cast/QR/reading-list policy (9)"
echo "      already refreshed live if Chromium was running — no relaunch needed"
echo "    • boot splash / login screen (needs sudo, not run by this script):"
echo "        omarchy plymouth set by theme omarchy-cllpse-theme-dark   # or -light"
