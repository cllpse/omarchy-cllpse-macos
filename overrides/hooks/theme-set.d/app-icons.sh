#!/bin/bash
# Sync overrides/icons/fallbacks/ into the icon directory the Omarchy menu
# actually reads, repainted in the active theme's foreground.
#
# Why this exists: the menu draws two kinds of icon. Rows that are not apps
# render `row.icon` as TEXT in a Nerd Font, coloured `foreground` -- that is the
# flat look. App rows instead render a plain `Image` of whatever the desktop
# entry's `Icon=` resolves to (Menu.qml:1253), with no recolouring at all, so
# every app shows its vendor's full-colour logo. There is no setting for this;
# the only lever short of forking the menu plugin is to make `Icon=` resolve to
# a file we control.
#
# AppLibrary.qml resolves an icon name through its OWN index before Qt's themed
# lookup -- a `find` over every XDG icon dir, `*/apps/*` and `*/devices/*`, svg
# pass then png, first hit per name. `$HOME/.icons` is the first directory in
# both passes, so a file we drop there outranks every installed theme. It has no
# index.theme, so GTK and Qt ignore it entirely: the override reaches the
# Omarchy shell and nothing else.
#
# Nothing here is generated. Every icon is a file hand-placed in
# icons/fallbacks/ -- see that directory's README for the naming and silhouette
# contract. An app with no file there keeps its vendor icon, unchanged.
#
# Because app icons are never recoloured by the shell, a synced file carries a
# FIXED colour and would not survive a light/dark switch -- which is why this is
# a theme-set hook rather than a one-off in apply.sh, exactly like
# starship-colors.sh. `omarchy theme set` restarts the shell, so Qt's URL-keyed
# image cache is dropped and the new colour actually lands.
set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
FALLBACKS="$HERE/../../icons/fallbacks"
COLORS="$HOME/.local/state/omarchy/current/theme/colors.toml"
OUT="$HOME/.icons/cllpse-flat/apps"

[[ -d $FALLBACKS ]] || exit 0
[[ -f $COLORS ]] || exit 0

fg="$(omarchy-theme-color --file "$COLORS" foreground 2>/dev/null || true)"
[[ $fg =~ ^#[0-9A-Fa-f]{6}$ ]] || exit 0

mkdir -p "$OUT"
declare -A wanted=()

# Both loops below iterate globs that legitimately match nothing.
shopt -s nullglob

for f in "$FALLBACKS"/*.svg "$FALLBACKS"/*.png; do
  base=$(basename "$f"); name=${base%.*}; ext=${base##*.}
  # One file per app, or both would land in $OUT and the index's svg pass would
  # outrank the png one -- so a .png drop-in would silently lose to a stale .svg.
  if [[ -n ${wanted[$name]:-} ]]; then
    printf 'app-icons: %s has both .svg and .png in fallbacks/, using .svg\n' "$name" >&2
    continue
  fi
  wanted[$name]="$name.$ext"

  if [[ $ext == svg ]]; then
    # Repaint every paint, with three failure modes all found in practice here:
    #
    # fill="none" is parked first because it is load-bearing -- it is how an
    # outline-only shape says it has no fill, and flooding it turns the outline
    # into a solid blob. The parking token must NOT itself read fill="..." or
    # the generic rule below matches it too and the protection silently does
    # nothing.
    #
    # The style-property character classes must stop at } and < as well as at
    # the quotes: a CSS <style> block writes `.a{fill:#0acf83}.b{fill:#a259ff}`,
    # and a class that only excludes quotes runs from the first `fill:` through
    # every rule after it and into the following tag, destroying the document --
    # that corrupted org.gnome.DiskUtility's symbolic icon into unparseable XML,
    # which rsvg reported as "Couldn't find end of Start Tag".
    #
    # Both quote styles: Inkscape-authored SVGs use single quotes throughout,
    # and a rule written only for double quotes silently leaves those
    # unrecoloured, which on a matching theme looks like the icon vanished.
    sed -e 's/fill="none"/__KEEPF__/g;      s/fill='"'"'none'"'"'/__KEEPF__/g' \
        -e 's/stroke="none"/__KEEPS__/g;    s/stroke='"'"'none'"'"'/__KEEPS__/g' \
        -e "s/fill=\"[^\"]*\"/fill=\"$fg\"/g" \
        -e "s/fill='[^']*'/fill='$fg'/g" \
        -e "s/stroke=\"[^\"]*\"/stroke=\"$fg\"/g" \
        -e "s/stroke='[^']*'/stroke='$fg'/g" \
        -e "s/fill:[^;}\"'<]*/fill:$fg/g" \
        -e "s/stroke:[^;}\"'<]*/stroke:$fg/g" \
        -e 's/__KEEPF__/fill="none"/g' \
        -e 's/__KEEPS__/stroke="none"/g' \
        "$f" >"$OUT/$name.svg"

    # An SVG that carries no paint at all -- simple-icons ships exactly this,
    # a bare <path d="..."/> -- has nothing for the rules above to rewrite, and
    # SVG's default fill is black, so it would render invisible on a dark theme.
    # Give the root a fill; children that set their own still win, so this is
    # safe on files that did get recoloured. Only when the root has none, or the
    # duplicate attribute makes the document unparseable. The tag can wrap
    # lines, hence grep -z: one NUL-delimited record, so [^>]* spans newlines
    # without a `tr` to flatten them first.
    if ! grep -zqE '<svg[^>]*fill=' "$OUT/$name.svg"; then
      sed -i "0,/<svg/s//<svg fill=\"$fg\"/" "$OUT/$name.svg"
    fi
  elif command -v magick >/dev/null; then
    # Alpha as the mask, painted in the theme colour. -strip drops the PNG date
    # chunks ImageMagick stamps in, which are otherwise the only thing that
    # differs between two runs of an identical input.
    magick "$f" -channel A -threshold 50% +channel -fill "$fg" -colorize 100 \
      -trim +repage -background none -resize 200x200 -gravity center \
      -extent 256x256 -strip "PNG32:$OUT/$name.png" 2>/dev/null || true
  else
    cp -f "$f" "$OUT/$name.png"
  fi
done

# Remove anything no longer backed by a file in fallbacks/, so deleting a
# drop-in really does hand that app back to its vendor icon. Both extensions:
# an app that switches from .png to .svg would otherwise leave the old file
# behind, and the svg pass outranks the png one.
for f in "$OUT"/*.svg "$OUT"/*.png; do
  b=$(basename "$f")
  [[ ${wanted[${b%.*}]:-} == "$b" ]] || rm -f "$f"
done
rmdir "$OUT" "$(dirname "$OUT")" 2>/dev/null || true
