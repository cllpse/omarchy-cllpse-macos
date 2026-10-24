#!/bin/bash
# SF Pro Text and Display, upright and italic, as Nerd Font Propo faces
#
# Rebuilds the 16 SFPro*NerdFontPropo-*.otf one folder up from Apple's
# SF-Pro.dmg (developer.apple.com/fonts). See ../README.md for why each stage
# is there. Not an apply.sh step: the output is committed. Needs docker and uv,
# no root, and takes about four minutes.
#
#   build-sf-pro.sh ~/Downloads/SF-Pro.dmg [OUTDIR]
set -euo pipefail

dmg="$(realpath "${1:?usage: build-sf-pro.sh SF-Pro.dmg [OUTDIR]}")"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="$(realpath "${2:-$here/..}")"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Nerd Fonts 3.5.1 ships font-patcher 4.27.2, which is what the image is
# tagged by. The SF Mono faces beside these were patched with 3.5.1 too.
PATCHER=nerdfonts/patcher:4.27.2
# The faces this repo has always shipped upright. Each gets its italic.
FACES=(
  Text-Regular Text-Medium Text-Semibold Text-Bold
  Display-Light Display-Regular Display-Semibold Display-Bold
)
PY=(uv run --quiet --no-project --with fonttools==4.67.0 --with uharfbuzz==0.57.0
    --with pyliblzfse==0.4.1 python -I)

echo "▸ Unpacking $dmg"
mkdir "$work/pkg" "$work/apple" "$work/src" "$work/in" "$work/patched"
"${PY[@]}" "$here/udif.py" "$dmg" "$work/disk.img"
"${PY[@]}" "$here/carve_xar.py" "$work/disk.img" "$work/pkg/SF-Pro.pkg"
rm "$work/disk.img"
bsdtar -xf "$work/pkg/SF-Pro.pkg" -C "$work/pkg"
bsdtar -xf "$work/pkg/SFProFontsPackage.pkg/Payload" -C "$work/apple"
for face in "${FACES[@]}"; do
  cp "$work/apple/Library/Fonts/SF-Pro-$face.otf" \
     "$work/apple/Library/Fonts/SF-Pro-${face}Italic.otf" "$work/src/"
done
# The patcher gets them without Apple's 60 KB license record, which overflows
# fontforge's name table; the repair puts it back from $work/src.
"${PY[@]}" "$here/drop_license.py" "$work/in" "$work/src"/*.otf

echo "▸ Patching $(ls "$work/in" | wc -l) faces with $PATCHER (--complete --variable-width-glyphs)"
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp -e PN=6 \
  -v "$work/in:/in:ro" -v "$work/patched:/out" \
  "$PATCHER" --complete --variable-width-glyphs >"$work/patcher.log" 2>&1 ||
  { tail -20 "$work/patcher.log"; exit 1; }

# The patcher's file names: Semibold becomes SemiBold, RegularItalic Italic.
echo "▸ Restoring Apple's glyph order and layout, checked against Apple"
for src in "$work/src"/*.otf; do
  face="$(basename "$src" .otf)"
  face="${face#SF-Pro-}"
  style="${face#*-}"
  style="${style/Semibold/SemiBold}"
  [[ $style == RegularItalic ]] && style=Italic
  name="SFPro${face%%-*}NerdFontPropo-$style.otf"
  [[ -f $work/patched/$name ]] || { echo "  ✗ the patcher wrote no $name"; exit 1; }
  printf '%s\0' "$src" "$work/patched/$name" "$out/$name"
done | xargs -0 -n3 -P4 "${PY[@]}" "$here/restore_layout.py"
