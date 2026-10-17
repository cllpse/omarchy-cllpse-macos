#!/bin/bash
# Cursor and VS Code overrides: settings.json merge, chrome hook, and (Cursor
# only) window-layout state
#
#   cursor.sh           Cursor
#   cursor.sh vscode    VS Code, from the same files; apply.sh's `vscode` step
#
# The editors are a table in editors.sh. See README.md in this directory for
# what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"
source "$HERE/cursor/editors.sh"
editor_spec "${1:-cursor}" || {
  printf 'cursor.sh: unknown editor %s (one of: %s)\n' "$1" "${EDITORS[*]}" >&2
  exit 2
}

# See README.md (2)
settings="$EDITOR_USER/settings.json"
if [[ -x $EDITOR_BIN || -d $EDITOR_USER ]]; then
  mkdir -p "$EDITOR_USER"
  if [[ -s $settings ]] && ! jq -e . "$settings" >/dev/null 2>&1; then
    skip "$EDITOR_NAME settings.json has comments / trailing commas jq won't parse —"
    skip "  merge $HERE/cursor/settings.json in by hand"
  else
    backup "$settings"
    _merged=$(mktemp)
    # Left to right, each input's keys winning over the last: the editor's own
    # settings.json, ours for every editor, ours for this one alone
    # (settings.<id>.json, if there is one), then the dark syntax tokens.
    _inputs=()
    [[ -s $settings ]] && _inputs+=("$settings")
    _inputs+=("$HERE/cursor/settings.json")
    _own="$HERE/cursor/settings.$EDITOR_ID.json"
    [[ -f $_own ]] && _inputs+=("$_own")
# See README.md (3)
    _tokens="$HERE/cursor/bearded-dark-tokens.json"
    [[ -f $_tokens ]] && jq -e . "$_tokens" >/dev/null 2>&1 && _inputs+=("$_tokens")
    jq -s 'reduce .[] as $x ({}; . * $x)' "${_inputs[@]}" >"$_merged" 2>/dev/null || true
# See README.md (4): the font sizes are plain keys in cursor/settings.json now.
    if [[ -s $_merged ]]; then
      mv "$_merged" "$settings"
      say "$EDITOR_NAME -> $settings (jq merge)"
    else
      rm -f "$_merged"
      skip "$EDITOR_NAME settings merge produced nothing — left settings.json untouched"
    fi
  fi
else
  skip "$EDITOR_NAME not installed — skipped settings.json merge and chrome hook"
fi

# See README.md (1). After the merge, because the hook reads the two Bearded
# variant names out of settings.json, and on a fresh profile only the merge has
# put them there. One hook file, linked once per editor: it repaints whichever
# editor its link name belongs to (editors.sh), and it is run through that link.
if [[ -d $EDITOR_USER ]]; then
  _hook=~/.config/omarchy/hooks/theme-set.d/$EDITOR_HOOK
  say "$EDITOR_NAME chrome -> $_hook"
  mkdir -p "${_hook%/*}"
  ln -sfn "$HERE/hooks/theme-set.d/cursor-chrome.sh" "$_hook"
  "$_hook" || skip "$EDITOR_HOOK produced nothing this run"
fi

# Everything below is Cursor's alone: a watcher only Cursor ever had (retired
# whether or not Cursor is still installed), and two keys in Cursor's own state
# DB.
[[ $EDITOR_ID == cursor ]] || exit 0

# See README.md (5): retire the text-size watcher an earlier apply installed.
if [[ -e ~/.config/systemd/user/cllpse-cursor-text-size.path || -L ~/.local/bin/cllpse-cursor-text-size ]]; then
  systemctl --user disable --now cllpse-cursor-text-size.path >/dev/null 2>&1 || true
  rm -f ~/.config/systemd/user/cllpse-cursor-text-size.path \
    ~/.config/systemd/user/cllpse-cursor-text-size.service \
    ~/.local/bin/cllpse-cursor-text-size
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  say "Cursor text-size watcher removed (Electron's GTK factor carries text size now)"
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
