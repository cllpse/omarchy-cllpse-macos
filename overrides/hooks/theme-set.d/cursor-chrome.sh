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
# CHROME, plus the surfaces that float ON TOP of the window. The editor pane,
# lists, inputs and terminal are left to Bearded; the frame, and anything drawn
# over it, are taken over. Widening that is a matter of adding prefixes to
# $CHROME below -- the whole `colors` object is available.
#
# The two scopes are read from the settings file rather than hardcoded, so the
# Bearded variant names live in exactly one place (cursor/settings.json). Both
# scopes get the CURRENT palette, which is correct at all times: only one is
# ever active, and the one that is active always matches the Omarchy mode that
# selected it, because `window.autoDetectColorScheme` keys off the same signal.
set -euo pipefail

THEME="$HOME/.local/state/omarchy/current/theme/vscode-theme.json"
SETTINGS="$HOME/.config/Cursor/User/settings.json"

# The dark counterpart of Bearded Theme Light, derived by
# cursor/derive-dark-from-light.py -- the editor-area colours only, since the
# chrome is taken from Omarchy below and wins over these. Resolved through this
# script's own symlink, because a hook runs from ~/.config/omarchy/hooks/.
# Absent (or an older checkout) simply means dark mode keeps whatever the
# Bearded dark variant paints, which is what it did before this existed.
DERIVED="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../cursor/bearded-dark-colors.json"

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

# The last four are the overlay group: the quick input (SUPER+P and
# SUPER+SHIFT+P are the same widget), the group separator and label inside it,
# both hover widgets -- `.monaco-hover` in the editor and `.workbench-hover`
# over tabs and the sidebar read the same editorHoverWidget.* vars -- and the
# keybinding chips those two surfaces render. An overlay sits over the window
# and should look like it belongs to it; Bearded paints a tooltip #c9ced2 grey
# against a #FFFFFF window, with teal keybinding chips.
#
# Three neighbours are deliberately NOT here. `list.` would repaint every tree
# in the workbench for the sake of the picker's rows, and Omarchy's own
# list.hoverBackground is the window background -- taking it would cost the
# hover feedback Bearded has. `input.` reaches the find widget, the settings
# search and the SCM box for a #f9f9fa-vs-#FFFFFF difference inside the picker's
# own field. `editorSuggestWidget.` is completion, which is syntax-adjacent and
# belongs with the colours Bearded was chosen for.
CHROME='["titleBar.","activityBar","sideBar","statusBar","editorGroupHeader.","tab.","panel","menu","commandCenter.","toolbar.","banner.","breadcrumb","quickInput","pickerGroup.","editorHoverWidget.","keybindingLabel."]'

# Whole-key additions, for surfaces that are not chrome but must agree with it.
# The editor pane is the big one: Bearded paints it #f4f4f4 against the window's
# #FFFFFF, so the editor sat as a visible panel inside the window instead of
# being the window. Taking Omarchy's value makes the editor the window colour.
#
# editorGutter.background has to come too -- Bearded sets it explicitly to the
# same #f4f4f4, so on its own the gutter would stay grey against a white editor.
# The neighbouring surfaces (editorPane, editorGroup.emptyBackground,
# editorStickyScroll) need no entry: Bearded leaves them unset and VS Code
# derives them from editor.background, which is now ours (checked).
#
# Widgets, lists, the terminal and syntax stay Bearded -- this is the editor
# SURFACE, not the editor's contents.
EXACT='["editor.background","editorGutter.background"]'

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
# editor.lineHighlightBorder is the hairline box Bearded draws around the caret
# line -- #22a5c926 teal on the light variant, #c7910c26 gold on the dark one.
# It is the one border in the editor that is on screen at all times, and a
# coloured one on a desktop whose windows are otherwise flat. Omarchy has the
# same opinion: its own template pins the key to `{{ background }}00`, zero
# alpha. The literal lives here rather than in $EXACT so the intent reads as
# "no border" instead of "whatever alpha the palette lands on". The fill stays
# Bearded's -- editor.lineHighlightBackground is untouched, so the current line
# is still marked, by wash only, on the gutter too via
# `editor.renderLineHighlight: "all"` in cursor/settings.json.
#
# tab.border is the SEPARATOR between tabs, and it is the one edge here that is
# a real CSS border rather than an overlay div. Cursor sets it inline on every
# tab -- `borderRight = 1px solid ${tab.lastPinnedBorder || tab.border ||
# contrastBorder}` -- and Omarchy paints it the window colour, which is
# invisible against an inactive tab and a 1px white notch against a hovered or
# active one, now that those carry a wash.
#
# Transparent, not the tab colour: `.tabs-container > .tab` sets no
# background-clip, so the default border-box paints the tab's own background
# under its border, and box-sizing: border-box means the 1px is already inside
# the tab's width. So zero alpha shows whatever that particular tab is -- white
# when inactive, the wash when hovered or active -- with nothing to keep in sync
# and no reflow. Zero alpha rather than DELETING the key, because Cursor falls
# through to contrastBorder when the colour is undefined; a transparent colour
# is still defined, so the fallback does not fire.
#
# tab.lastPinnedBorder is deliberately left alone -- it marks where the pinned
# tabs end, which is information, not decoration.
#
# The three BOTTOM-edge keys are not here -- they are derived below, from the
# tab background, rather than pinned to a literal.
#
# editorHoverWidget.border is NOT forced here any more -- it follows the border
# token below, like every other managed edge.

