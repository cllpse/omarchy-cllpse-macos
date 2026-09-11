#!/bin/bash
# Regenerate ~/.config/yazi/cllpse-macos.tmTheme from
# overrides/yazi/cllpse-macos.tmTheme.tpl on every `omarchy theme set`.
#
# Third hook of this shape, after starship and hunk, and for the same reason:
# yazi's previewer highlights through syntect, syntect reads a TextMate
# .tmTheme, and a .tmTheme holds literal hex only.
#
# Note this one is a deliberate TRADE, not a repair. Left without a
# syntect_theme, yazi highlights in the terminal's ANSI palette and tracks a
# theme switch live (measured: keywords `35m`, strings `32m`, zero truecolor).
# Pointing it at this file swaps that for the full macOS palette -- more hues
# than ANSI's 16 slots, Xcode's project-vs-system symbol split -- at the cost of
# only updating when a theme-set runs. That is the trade the config asked for;
# deleting `syntect_theme` from yazi/theme.toml reverts to the ANSI behaviour.
set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
TEMPLATE="$HERE/../../yazi/cllpse-macos.tmTheme.tpl"
COLORS="$HOME/.local/state/omarchy/current/theme/colors.toml"
TARGET="$HOME/.config/yazi/cllpse-macos.tmTheme"

[[ -f $TEMPLATE ]] || exit 0
[[ -f $COLORS ]] || exit 0

pick() { omarchy-theme-color --file "$COLORS" "$1" 2>/dev/null || true; }

# Raise a hue until it is readable against the background, and return it as hex.
#
# This exists for the LIGHT theme. Its system hues are macOS aqua-appearance
# colours meant for UI fills, not text: systemYellow #FFCC00 on the #FFFFFF
# window background is a contrast ratio of about 1.3:1, i.e. invisible as code.
# The dark theme mostly clears the bar already, so on that side this is close to
# a no-op -- which is the point, it corrects only what needs it rather than
# flattening the palette everywhere.
#
# Mixes toward black (on a light background) or white (on a dark one) in 2%
# steps until WCAG contrast reaches $3, giving up at 100% rather than looping.
# awk because the sRGB->luminance transfer is a real pow(), which bash cannot
# do; awk's exp/log stand in for it.
readable() { # $1 hue  $2 background  $3 target ratio
  awk -v hue="${1#\#}" -v bg="${2#\#}" -v target="$3" '
    function hex(s, i) { return strtonum("0x" substr(s, i, 2)) }
    function chan(c,   v) { v = c / 255
      return (v <= 0.03928) ? v / 12.92 : exp(2.4 * log((v + 0.055) / 1.055)) }
    function lum(r, g, b) { return 0.2126*chan(r) + 0.7152*chan(g) + 0.0722*chan(b) }
    function ratio(l1, l2) { return (l1 > l2) ? (l1+0.05)/(l2+0.05) : (l2+0.05)/(l1+0.05) }
    BEGIN {
      hr = hex(hue,1); hg = hex(hue,3); hb = hex(hue,5)
      br = hex(bg,1);  bg_ = hex(bg,3); bb = hex(bg,5)
      blum = lum(br, bg_, bb)
      # Mix toward whichever end is away from the background.
      t = (blum > 0.5) ? 0 : 255
      for (p = 0; p <= 100; p += 2) {
        r = hr + (t - hr) * p / 100
        g = hg + (t - hg) * p / 100
        b = hb + (t - hb) * p / 100
        if (ratio(lum(r, g, b), blum) >= target) break
      }
      printf "#%02X%02X%02X", r, g, b
    }'
}

declare -A C=()
for k in mode background dark_background lighter_background foreground dark_foreground \
         accent selection red yellow orange green cyan blue magenta; do
  C[$k]="$(pick "$k")"
done

for k in background foreground dark_foreground accent selection \
         red yellow orange green cyan magenta; do
  [[ ${C[$k]} =~ ^#[0-9A-Fa-f]{6}$ ]] || exit 0
done

bg="${C[background]}"

# macOS has no surface lighter than white, so in light mode lighter_background
# collapses onto background and the current-line band would be invisible. Step
# the other way there -- the same choice bash/shell.sh makes for fzf's selected
# row, and the theme's own shell.launcher.toml for its selected background.
if [[ ${C[mode]:-dark} == light ]]; then
  C[line_highlight]="${C[dark_background]:-$bg}"
else
  C[line_highlight]="${C[lighter_background]:-$bg}"
fi

# Xcode's assignment, in this palette. Comments are held to a lower bar on
# purpose: they are meant to recede, and forcing them to body-text contrast
# defeats that.
C[comment]="$(readable "${C[dark_foreground]}" "$bg" 3.0)"
C[string]="$(readable "${C[red]}"     "$bg" 4.5)"
C[number]="$(readable "${C[yellow]}"  "$bg" 4.5)"
C[keyword]="$(readable "${C[magenta]}" "$bg" 4.5)"
C[project_symbol]="$(readable "${C[cyan]}"  "$bg" 4.5)"
C[system_symbol]="$(readable "${C[magenta]}" "$bg" 4.5)"
C[preprocessor]="$(readable "${C[orange]}"  "$bg" 4.5)"
C[regexp]="$(readable "${C[orange]}"  "$bg" 4.5)"
C[inserted]="$(readable "${C[green]}" "$bg" 4.5)"
C[invalid]="$(readable "${C[red]}"    "$bg" 4.5)"
C[accent]="$(readable "${C[accent]}"  "$bg" 4.5)"

out="$(cat "$TEMPLATE")"
for k in "${!C[@]}"; do
  out="${out//\{\{ $k \}\}/${C[$k]}}"
done

if [[ $out == *'{{'* ]]; then
  printf 'yazi-syntax.sh: unfilled placeholder in template — left %s untouched\n' "$TARGET" >&2
  exit 1
fi

mkdir -p "${TARGET%/*}"
printf '%s\n' "$out" >"$TARGET"
