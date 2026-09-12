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
# starship-colors.sh.
#
# `omarchy theme set` does NOT restart the shell. It pushes the new palette into
# the running process over IPC (omarchy-theme-set:112/308, `shell_ipc shell
# applyTheme`) and restarts only the terminal, hyprctl, btop, opencode and helix
# (319-323). Measured: the quickshell pid is unchanged across a theme set. This
# file used to claim the opposite, and the restart at the bottom is what makes
# the claim true rather than the comment.
set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
FALLBACKS="$HERE/../../icons/fallbacks"
# Drop-ins that keep their own colours. Separate directory rather than a naming
# convention, because two different things have to leave them alone: this script
# must not repaint the file, and the switcher must not colorize it at draw time
# -- and the switcher decides that from the PATH (anything under cllpse-flat is
# flat by definition). A second output directory settles both at once.
COLOR_IN="$HERE/../../icons/color"
COLOR_OUT="$HOME/.icons/cllpse-color/apps"
COLORS="$HOME/.local/state/omarchy/current/theme/colors.toml"
OUT="$HOME/.icons/cllpse-flat/apps"

# Every loop here iterates a glob that legitimately matches nothing.
shopt -s nullglob

# ── Make the result visible ─────────────────────────────────────────────────
# Everything below writes files the SHELL has already cached, and the palette
# push that `omarchy theme set` performs does not invalidate either cache:
#
#   - The Omarchy menu draws an app icon as a plain Image (Menu.qml:1253) with
#     no recolouring and no `cache:` property, so Qt's URL-keyed pixmap cache
#     can keep serving the previous theme's colour from an unchanged path.
#   - The switcher builds its drop-in index from a single `ls` at launch
#     (Hud.qml, iconScan), so a newly added drop-in is not in it at all -- the
#     file is correct on disk and the strip still shows a Nerd Font glyph.
#
# Without a restart the repaint below is work nothing ever displays. Restart
# only when something ACTUALLY changed: re-publishing the same theme rewrites
# identical bytes, and taking the bar down on every no-op theme-set would be a
# worse bug than the one this fixes. A manifest either side of the passes is
# what decides, and an EXIT trap is what makes it cover the flat pass's two
# early `exit 0`s (no colors.toml, unreadable foreground) as well as the end.
_manifest() {
  { [[ -d $OUT ]]       && find "$OUT"       -type f -exec md5sum {} +
    [[ -d $COLOR_OUT ]] && find "$COLOR_OUT" -type f -exec md5sum {} +
  } 2>/dev/null | sort || true
}
_before="$(_manifest)"

_restart_shell_if_changed() {
  [[ "$_before" != "$(_manifest)" ]] || return 0
  command -v omarchy-restart-shell >/dev/null 2>&1 || return 0
  # Never fail the hook over this, and do not treat a refusal as an error.
  # omarchy-restart-shell exits 1 on a LOCKED session by design -- restarting
  # would kill the lock client and strand the session behind Hyprland's failsafe
  # -- and a hook that exits non-zero prints "Hook failed:" for something the
  # user never asked for. Measured: with the screen locked this is the branch
  # that runs, every time.
  #
  # The consequence is accepted rather than worked around: a theme change made
  # while locked leaves the icons at the previous colour, with no retry. It is
  # cosmetic, it is invisible until the session is unlocked anyway, and it
  # self-heals on the next theme change or shell restart. Polling for an unlock
  # from a hook that has already exited would cost a background process on every
  # theme-set to fix a stale icon nobody can currently see.
  omarchy-restart-shell >/dev/null 2>&1 || true
}
trap _restart_shell_if_changed EXIT

# ── Colour pass ─────────────────────────────────────────────────────────────
# Copied verbatim, no recolouring, no ImageMagick -- so it needs neither the
# palette nor the flat directory, and it runs FIRST, before any of the flat
# pass's guards. It used to sit below them, which quietly coupled two
# independent icon sets: emptying icons/fallbacks/ also stopped syncing
# icons/color/, and a theme with no readable colors.toml stopped both.
#
# $HOME/.icons is first in the XDG sweep the switcher runs (and in Omarchy's own
# AppLibrary), and this lands under */apps/*, so a file here is found by name
# exactly like a vendor icon -- which is the point: it IS one, just ours.
#
# The sweep is OUTSIDE the `-d $COLOR_IN` test on purpose. Inside it, removing
# icons/color/ from the repo altogether left ~/.icons/cllpse-color/apps/ serving
# files nothing backed any more -- the one case where a stale icon is certain
# rather than merely possible. With COLOR_IN gone, wantedColor is empty and the
# sweep clears the directory, which is what "delete a drop-in to hand that app
# back" has to mean.
declare -A wantedColor=()
if [[ -d $COLOR_IN ]]; then
  mkdir -p "$COLOR_OUT"
  for f in "$COLOR_IN"/*.svg; do
    b=$(basename "$f")
    wantedColor[${b%.*}]="$b"
    cp -f "$f" "$COLOR_OUT/$b"
  done
fi
for f in "$COLOR_OUT"/*.svg; do
  b=$(basename "$f")
  [[ ${wantedColor[${b%.*}]:-} == "$b" ]] || rm -f "$f"
done
rmdir "$COLOR_OUT" "$(dirname "$COLOR_OUT")" 2>/dev/null || true

# ── Flat pass ───────────────────────────────────────────────────────────────
# Repainting needs the active palette, so this half -- and only this half --
# stops here when either is missing.
[[ -d $FALLBACKS ]] || exit 0
[[ -f $COLORS ]] || exit 0

fg="$(omarchy-theme-color --file "$COLORS" foreground 2>/dev/null || true)"
[[ $fg =~ ^#[0-9A-Fa-f]{6}$ ]] || exit 0

mkdir -p "$OUT"
declare -A wanted=()

# SVG only. Rasters used to be accepted here and normalised by ImageMagick --
# trimmed to the ink, resized to 200x200, then re-padded onto a 256x256 canvas.
# That gave every raster a known 200/256 ink ratio, which the switcher undid at
# draw time by scaling its icon box by 256/200. The SVG branch below does no
# such padding, so the same compensation drew every vector 28% oversized: they
# overflowed their box and clipped, while the rasters beside them looked small
# and off-centre.
#
# Compensating per extension worked but kept two conventions alive, one of them
# only reachable by reading this file. Accepting a single format retires the
# question: every drop-in is edge-to-edge, the switcher draws at ink size with
# no ratio at all, and an app whose icon only exists as a raster keeps its Nerd
# Font glyph -- which is the flat look anyway, and what an app with no drop-in
# has always fallen back to.
#
# aether, cliamp, helium and LimineSnapperSync were the four that went. If a
# vector turns up for any of them, dropping it in is the whole of the work.
for f in "$FALLBACKS"/*.svg; do
  base=$(basename "$f"); name=${base%.*}
  wanted[$name]="$base"

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
done

# Remove anything no longer backed by a file in fallbacks/, so deleting a
# drop-in really does hand that app back to its vendor icon. Still sweeps .png
# as well as .svg: this run generates none, but an earlier one did, and a
# leftover raster is exactly the stale second convention this change exists to
# remove.
for f in "$OUT"/*.svg "$OUT"/*.png; do
  b=$(basename "$f")
  [[ ${wanted[${b%.*}]:-} == "$b" ]] || rm -f "$f"
done
rmdir "$OUT" "$(dirname "$OUT")" 2>/dev/null || true
