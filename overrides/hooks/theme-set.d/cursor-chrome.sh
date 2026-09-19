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

# The active Bearded variant's own JSON, resolved through the extension's
# package.json (label -> path). It is needed for one thing only: the three
# colour families Cursor registers that Omarchy has no key for (see the
# re-tint below), where the alpha has to come from whatever the theme itself
# painted. Absent -- no extension, a renamed variant, a future layout -- the
# re-tint is skipped and those families keep their own colours, which is
# exactly what they did before.
BEARDED=""
_bext=$(ls -d "$HOME"/.cursor/extensions/beardedbear.beardedtheme-* 2>/dev/null | sort | tail -1 || true)

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

# WHAT COMES FROM OMARCHY, AND WHAT STAYS BEARDED.
#
# The boundary used to be a list of chrome prefixes -- the frame, plus the
# surfaces that float over it -- with everything else left to Bearded. That
# left the two palettes meeting inside single widgets, and the seams were
# visible rather than theoretical: the active sidebar-toggle chip was opaque
# `muted` while the active editor tab beside it was a 25% wash of the same
# colour, every text field was Bearded's blue-tinted #202027 against the flat
# neutral window, and Bearded's cyan/teal/gold turned up in accent roles
# (badge, button, progress bar, focus ring, list selection, links) on a desktop
# whose accent is #007AFF everywhere else.
#
# So the rule is inverted: EVERY key Omarchy paints is taken, except the editor
# CANVAS and the things drawn on it, which is what Bearded was chosen for in
# the first place. $KEEP is that exception list, and it is the only thing to
# edit when a surface is on the wrong side -- adding a prefix hands it back to
# Bearded, removing one takes it over.
#
# What KEEP holds, and why each entry is canvas rather than chrome:
#   editor.            the code area itself -- selection, find matches, word
#                      and range highlights, the current-line wash, folded
#                      regions. editor.background is pulled back out below.
#   editorBracket*     bracket pair colours and their guides: syntax.
#   editorIndentGuide. editorWhitespace. editorRuler. editorCodeLens.
#   editorLineNumber.  editorGhostText. editorInlayHint. editorLink.
#   editorUnnecessaryCode. editorHint.   all drawn among the glyphs.
#   editorCursor. terminalCursor.        the caret pair (their *.background is
#                      the character drawn ON the cursor, so the pair inverts).
#   symbolIcon. debugTokenExpression.    token-coloured symbol lists; they read
#                      as syntax wherever they appear.
#   editorOverviewRuler. minimap*        the miniature of the canvas -- these
#                      have to agree with the canvas, not with the frame.
#
# Everything else -- inputs, dropdowns, checkboxes, buttons, badges, progress
# bars, lists and trees, scrollbars, notifications, peek view, settings, the
# welcome page, git decorations, diff and merge, the integrated terminal's ANSI
# set, and the whole window frame that was here before -- now comes from
# Omarchy's generated theme, so it is the same palette the rest of the desktop
# is painted from.
#
# The integrated terminal is the one entry worth re-reading later: its ANSI
# colours are Omarchy's now, which matches Ghostty, btop and everything else
# themed here, and differs from the editor's own syntax palette by design. Add
# "terminal.ansi" to $KEEP to hand it back to Bearded.
KEEP='["editor.","editorBracket","editorIndentGuide.","editorWhitespace.","editorRuler.","editorCodeLens.","editorLineNumber.","editorCursor.","terminalCursor.","editorGhostText.","editorInlayHint.","editorUnnecessaryCode.","editorLink.","editorHint.","symbolIcon.","debugTokenExpression.","editorOverviewRuler.","minimap"]'

