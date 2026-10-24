#!/bin/bash
# SF Pro or SF Mono, upright and italic, as Nerd Font faces
#
# Rebuilds the SF faces one folder up from one of Apple's DMGs
# (developer.apple.com/fonts), whichever family it holds:
#
#   SF-Pro.dmg   the 16 SFPro{Text,Display}NerdFontPropo-*.otf  (Nerd Font Propo)
#   SF-Mono.dmg  the 12 SFMonoNerdFontMono-*.otf                 (Nerd Font Mono)
#
# See ../README.md for why each stage is there. Not an apply.sh step: the
# output is committed. Needs docker and uv, no root; SF Pro takes about four
# minutes, SF Mono about one.
#
#   build-sf.sh ~/Downloads/SF-Pro.dmg [OUTDIR]
#   build-sf.sh ~/Downloads/SF-Mono.dmg [OUTDIR]
set -euo pipefail

dmg="$(realpath "${1:?usage: build-sf.sh SF-Pro.dmg|SF-Mono.dmg [OUTDIR]}")"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="$(realpath "${2:-$here/..}")"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Nerd Fonts 3.5.1 ships font-patcher 4.27.2, which is what the image is
# tagged by.
PATCHER=nerdfonts/patcher:4.27.2
PY=(uv run --quiet --no-project --with fonttools==4.67.0 --with uharfbuzz==0.57.0
    --with pyliblzfse==0.4.1 python -I)

echo "▸ Unpacking $dmg"
mkdir "$work/pkg" "$work/apple" "$work/src" "$work/in" "$work/patched"
"${PY[@]}" "$here/udif.py" "$dmg" "$work/disk.img"
"${PY[@]}" "$here/carve_xar.py" "$work/disk.img" "$work/pkg/SF.pkg"
rm "$work/disk.img"
bsdtar -xf "$work/pkg/SF.pkg" -C "$work/pkg"
# SF-Pro.dmg's component is SFProFontsPackage.pkg, SF-Mono.dmg's SFMonoFonts.pkg.
payloads=("$work"/pkg/*.pkg/Payload)
[[ ${#payloads[@]} == 1 && -f ${payloads[0]} ]] || { echo "  ✗ expected one component package"; exit 1; }
bsdtar -xf "${payloads[0]}" -C "$work/apple"
fonts="$work/apple/Library/Fonts"

# The faces this repo ships, each with its italic.
if [[ -f $fonts/SF-Pro-Text-Regular.otf ]]; then
  family=Pro
  FACES=(
    Text-Regular Text-Medium Text-Semibold Text-Bold
    Display-Light Display-Regular Display-Semibold Display-Bold
  )
  # --variable-width-glyphs keeps the icons at their own widths: Nerd Font Propo.
  PATCH_OPTS=(--complete --variable-width-glyphs)
elif [[ -f $fonts/SF-Mono-Regular.otf ]]; then
  family=Mono
  FACES=(Light Regular Medium Semibold Bold Heavy)
  # --mono makes every icon one cell wide: Nerd Font Mono, as terminals expect.
  PATCH_OPTS=(--complete --mono)
else
  echo "  ✗ neither SF Pro nor SF Mono in $dmg"; exit 1
fi
for face in "${FACES[@]}"; do
  cp "$fonts/SF-$family-$face.otf" "$fonts/SF-$family-${face}Italic.otf" "$work/src/"
done
# The patcher gets them without Apple's license record, which overflows
# fontforge's name table; the repair puts it back from $work/src.
"${PY[@]}" "$here/drop_license.py" "$work/in" "$work/src"/*.otf

echo "▸ Patching $(ls "$work/in" | wc -l) faces with $PATCHER (${PATCH_OPTS[*]})"
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp -e PN=6 \
  -v "$work/in:/in:ro" -v "$work/patched:/out" \
  "$PATCHER" "${PATCH_OPTS[@]}" >"$work/patcher.log" 2>&1 ||
  { tail -20 "$work/patcher.log"; exit 1; }

# The patcher's file names: Semibold becomes SemiBold, RegularItalic Italic,
# SF Pro Text-Regular SFProTextNerdFontPropo-Regular, SF Mono Regular
# SFMonoNerdFontMono-Regular.
echo "▸ Restoring Apple's glyph order and layout, checked against Apple"
for src in "$work/src"/*.otf; do
  face="$(basename "$src" .otf)"
  face="${face#SF-$family-}"
  if [[ $family == Pro ]]; then
    style="${face#*-}"
    prefix="SFPro${face%%-*}NerdFontPropo"
  else
    style="$face"
    prefix="SFMonoNerdFontMono"
  fi
  style="${style/Semibold/SemiBold}"
  [[ $style == RegularItalic ]] && style=Italic
  name="$prefix-$style.otf"
  [[ -f $work/patched/$name ]] || { echo "  ✗ the patcher wrote no $name"; exit 1; }
  printf '%s\0' "$src" "$work/patched/$name" "$out/$name"
done | xargs -0 -n3 -P4 "${PY[@]}" "$here/restore_layout.py"
