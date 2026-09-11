#!/bin/bash
# Repaint Cursor's window chrome from the active Omarchy theme, on every
# `omarchy theme set`.
#
# The colour theme itself is Bearded (see cursor/settings.json), chosen for its
# editor and syntax colours. What Bearded also brings is its own window chrome,
# which steps through greys -- titleBar #d2d2d2, activityBar/sideBar #ebebeb,
# statusBar #f4f4f4 on the light variant -- while every other window on this
# desktop sits on the theme's flat window background (#FFFFFF light, #1E1E1E
# dark). So the editor reads as a foreign window.
#
# `workbench.colorCustomizations` sits ABOVE the active theme and can be scoped
# per theme, which is the only lever that reaches this without forking Bearded.
# The values come from Omarchy's own generated VS Code theme
# (~/.local/state/omarchy/current/theme/vscode-theme.json, 664 keys, rebuilt
# from colors.toml on every theme-set) so the chrome is exactly what the Omarchy
# extension would have painted -- no second derivation of the palette to drift.
#
# CHROME ONLY. The editor pane, widgets, lists and terminal are left to Bearded;
# only the frame around them is taken over. Widening that is a matter of adding
# prefixes to $CHROME below -- the whole `colors` object is available.
#
# The two scopes are read from the settings file rather than hardcoded, so the
# Bearded variant names live in exactly one place (cursor/settings.json). Both
# scopes get the CURRENT palette, which is correct at all times: only one is
# ever active, and the one that is active always matches the Omarchy mode that
# selected it, because `window.autoDetectColorScheme` keys off the same signal.
set -euo pipefail

THEME="$HOME/.local/state/omarchy/current/theme/vscode-theme.json"
SETTINGS="$HOME/.config/Cursor/User/settings.json"

[[ -f $THEME ]] || exit 0
[[ -f $SETTINGS ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# A settings.json Cursor has written with comments or trailing commas is not
# ours to rewrite -- same guard apply.sh uses for the merge.
jq -e . "$SETTINGS" >/dev/null 2>&1 || {
  printf 'cursor-chrome.sh: settings.json is not plain JSON — left untouched\n' >&2
  exit 0
}
jq -e . "$THEME" >/dev/null 2>&1 || exit 0

CHROME='["titleBar.","activityBar","sideBar","statusBar","editorGroupHeader.","tab.","panel","menu","commandCenter.","toolbar.","banner.","breadcrumb"]'

# Keys forced on top of whatever Omarchy painted, where its value isn't wanted.
#
# tab.activeBorderTop is the accent line drawn ABOVE the active tab (Omarchy
# puts the theme accent there, #007AFF). Transparent rather than deleted: drop
# the key and Bearded's own value shows through instead, since colorCustomizations
# only overrides what it names. VS Code reads 8-digit #RRGGBBAA, so the trailing
# 00 is zero alpha -- the same form Omarchy's own file uses for its #007AFF20
# washes.
#
# tab.unfocusedActiveBorderTop is the SAME line while the editor group is
# unfocused (Omarchy: #BDBDBD). Left alone it would reappear in grey whenever
# focus moved to the terminal or another group, so it goes too.
#
# tab.hoverBorder is the line drawn under a tab while the pointer is over it
# (Omarchy: #007AFF40), so a tab's bottom edge changed on hover. Its unfocused
# twin needs no entry: VS Code derives tab.unfocusedHoverBorder from this one,
# and neither Omarchy nor Bearded sets it explicitly (checked). tab.hoverBackground
# is deliberately left alone -- only the border was unwanted.
FORCE='{"tab.activeBorderTop":"#00000000","tab.unfocusedActiveBorderTop":"#00000000","tab.hoverBorder":"#00000000"}'

# Derived afterwards, so it follows whatever the active theme paints rather than
# being pinned: the active tab's bottom border takes the tab HOVER colour
# instead of Omarchy's accent (#007AFF), so the selected tab is marked with the
# same restraint as a hovered one rather than a saturated blue edge.

tmp=$(mktemp)
if ! jq --slurpfile t "$THEME" --argjson pre "$CHROME" --argjson force "$FORCE" '
      . as $set
      | (($t[0].colors // {})
         | with_entries(select(.key as $k | any($pre[]; . as $p | $k | startswith($p))))
         + $force
         | .["tab.activeBorder"] = (.["tab.hoverBackground"] // .["tab.activeBorder"])) as $chrome
      | ( [ $set["workbench.preferredLightColorTheme"],
            $set["workbench.preferredDarkColorTheme"] ] | map(select(type == "string")) ) as $themes
      | if ($themes | length) == 0 or ($chrome | length) == 0 then $set
        else
          $set
          + { "workbench.colorCustomizations":
              (($set["workbench.colorCustomizations"] // {})
               + ($themes | map({ key: ("[" + . + "]"), value: $chrome }) | from_entries)) }
        end
    ' "$SETTINGS" >"$tmp"; then
  rm -f "$tmp"
  printf 'cursor-chrome.sh: jq failed — left %s untouched\n' "$SETTINGS" >&2
  exit 1
fi

# Never let a failed rewrite truncate a real settings file.
[[ -s $tmp ]] && jq -e . "$tmp" >/dev/null 2>&1 || {
  rm -f "$tmp"
  printf 'cursor-chrome.sh: refusing to write invalid JSON — left %s untouched\n' "$SETTINGS" >&2
  exit 1
}

cat "$tmp" >"$SETTINGS"
rm -f "$tmp"