# Keys taken from Omarchy even though $KEEP covers them.
#
# editor.background is the big one: Bearded paints it #f4f4f4 against the
# window`s #FFFFFF, so the editor sat as a visible panel inside the window
# instead of being the window.
#
# editorGutter.background is no longer needed here -- editorGutter. is not in
# $KEEP, so the whole group comes from Omarchy with everything else -- but it
# is left named for the record: it has to agree with editor.background, and
# Bearded sets it explicitly to the same grey.
#
# The neighbouring surfaces (editorPane, editorGroup.emptyBackground,
# editorStickyScroll) need no entry: Bearded leaves them unset and VS Code
# derives them from editor.background, which is ours (checked).
# minimap.background is the third: the minimap strip is part of the canvas, so
# the group stays in $KEEP for its highlight marks, but Bearded paints the
# strip itself #25292D -- a blue-grey column against a #1E1E1E editor. Same
# argument as the gutter: the SURFACE is the editor, the marks on it are not.
EXACT='["editor.background","editorGutter.background","minimap.background"]'

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


if [[ -n $_bext && -f $_bext/package.json ]] && command -v jq >/dev/null 2>&1; then
  _mode=$(jq -r '.type // "light"' "$THEME")
  _label=$(jq -r --arg m "$_mode" \
    'if $m == "dark" then .["workbench.preferredDarkColorTheme"]
     else .["workbench.preferredLightColorTheme"] end // empty' "$SETTINGS")
  if [[ -n $_label ]]; then
    _rel=$(jq -r --arg l "$_label" \
      '.contributes.themes[] | select(.label == $l) | .path' "$_bext/package.json" | head -1)
    [[ -n $_rel ]] && [[ -f $_bext/${_rel#./} ]] && BEARDED="$_bext/${_rel#./}"
  fi
fi

tmp=$(mktemp)
# Dark only: in light mode the scheme IS Bearded Theme Light, so there is
# nothing to derive.
derived='{}'
# The active Bearded variant's own colors object, for the re-tint's alphas.
bearded='{}'
if [[ -n $BEARDED ]] && jq -e . "$BEARDED" >/dev/null 2>&1; then
  bearded="$(jq -c '.colors // {}' "$BEARDED")"
fi
if [[ -f $DERIVED ]] && jq -e . "$DERIVED" >/dev/null 2>&1 &&
   [[ $(jq -r '.type // "light"' "$THEME") == dark ]]; then
  derived="$(<"$DERIVED")"
fi

if ! jq --slurpfile t "$THEME" --argjson keep "$KEEP" --argjson exact "$EXACT" --argjson force "$FORCE" \
       --arg shadow_light "$SHADOW_LIGHT" --arg shadow_dark "$SHADOW_DARK" \
       --argjson derived "$derived" --argjson bearded "$bearded" '
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
      # Swap a colour hue for one of ours while KEEPING the alpha the theme
      # gave it, so a wash stays a wash and a solid stays solid.
      def retint($src): . as $cur
                | if $cur == null or $src == null then $cur
                  else ($src[0:7]
                        + (if ($cur | ltrimstr("#") | length) >= 8
                           then ($cur | ltrimstr("#"))[6:8] else "" end))
                  end;
      # Alpha byte of "#RRGGBBAA" (255 when the colour is 6-digit).
      def alpha_of: if . == null then 255
                    elif (ltrimstr("#") | length) >= 8 then (.[7:9] | hx2i)
                    else 255 end;
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
             | ((any($keep[]; . as $p | $k | startswith($p))) | not)
               or ($exact | index($k) != null)))
         + $force
         # ONE WASH FOR EVERY HOVER/ACTIVE STATE.
         #
         # Omarchy paints its state backgrounds three different weights, and
         # two of them are wrong next to the active tab: `{{ background }}`,
         # which is the window colour and therefore no feedback at all
         # (toolbar.hoverBackground, list.hoverBackground,
         # button.secondaryHoverBackground, settings.rowHoverBackground), and
         # opaque `{{ muted }}`, which is far heavier than anything else that
         # marks a selection (toolbar.activeBackground -- the sidebar-toggle
         # chip -- commandCenter.activeBackground, inputOption.hoverBackground,
         # statusBarItem.activeBackground and its compact hover).
         # statusBarItem.hoverBackground is a third weight again, muted at 38%.
         #
         # All of them are rewritten to the tab wash, so "this thing is hovered
         # or active" is one colour across the whole window. The test is
         # mechanical rather than a key list: a state background is wrong if it
         # is the window colour, or if it is muted at an alpha ABOVE the wash
         # -- which catches the opaque case, the 38% case and anything Omarchy
         # adds later, while leaving alone the states that already sit at the
         # wash or below it, and every state painted in the accent.
         #
         # Five prefixes are excluded, and the reason splits in two.
         #
         # tab.* and titleBar.* are surfaces: the tab pair is derived just
         # below, and tab.inactiveBackground and titleBar.*Background are
         # supposed to BE the window colour.
         #
         # scrollbarSlider., extensionButton. and button. own a solid surface
         # of their own, so their hover is a relationship to THAT, not to the
         # window -- and the wash would inverted it. Measured before excluding
         # them: the slider rests at muted 25% and hovers at 50%, so washing
         # the hover made hover and rest identical and the feedback vanished;
         # the extension button rests at opaque muted and hovers at 50%, so the
         # wash made a hovered button LIGHTER than an idle one.
         # The one real bug among them is handled on its own below.
         | (.["tab.hoverBackground"] // "#00000000") as $wash
         | ($wash | alpha_of) as $washa
         | (.["editor.background"] // "#000000" | ascii_downcase) as $bgl
         | ($muted // "#000000" | ascii_downcase) as $mutedl
         | reduce (keys_unsorted[]
                   | . as $k
                   | select($k | test("(?i)(hover|active|selection|focus)background$"))
                   | select([ "tab.", "titleBar.", "scrollbarSlider.",
                              "extensionButton.", "button." ]
                            | any(. as $p | $k | startswith($p)) | not)
                  ) as $k (.;
               (.[$k] | ascii_downcase) as $v
               | if $v == $bgl
                    or (($v | startswith($mutedl)) and (.[$k] | alpha_of) > $washa)
                 then .[$k] = $wash else . end)
         # A secondary button is opaque muted, and Omarchy paints its hover
         # the window colour -- so hovering one made it vanish into the
         # background rather than respond. Omarchy own vocabulary for the
         # hover of a solid surface is that surface at 80% alpha (that is what
         # statusBarItem.prominentHoverBackground, .errorHoverBackground and
         # .remoteHoverBackground all are), so the same relationship is used
         # here rather than a new constant. Conditional, so if Omarchy ever
         # gives the key a real value, that value is kept.
         | (if (.["button.secondaryHoverBackground"] // "" | ascii_downcase) == $bgl
            then .["button.secondaryHoverBackground"] =
                   ((.["button.secondaryBackground"] // $muted) + "80")
            else . end)
         # IDS OMARCHY DOES NOT DEFINE.
         #
         # Cursor registers a handful of colours that are in neither palette,
         # so they fall through to Bearded (or to the dark derivation of it)
         # and keep their tint no matter what is copied above. Only the ones
         # that read as chrome are set; the rest -- scmGraph. (git graph
         # strands), inlineEdit. (Cursor tab-completion diffs) and errorLens.
         # (an extension) are semantic or syntax-like and are left alone.
         #
         # profileBadge is the visible one: a teal dot against a window whose
         # every other badge is the accent.
         | .["profileBadge.background"] = (.["badge.background"] // .["profileBadge.background"])
         | .["profileBadge.foreground"] = (.["badge.foreground"] // .["profileBadge.foreground"])
         | .["multiDiffEditor.headerBackground"] = (.["editor.background"] // .["multiDiffEditor.headerBackground"])
         | .["multiDiffEditor.border"] = ($muted // .["multiDiffEditor.border"])
         | .["diffEditor.border"] = ($muted // .["diffEditor.border"])
         | .["button.separator"] = ($muted // .["button.separator"])
         | .["peekViewEditorStickyScroll.background"] = (.["editor.background"] // .["peekViewEditorStickyScroll.background"])
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
      | (($derived + $chrome)
      # THREE FAMILIES CURSOR REGISTERS THAT OMARCHY HAS NEVER HEARD OF.
      #
      # inlineEdit. (Cursor tab-completion diffs), scmGraph. (the git graph
      # strands and ref chips) and errorLens. (the extension) have no key in
      # Omarchy generated theme at all, so nothing above touches them and
      # they keep whatever Bearded or the dark derivation left: pink-red
      # #EA4D4D deletions, mint #98FFAE insertions, a gold tab indicator, a
      # teal one, and five graph strands in Bearded own hues.
      #
      # They are semantic rather than structural, so they are RE-TINTED
      # instead of being pinned: each one takes the hue of the matching
      # Omarchy chart colour and keeps the alpha the theme gave it, so a 15%
      # wash stays a 15% wash and only the hue moves onto the palette the
      # rest of the desktop uses. charts.* is the right source row because
      # it is the palette own set of distinguishable hues, already copied
      # above, and it tracks colors.toml like everything else here.
      #
      # The two indicator foregrounds go to badge.foreground, which is what
      # Omarchy paints text ON an accent-coloured chip.
               # The alpha comes from the ACTIVE Bearded variant itself (read above),
      # falling back to the dark derivation, so a 15% wash stays a 15% wash in
      # BOTH modes -- these ids are not in Omarchy file, so there is no value
      # of ours to take the shape from. With neither source readable the key is
      # left exactly as it was.
| ({ "inlineEdit.modifiedBackground":            "charts.green",
   "inlineEdit.modifiedBorder":                "charts.green",
   "inlineEdit.modifiedChangedLineBackground": "charts.green",
   "inlineEdit.modifiedChangedTextBackground": "charts.green",
   "inlineEdit.tabWillAcceptModifiedBorder":   "charts.green",
   "inlineEdit.originalBackground":            "charts.red",
   "inlineEdit.originalBorder":                "charts.red",
   "inlineEdit.originalChangedLineBackground": "charts.red",
   "inlineEdit.originalChangedTextBackground": "charts.red",
   "inlineEdit.tabWillAcceptOriginalBorder":   "charts.red",
   "inlineEdit.gutterIndicator.primaryBackground":     "charts.yellow",
   "inlineEdit.gutterIndicator.primaryBorder":         "charts.yellow",
   "inlineEdit.gutterIndicator.secondaryBackground":   "charts.blue",
   "inlineEdit.gutterIndicator.secondaryBorder":       "charts.blue",
   "inlineEdit.gutterIndicator.successfulBackground":  "charts.green",
   "inlineEdit.gutterIndicator.successfulBorder":      "charts.green",
   "inlineEdit.gutterIndicator.primaryForeground":     "badge.foreground",
   "inlineEdit.gutterIndicator.secondaryForeground":   "badge.foreground",
   "inlineEdit.gutterIndicator.successfulForeground":  "badge.foreground",
   "errorLens.errorForeground":   "charts.red",
   "errorLens.warningForeground": "charts.yellow",
   "errorLens.infoForeground":    "charts.blue",
   "errorLens.hintForeground":    "charts.blue",
   "scmGraph.foreground1": "charts.blue",
   "scmGraph.foreground2": "charts.purple",
   "scmGraph.foreground3": "charts.green",
   "scmGraph.foreground4": "charts.orange",
   "scmGraph.foreground5": "charts.red",
   "scmGraph.historyItemRefColor":       "charts.yellow",
   "scmGraph.historyItemRemoteRefColor": "charts.blue",
   "scmGraph.historyItemBaseRefColor":   "charts.purple",
   "scmGraph.historyItemHoverAdditionsForeground": "charts.green",
   "scmGraph.historyItemHoverDeletionsForeground": "charts.red",
   "scmGraph.historyItemHoverLabelForeground":     "charts.foreground",
   "scmGraph.historyItemHoverDefaultLabelForeground": "charts.foreground",
   "scmGraph.historyItemHoverDefaultLabelBackground": "charts.lines"
            }) as $retint      | . as $c
      | reduce ($retint | keys_unsorted[]) as $k ($c;
            (($bearded[$k]) // ($derived[$k])) as $cur
            | if $cur != null and ($c[$retint[$k]] != null)
              then .[$k] = ($cur | retint($c[$retint[$k]]))
              else . end)
        ) as $chrome
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
