#!/bin/bash
# Orca: both themes' terminal palettes as Warp themes, for Orca's Warp import
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads the same as in the other steps.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

TPL="$HERE/orca/warp-theme.yaml.tpl"
# The folder Orca's "Import from Warp" scans on Linux, $XDG_DATA_HOME first.
OUT="${XDG_DATA_HOME:-$HOME/.local/share}/warp-terminal/themes"

# Render the template from one theme's colors.toml. Every key it names must
# resolve to a hex colour, or nothing is written: a half-filled theme would
# import with Orca's defaults in the gaps and look almost right.
render() { # $1 theme folder  $2 name shown in Orca  $3 output file
  local colors="$REPO/$1/colors.toml" k v details tmp script
  local -A C=()
  [[ -f $colors ]] || { skip "$1/colors.toml missing — no Orca theme for it"; return 0; }
  while IFS=$'\t' read -r k v; do C[$k]=$v; done \
    < <(omarchy-theme-color --file "$colors" --all)

  # Warp's own light/dark word. Orca reads the mode off the background instead
  # and falls back to this only when there is none.
  case "${C[mode]:-}" in light) details=lighter ;; dark) details=darker ;;
    *) skip "$1: mode '${C[mode]:-}' is neither light nor dark — left $3 alone"; return 0 ;;
  esac

  script="s|{{ theme_source }}|$1/colors.toml|g
s|{{ theme_name }}|$2|g
s|{{ theme_details }}|$details|g"
  while read -r k; do
    v=${C[$k]:-}
    [[ $v =~ ^#[0-9A-Fa-f]{6}$ ]] || {
      skip "$1: '$k' is not a hex colour ('$v') — left $3 alone"; return 0
    }
    script+=$'\n'"s|{{ $k }}|$v|g"
  done < <(grep -o '{{ [a-z_]* }}' "$TPL" | sed 's/^{{ //; s/ }}$//' | grep -v '^theme_' | sort -u)

  tmp=$(mktemp "$OUT/.$(basename "$3").XXXXXX")
  sed -e "$script" "$TPL" >"$tmp"

  # Orca keeps a copy at import, so a changed file reaches it only through
  # another import. Same file name, same id: the import replaces it in place.
  if cmp -s "$tmp" "$3"; then
    rm -f "$tmp"; skip "$(basename "$3"): unchanged"
  else
    [[ -f $3 ]] && skip "$(basename "$3"): changed — import it again in Orca"
    chmod 644 "$tmp"; mv -f "$tmp" "$3"
  fi
}

# See README.md. Orca the IDE keeps its profiles here; the GNOME screen reader
# of the same name lives in ~/.local/share/orca, so `command -v orca` would not do.
if [[ -d ~/.config/orca/profiles ]]; then
  say "Orca -> $OUT/cllpse-macos-{light,dark}.yaml (Warp themes, Ghostty's palette)"
  mkdir -p "$OUT"
  render omarchy-cllpse-theme-light "cllpse-macos Light" "$OUT/cllpse-macos-light.yaml"
  render omarchy-cllpse-theme-dark  "cllpse-macos Dark"  "$OUT/cllpse-macos-dark.yaml"
  skip "in Orca: Terminal Themes > Import from Warp, then one per Theme Mode (orca/README.md)"
else
  skip "Orca not found (~/.config/orca/profiles) — skipped its Warp themes"
fi