# TWO TOKENS, because two is all the product exposes.
#
# Material 2's elevation scale was the target here and is not reachable: a 2dp
# or 6dp shadow is three stacked layers with their own offsets, blurs and
# spreads, and box-shadow geometry is CSS -- every surface's is hardcoded in
# workbench.desktop.main.css and no setting or colour id touches it. Border
# WIDTH is the same story: there is no *BorderWidth or *BorderSize key anywhere
# in the registry, and every edge in the product is 1px. What is themable is
# colour, so the system is one colour for every edge and one for every shadow,
# with each surface keeping the shadow SHAPE Cursor gave it.
#
# SHADOW token -- widget.shadow, and the ONE value here that cannot be shared
# between the two modes, because it is a literal rather than a palette entry.
# It is also the only shadow id not zeroed in cursor/settings.json, and it is
# worth knowing how far it reaches: Cursor derives --cursor-shadow-primary from
# this var and secondary/tertiary/workbench from color-mixes of it at 60/30/40%,
# so every --cursor-box-shadow-* composite takes its colour from here too -- the
# quick input among them, which Cursor forces onto box-shadow-xl. The editor
# hover takes nothing from it at all: `.monaco-editor .monaco-hover` has no
# box-shadow declaration, so its only edge is the border.
#
# LIGHT is black at 14%, Material's own penumbra alpha. On the #FFFFFF window
# that lands at #DBDBDB -- a 36/255 step, clearly readable.
#
# DARK cannot use the same number, and cannot be fixed by scaling it either.
# Against the #1E1E1E window:
#
#     14%  -> #1A1A1A   step  4/255   invisible
#     30%  -> #151515   step  9/255
#     35%  -> #141414   step 10/255   what ships
#    100%  -> #000000   step 30/255   the absolute ceiling
#
# against the light theme's 14% over #FFFFFF, which is a step of 36/255.
#
# A dark shadow simply has 30 levels of headroom where the light one has 255, so
# it can never carry the light theme's weight -- which is exactly why Material
# uses surface overlays on dark instead of shadows, and why Omarchy's own
# generated value for dark (#1E1E1E80, the background at half alpha) is
# invisible by construction. 35% is the practical floor for "present but not
# a smear", and matches what VS Code's own Dark Modern uses (#0000005c).
# Bearded's dark variants sit lower still, at #11100f30 and #00000033.
#
# The mode comes from the generated theme's own `type` key -- the same field
# Omarchy writes from the theme's `mode`, so it is the identical signal that
# picks which of the two Bearded variants is active in the first place. No
# second source of truth.
SHADOW_LIGHT='#00000024'
SHADOW_DARK='#00000059'

# The rest of $FORCE is mode-independent: all three are fully transparent, and
# zero alpha reads the same on any background.
FORCE='{"tab.activeBorderTop":"#00000000","tab.unfocusedActiveBorderTop":"#00000000","tab.border":"#00000000","editor.lineHighlightBorder":"#00000000"}'

# WHAT MARKS THE ACTIVE TAB, now that no tab has an underline: its background,
# set to exactly what an inactive tab shows under the pointer. Omarchy paints
# tab.activeBackground the window colour (#FFFFFF light, #1E1E1E dark) and
# tab.hoverBackground a 25% wash of muted (#BDBDBD40 / #56565640) -- so before
# this the selected tab was indistinguishable from the strip it sits in, and
# only the accent line said which one it was.
#
# Derived from the hover value rather than pinned in $FORCE so it tracks the
# theme's own muted, like every other managed value here. The wash composites
# over editorGroupHeader.tabsBackground, which is the window colour, so the
# result is byte-identical to what a hovered tab renders. The unfocused pair
# follows the same way: Omarchy gives the two hover keys the same value, but
# reading each from its own counterpart keeps them independent if that changes.

