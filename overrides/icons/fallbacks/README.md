# fallbacks/

This directory is one of the two sources of app icons for the Omarchy menu —
the **repainted** one. Nothing is generated: each file here is one you placed by
hand, gets recoloured to the active theme on every theme-set, and an app with no
file here (or in `../color/`) simply keeps its own vendor icon, in full colour,
unchanged.

Its sibling `../color/` is the same idea without the repaint: files there are
copied verbatim, for marks that only read in their own colours. A name in either
directory takes that app over; do not put the same name in both.

Add a file to take an app over; delete it to hand that app back.

## Naming

The filename must be the desktop entry's `Icon=` value, verbatim, plus `.svg`:

```
Exec line in the .desktop     Icon=com.mitchellh.ghostty
file to drop here             com.mitchellh.ghostty.svg
```

Check the name rather than guessing — it is often not the app's display name, and
often not the window class either:

```bash
grep -h '^Icon=' ~/.local/share/applications/*.desktop /usr/share/applications/*.desktop | sort -u
```

`.svg` only — a raster here is ignored. Qt rasterises a vector at whichever size
is asked for, while a PNG has to be scaled to each and goes soft.

The harder reason is ink. The sync used to accept rasters and normalise them,
trimming to the ink and re-padding onto a 256×256 canvas at 200×200, so every
PNG carried a known 200/256 ink ratio that the switcher undid at draw time. SVGs
got no such padding, so the same compensation drew every vector 28% oversized —
they overflowed their box and clipped, while the rasters beside them looked
small and off-centre. Two conventions, one of them invisible unless you read the
sync script.

So there is one now: every drop-in is edge-to-edge, and the switcher draws at
ink size with no ratio at all. An app whose icon exists only as a raster keeps
its Nerd Font glyph, which is the flat look regardless, and is what an app with
no drop-in has always fallen back to. `aether`, `cliamp`, `helium` and
`LimineSnapperSync` were the four dropped on that basis; a vector for any of
them can simply be dropped back in.

## What the file should contain

**A silhouette, not a coloured logo.** You supply the shape; the theme supplies
the colour. On every `omarchy theme set` the sync repaints every mark in that
theme's `foreground`, which is what keeps the light and dark themes consistent
without you keeping two copies.

- **SVG** — every `fill` and `stroke` is rewritten to the theme colour.
  `fill="none"` is preserved, so an outline-only shape stays an outline.
  Gradients and `url(#…)` paints are replaced by the flat colour.
- **SVG with a `<style>` block** — CSS class fills (`.st0{fill:#0acf83}`) are
  rewritten too, so a vector exported from a design tool works as-is.
- **SVG with no paint at all** — simple-icons and similar ship a bare
  `<path d="…"/>` with no `fill` anywhere. SVG's default fill is black, which
  would be invisible on a dark theme, so the sync gives the root element a fill.
  It only does this when the root has none, since a duplicate attribute makes
  the document unparseable.

## Preparing a file you sourced

Two things are worth checking before dropping a file in, because neither is done
for you.

**Size the mark to ~78% of a square canvas** — a 200px mark in a 256px box, or
the equivalent in user units. Logos are usually distributed edge-to-edge: the
official Figma mark is `viewBox="0 0 288 432"` with no padding, and dropped in
raw it renders visibly taller than every neighbour. Rewrap it:

```
<svg viewBox="0 0 256 256">
  <g transform="translate(TX,TY) scale(S)">  <!-- S = 200 / max(w,h) -->
    …the original shapes…
  </g>
</svg>
```

Centre on the **shapes' own bounds**, not the viewBox — exports often pad the
canvas, and centring on the viewBox leaves the mark fractionally off. The
switcher compensates for exactly the 200/256 ratio when lining icon ink up
against font glyphs, so a full-bleed file renders oversized there.

**Strip export artefacts.** Design tools emit invisible bounding rectangles —
`<rect … fill-opacity="0">` spanning the canvas. They draw nothing today, but
the sync rewrites `fill` attributes, and that rect is one attribute away from
becoming a solid block.

Check the result before trusting it:

```bash
overrides/hooks/theme-set.d/app-icons.sh
rsvg-convert -w 96 -h 96 ~/.icons/cllpse-flat/apps/<name>.svg -o /tmp/check.png
```

A file that fails to parse is silently skipped, so an icon that simply does not
appear is the symptom of a malformed drop-in, not a naming mistake.

## Where it ends up

`overrides/hooks/theme-set.d/app-icons.sh` syncs this directory into
`~/.icons/cllpse-flat/apps/` on every theme change, and the `post-update` hook
re-runs it after an `omarchy update`. Delete a file and the next sync removes it
from `~/.icons/` too.

The window switcher reads the same files, but keys on the **window class**
rather than `Icon=`. Those differ for a handful of apps, so a drop-in whose name
does not match the class reaches the menu only; drop a second copy named for the
class if you want it in both. Check a running window's class with:

```bash
hyprctl clients -j | grep '"class"'
```

One `.svg` per app. A `.png` of the same name is not a conflict any more, just
ignored — the sync no longer reads rasters at all.
