#!/bin/bash
# Cursor overrides: chrome hook, settings.json merge, window-layout state
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

# See README.md (1)
if [[ -d ~/.config/Cursor/User ]]; then
  say "Cursor chrome -> ~/.config/omarchy/hooks/theme-set.d/cursor-chrome.sh"
  mkdir -p ~/.config/omarchy/hooks/theme-set.d
  ln -sfn "$HERE/hooks/theme-set.d/cursor-chrome.sh" ~/.config/omarchy/hooks/theme-set.d/cursor-chrome.sh
  "$HERE/hooks/theme-set.d/cursor-chrome.sh" || skip "cursor-chrome.sh produced nothing this run"
fi

# See README.md (2)
cursor_settings=~/.config/Cursor/User/settings.json
if [[ -x /usr/bin/cursor || -d ${cursor_settings%/*} ]]; then
  mkdir -p "${cursor_settings%/*}"
  if [[ -s $cursor_settings ]] && ! jq -e . "$cursor_settings" >/dev/null 2>&1; then
    skip "Cursor settings.json has comments / trailing commas jq won't parse —"
    skip "  merge $HERE/cursor/settings.json in by hand"
  else
    backup "$cursor_settings"
    _merged=$(mktemp)
# See README.md (3)
    _tokens="$HERE/cursor/bearded-dark-tokens.json"
    [[ -f $_tokens ]] && jq -e . "$_tokens" >/dev/null 2>&1 || _tokens="/dev/null"
    if [[ -s $cursor_settings ]]; then
      if [[ $_tokens == /dev/null ]]; then
        jq -s '.[0] * .[1]' "$cursor_settings" "$HERE/cursor/settings.json" >"$_merged" 2>/dev/null || true
      else
        jq -s '.[0] * .[1] * .[2]' "$cursor_settings" "$HERE/cursor/settings.json" "$_tokens" >"$_merged" 2>/dev/null || true
      fi
    else
      if [[ $_tokens == /dev/null ]]; then
        jq . "$HERE/cursor/settings.json" >"$_merged" 2>/dev/null || true
      else
        jq -s '.[0] * .[1]' "$HERE/cursor/settings.json" "$_tokens" >"$_merged" 2>/dev/null || true
      fi
    fi
# See README.md (4)
    _px="$(omarchy display text size 2>/dev/null | sed -n '1s/[^0-9]*\([0-9][0-9]*\).*/\1/p')"
    if [[ $_px =~ ^[0-9]+$ ]] && (( _px >= 6 && _px <= 40 )); then
      _sized=$(mktemp)
      if jq --argjson px "$_px" '.["editor.fontSize"] = $px' "$_merged" >"$_sized" 2>/dev/null && [[ -s $_sized ]]; then
        mv "$_sized" "$_merged"
      else
        rm -f "$_sized"
        skip "could not write derived editor.fontSize — kept the value from cursor/settings.json"
      fi
    else
      skip "could not read \`omarchy display text size\` — kept editor.fontSize from cursor/settings.json"
    fi

    if [[ -s $_merged ]]; then
      mv "$_merged" "$cursor_settings"
      say "Cursor -> $cursor_settings (jq merge, editor.fontSize ${_px:-fallback} from display text size)"

# See README.md (5)
      mkdir -p ~/.local/bin ~/.config/systemd/user
      ln -sfn "$HERE/cursor/cllpse-cursor-text-size" ~/.local/bin/cllpse-cursor-text-size
      _units_changed=0
      for _u in cllpse-cursor-text-size.path cllpse-cursor-text-size.service; do
        if ! cmp -s "$HERE/cursor/$_u" ~/.config/systemd/user/"$_u"; then
          cp "$HERE/cursor/$_u" ~/.config/systemd/user/"$_u"
          _units_changed=1
        fi
      done
      (( _units_changed )) && systemctl --user daemon-reload >/dev/null 2>&1
      systemctl --user enable --now cllpse-cursor-text-size.path >/dev/null 2>&1 \
        && say "Cursor text size -> follows \`omarchy display text size\` (systemd path unit)" \
        || skip "could not enable cllpse-cursor-text-size.path — editor.fontSize will only update on apply"
    else
      rm -f "$_merged"
      skip "Cursor settings merge produced nothing — left settings.json untouched"
    fi
  fi
else
  skip "Cursor not installed — skipped settings.json merge"
fi

# See README.md (6)
cursor_running() {
  local p exe
  for p in /proc/[0-9]*; do
    exe=$(readlink "$p/exe" 2>/dev/null) || continue
    case "$exe" in */electron*|*/cursor|*/Cursor) ;; *) continue ;; esac
    grep -qa '/share/cursor/' "$p/cmdline" 2>/dev/null && return 0
  done
  return 1
}

# key | value we want | the ONE value we will overwrite | state file for revert
cursor_layout_keys=(
  "cursor/unifiedAppLayout|editor|agent|previous-cursor-layout"
  "cursor/noTitlebarLayout.visibility|show|hide|previous-cursor-titlebar"
)

cursor_state=~/.config/Cursor/User/globalStorage/state.vscdb
if [[ ! -s $cursor_state ]]; then
  : # no profile yet — nothing to correct, and Cursor starts on both defaults
elif ! command -v sqlite3 >/dev/null 2>&1; then
  skip "sqlite3 missing — cannot check Cursor's layout keys (sudo pacman -S sqlite)"
elif cursor_running; then
  skip "Cursor is running — left its layout keys alone (it rewrites state.vscdb"
  skip "  from memory); close Cursor and re-run if its editor tabs are missing"
else
  for _spec in "${cursor_layout_keys[@]}"; do
    IFS='|' read -r _key _want _wrong _file <<<"$_spec"
    _have="$(sqlite3 "$cursor_state" \
      "select value from ItemTable where key='$_key';" 2>/dev/null || true)"
    [[ $_have == "$_wrong" ]] || continue
    record_prior "$STATE/$_file" "$_have" "$_want"
    if sqlite3 "$cursor_state" \
         "update ItemTable set value='$_want' where key='$_key';" 2>/dev/null &&
       [[ $(sqlite3 "$cursor_state" 'pragma integrity_check;' 2>/dev/null) == ok ]]; then
      say "Cursor $_key -> $_want (was $_wrong; editor tabs were hidden)"
    else
      skip "could not write $_key — left state.vscdb alone"
    fi
  done
fi
