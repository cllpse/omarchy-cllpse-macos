# fallbacks/

This directory is the **only** source of app icons for the Omarchy menu. Nothing
is generated: each file here is one you placed by hand, and an app with no file
here simply keeps its own vendor icon, in full colour, unchanged.

Add a file to take an app over; delete it to hand that app back.

## Naming

The filename must be the desktop entry's `Icon=` value, verbatim, plus `.svg` or
`.png`:

```
Exec line in the .desktop     Icon=com.mitchellh.ghostty
file to drop here             com.mitchellh.ghostty.svg
```

Check the name rather than guessing — it is often not the app's display name, and
often not the window class either:

```bash
grep -h '^Icon=' ~/.local/share/applications/*.desktop /usr/share/applications/*.desktop | sort -u
```

`.svg` is strongly preferred. The same icon is drawn at 21px in the menu and 28px
in the switcher; Qt rasterises a vector at whichever size is asked for, while a
PNG has to be scaled to both and goes soft. If you only have a PNG, give it at
least 256×256.

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
- **PNG** — the alpha channel is used as the mask and painted in the theme
  colour, so anything non-transparent becomes part of the mark. A logo on an
  opaque background tile will come out as a solid block; trim it to the mark
  first.

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

Give exactly one file per app — a `.svg` and a `.png` of the same name is a
conflict, and the sync warns and keeps the `.svg`.
