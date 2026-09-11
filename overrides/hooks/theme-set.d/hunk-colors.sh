#!/bin/bash
# Regenerate ~/.config/hunk/config.toml from overrides/hunk/config.toml.tpl
# whenever the active Omarchy theme changes.
#
# Same shape, and the same reason, as the starship hook next to this one: hunk
# is not an app omarchy-theme-set-templates knows about, and it has no config
# "import" directive that could point at a themed file under
# ~/.local/state/omarchy/current/theme/. Unlike the other TUIs in overrides/, it
# also cannot be pointed at the terminal's ANSI palette at all -- its theme
# validator takes hex only ("must be a hex color like #112233"), and every
# built-in theme id is a bundled Shiki theme rather than a terminal-derived one.
# So the palette is baked in here, on every theme-set, instead of being resolved
# by the terminal at render time.
#
# Writes the file WHOLE, like the starship hook -- so any non-theme hunk key a
# user adds by hand (mode, tab_width, sidebar, ...) is lost at the next theme
# switch. apply.sh backs the file up once before the first run.
set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
TEMPLATE="$HERE/../../hunk/config.toml.tpl"
COLORS="$HOME/.local/state/omarchy/current/theme/colors.toml"
TARGET="$HOME/.config/hunk/config.toml"

[[ -f $TEMPLATE ]] || exit 0
[[ -f $COLORS ]] || exit 0

# Read one key out of the active palette. Same helper the starship hook uses.
pick() { omarchy-theme-color --file "$COLORS" "$1" 2>/dev/null || true; }

# Mix $1 over $2 at $3 percent, in sRGB. hunk paints these behind body text, so
# the raw system hue is unusable at full strength -- see the template.
blend() { # $1 hue  $2 base  $3 percent
  local a=${1#\#} b=${2#\#} p=$3
  printf '#%02X%02X%02X' \
    $(( (16#${a:0:2} * p + 16#${b:0:2} * (100 - p)) / 100 )) \
    $(( (16#${a:2:2} * p + 16#${b:2:2} * (100 - p)) / 100 )) \
    $(( (16#${a:4:2} * p + 16#${b:4:2} * (100 - p)) / 100 ))
}

declare -A C=()
for k in mode accent selection muted background dark_background lighter_background \
         foreground dark_foreground red green yellow blue magenta cyan; do
  C[$k]="$(pick "$k")"
done

# Anything missing means a palette this template can't fill; leave the existing
# config alone rather than writing a half-themed one.
for k in accent selection muted background dark_background lighter_background \
         foreground dark_foreground red green yellow blue magenta cyan; do
  [[ ${C[$k]} =~ ^#[0-9A-Fa-f]{6}$ ]] || exit 0
done

# Shiki has no terminal-following theme, so the most this can do is follow the
# light/dark signal -- the same `mode` key that drives GTK, VS Code and Claude.
if [[ ${C[mode]:-dark} == light ]]; then
  C[base]="github-light-default"
else
  C[base]="github-dark-default"
fi

C[added_bg]="$(blend "${C[green]}"   "${C[background]}" 18)"
C[added_content_bg]="$(blend "${C[green]}" "${C[background]}" 30)"
C[removed_bg]="$(blend "${C[red]}"   "${C[background]}" 18)"
C[removed_content_bg]="$(blend "${C[red]}" "${C[background]}" 30)"
C[moved_added_bg]="$(blend "${C[cyan]}"    "${C[background]}" 18)"
C[moved_removed_bg]="$(blend "${C[magenta]}" "${C[background]}" 18)"
C[selected_hunk]="$(blend "${C[accent]}"   "${C[background]}" 22)"

out="$(cat "$TEMPLATE")"
for k in "${!C[@]}"; do
  out="${out//\{\{ $k \}\}/${C[$k]}}"
done

# A leftover placeholder means the template grew a key this hook doesn't fill.
# Writing it would hand hunk a literal "{{ foo }}" where it wants hex, so stop.
if [[ $out == *'{{'* ]]; then
  printf 'hunk-colors.sh: unfilled placeholder in template — left %s untouched\n' "$TARGET" >&2
  exit 1
fi

mkdir -p "${TARGET%/*}"
printf '%s\n' "$out" >"$TARGET"
