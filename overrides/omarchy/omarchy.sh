#!/bin/bash
# Omarchy shell.json: switcher, bar, disabled plugins
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
#
# --bar-only narrows the write to bar.layout + bar.centerAnchor and installs
# nothing. It exists for hooks/post-boot.d/bar-layout.sh, which restores the
# declared widget order once per session; see README.md (5). A boot hook has no
# business re-asserting plugins[], bar.transparent or disabledPlugins behind the
# user's back -- those stay apply.sh's job -- and it deliberately records no
# prior state either, because establishing what revert.sh puts back is the first
# apply's job, not a hook's.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

bar_only=false
[[ ${1:-} == --bar-only ]] && bar_only=true

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
  if jq --arg id "$switcher_id" --arg old "$switcher_id_legacy" \
        --argjson baronly "$bar_only" --slurpfile bar "$bar_json" '
        $bar[0] as $b
        # The live tray entry, wherever it currently sits, for its pinned/hidden.
        | ([ (.bar.layout // {}) | .[]? | .[]? ]
           | map(select(.id == "omarchy.tray")) | first) as $tray
        | (if $baronly then . else .plugins = ((.plugins // [])
            | map(select(.id != $old))
            | if any(.id == $id) then . else . + [{ id: $id }] end) end)
        | (if $baronly then . else .bar.transparent = true end)
        | .bar.centerAnchor = $b.bar.centerAnchor
        | .bar.layout = ($b.bar.layout | with_entries(.value |= map(
            if .id == "omarchy.tray" and $tray != null
            then . + ($tray | { pinned, hidden } | with_entries(select(.value != null)))
            else . end)))
        | (if $baronly then . else .disabledPlugins = $b.disabledPlugins end)
      ' "$shell_json" >"$_want" 2>/dev/null && [[ -s $_want ]]; then

# See README.md (3). Skipped under --bar-only: recording what revert.sh puts
# back is the first apply's job, and a hook that fires every session must never
# be what establishes it -- on a machine where apply.sh had not run yet, the
# boot hook would record OUR layout as the "pre-existing" one and revert would
# have nothing real to restore.
    if [[ $bar_only == false ]]; then
    _subset='{ layout: .bar.layout, centerAnchor: .bar.centerAnchor, disabled: .disabledPlugins }'
    record_prior "$STATE/previous-bar-layout" \
      "$(jq -cS "$_subset" "$shell_json" 2>/dev/null || true)" \
      "$(jq -cS "$_subset" "$_want" 2>/dev/null || true)"
# See README.md (4)
    record_prior "$STATE/previous-bar-transparent" \
      "$(jq -r '.bar.transparent | if . == null then empty else tostring end' "$shell_json" 2>/dev/null || true)" "true"
    fi

    if jq -e --slurpfile want "$_want" '. == $want[0]' "$shell_json" >/dev/null 2>&1; then
      if [[ $bar_only == true ]]; then
        skip "shell.json: bar layout already as declared"
      else
        skip "shell.json already has the switcher, transparent bar, layout and disabled plugins"
      fi
    else
      backup "$shell_json"
      # cat, not mv: keeps shell.json's own inode and 0600 mode.
      cat "$_want" >"$shell_json"
      if [[ $bar_only == true ]]; then
        say "shell.json -> bar layout restored from shell-bar.json"
      else
        say "shell.json -> $switcher_id enabled, bar.transparent = true, bar layout + disabledPlugins applied"
      fi
    fi
  else
    skip "shell.json isn't parseable JSON — left untouched, enable the switcher by hand"
  fi
  rm -f "$_want"
fi

# See README.md (5). The bar's widget order is drag-reorderable with no setting
# to turn that off, so it is restored once per session instead of defended.
if [[ $bar_only == false ]]; then
  say "bar layout -> ~/.config/omarchy/hooks/post-boot.d/cllpse-bar-layout.sh"
  mkdir -p ~/.config/omarchy/hooks/post-boot.d
  ln -sfn "$HERE/hooks/post-boot.d/cllpse-bar-layout.sh" \
    ~/.config/omarchy/hooks/post-boot.d/cllpse-bar-layout.sh
fi

