# fontconfig

One drop-in: point the UI font at SF Pro.

Hinting is left to the system: `hintslight`, from `/etc/fonts/conf.d/10-hinting-slight.conf`.
Until 2026-10-12 a second drop-in here, `11-cllpse-macos-hinting.conf`, forced
`hintnone` on the reasoning that SF is drawn to render unhinted and that slight
hinting snaps its stems hard under the greyscale antialiasing fractional scaling
forces. Side by side on this ~102 PPI TV, slight read sharper, and the drop-in
went. [`fontconfig.sh`](fontconfig.sh) deletes it where an earlier run installed
it. GTK and Ghostty read their own hinting knobs: apply.sh step 5 resets GTK's
to its default, also slight, and [`../ghostty/`](../ghostty/README.md) no longer
sets Ghostty's.

What hinting does not reach: most text in the bar and Omarchy's menus (Qt Quick's
distance-field rendering), Figma's canvas (its own glyphs) and Kitty (hardcoded).

Script: [`fontconfig.sh`](fontconfig.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