# BORDER token -- `muted`, read off textSeparator.foreground (a bare
# `{{ muted }}` in Omarchy's template) so it tracks the theme instead of being
# pinned: #BDBDBD light, #565656 dark, the same colour as the Hyprland window
# border. Every managed edge already resolves to it, because Omarchy's own
# *.border ids are muted and $CHROME copies them -- menu.border, pickerGroup,
# keybindingLabel, editorHoverWidget and the rest. The one that did NOT is
# widget.border, assigned below.
#
# widget.border is unclaimed by both themes (registered default null), so
# Cursor's composites were falling back to their own --cursor-stroke-tertiary.
# It is the `0 0 0 1px` ring inside all four --cursor-box-shadow-{sm,base,lg,xl}
# composites -- which is what draws the edge on the QUICK INPUT -- plus the find
# widget's side borders, simple-find-part, the marketplace menus, the
# announcement modal and the feedback pane. Setting it is what makes the command
# palette and the tooltips share one edge, which they never did before.


tmp=$(mktemp)
# Dark only: in light mode the scheme IS Bearded Theme Light, so there is
# nothing to derive.
derived='{}'
if [[ -f $DERIVED ]] && jq -e . "$DERIVED" >/dev/null 2>&1 &&
   [[ $(jq -r '.type // "light"' "$THEME") == dark ]]; then
  derived="$(<"$DERIVED")"
fi

if ! jq --slurpfile t "$THEME" --argjson pre "$CHROME" --argjson exact "$EXACT" --argjson force "$FORCE" \
       --arg shadow_light "$SHADOW_LIGHT" --arg shadow_dark "$SHADOW_DARK" \
       --argjson derived "$derived" '
      # Hex helpers, for the tab bottom edges below. jq has no printf %02x and
      # no hex literal parser, so both directions are spelled out.
      def hx2i: reduce (ascii_downcase | explode[]) as $c
                  (0; . * 16 + (if $c > 96 then $c - 87 else $c - 48 end));
      def i2hx: ("0123456789ABCDEF" | explode) as $D
                | [$D[(. / 16 | floor)], $D[. % 16]] | implode;
      # "#RRGGBB" or "#RRGGBBAA" -> [r, g, b, a] with a in 0..1.
      def rgba: ltrimstr("#")
                | (if length >= 8 then (.[6:8] | hx2i) / 255 else 1 end) as $a
                | [.[0:2], .[2:4], .[4:6]] | map(hx2i) | . + [$a];
      # Composite this colour over an opaque one and return the flat result.
      # Null in, null out, so a palette missing the key leaves the edge alone.
      def flatten_over($bg): if . == null or $bg == null then null
                else rgba as $f | ($bg | rgba) as $b
                  | [range(0; 3)
                     | (($f[.] * $f[3]) + ($b[.] * (1 - $f[3]))) | round]
                  | map(i2hx) | "#" + add
                end;
      . as $set
      | (($t[0].colors // {})["textSeparator.foreground"]) as $muted
      | (if ($t[0].type // "light") == "dark" then $shadow_dark else $shadow_light end) as $shadow
      | (($t[0].colors // {})
         | with_entries(select(.key as $k
             | any($pre[]; . as $p | $k | startswith($p)) or ($exact | index($k) != null)))
         + $force
         | (.["editorGroupHeader.tabsBackground"] // "#FFFFFF") as $strip
         | (.["tab.hoverBackground"] // .["tab.activeBackground"]) as $act
         | (.["tab.unfocusedHoverBackground"]
            // .["tab.unfocusedActiveBackground"]) as $uact
         | .["tab.activeBackground"] = ($act // .["tab.activeBackground"])
         | .["tab.unfocusedActiveBackground"] =
             ($uact // .["tab.unfocusedActiveBackground"])
         | .["tab.activeBorder"] =
             (($act | flatten_over($strip)) // .["tab.activeBorder"])
         | .["tab.hoverBorder"] =
             (($act | flatten_over($strip)) // .["tab.hoverBorder"])
         | .["tab.unfocusedActiveBorder"] =
             (($uact | flatten_over($strip)) // .["tab.unfocusedActiveBorder"])
         | .["widget.border"] = ($muted // .["widget.border"])
         | .["widget.shadow"] = $shadow) as $chrome
      # Derived editor-area colours go UNDERNEATH: every key the chrome copy
      # names wins, so the frame stays whatever Omarchy painted, and only what
      # the chrome does not claim -- editor surfaces, lists, inputs, terminal --
      # comes from the derivation. (No apostrophes in here: the whole jq program
      # is a single-quoted bash string, and one ends it.)
      | ($derived + $chrome) as $chrome
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
