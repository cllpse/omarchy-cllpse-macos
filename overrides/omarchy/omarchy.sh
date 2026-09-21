#!/bin/bash
# Omarchy shell.json: switcher, bar, disabled plugins
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

# See README.md (1)
shell_json=~/.config/omarchy/shell.json
switcher_id=cllpse.window-switcher
# See README.md (2)
switcher_id_legacy=io.eject.window-switcher
bar_json="$HERE/omarchy/shell-bar.json"
if [[ ! -f $shell_json ]]; then
  skip "no $shell_json — skipped the switcher enable, bar transparency and layout"
elif [[ ! -f $bar_json ]]; then
  skip "no $bar_json — skipped the shell.json writes"
else
  _want=$(mktemp)
  if jq --arg id "$switcher_id" --arg old "$switcher_id_legacy" --slurpfile bar "$bar_json" '
        $bar[0] as $b
        # The live tray entry, wherever it currently sits, for its pinned/hidden.
        | ([ (.bar.layout // {}) | .[]? | .[]? ]
           | map(select(.id == "omarchy.tray")) | first) as $tray
        | .plugins = ((.plugins // [])
            | map(select(.id != $old))
            | if any(.id == $id) then . else . + [{ id: $id }] end)
        | .bar.transparent = true
        | .bar.centerAnchor = $b.bar.centerAnchor
        | .bar.layout = ($b.bar.layout | with_entries(.value |= map(
            if .id == "omarchy.tray" and $tray != null
            then . + ($tray | { pinned, hidden } | with_entries(select(.value != null)))
            else . end)))
        | .disabledPlugins = $b.disabledPlugins
      ' "$shell_json" >"$_want" 2>/dev/null && [[ -s $_want ]]; then

# See README.md (3)
    _subset='{ layout: .bar.layout, centerAnchor: .bar.centerAnchor, disabled: .disabledPlugins }'
    record_prior "$STATE/previous-bar-layout" \
      "$(jq -cS "$_subset" "$shell_json" 2>/dev/null || true)" \
      "$(jq -cS "$_subset" "$_want" 2>/dev/null || true)"
# See README.md (4)
    record_prior "$STATE/previous-bar-transparent" \
      "$(jq -r '.bar.transparent | if . == null then empty else tostring end' "$shell_json" 2>/dev/null || true)" "true"

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

