# Ghostty

Ghostty reads its own hinting knob rather than fontconfig's, so it needs a line of its own. Everything else about Ghostty's colours comes from the theme.

The font size is pinned at 9pt, overruling what `omarchy display text size` writes, so terminal text is Omarchy's text size like every other app's ([`../README.md`](../README.md), "One text size"). Ghostty multiplies its points by the GTK text factor, so it still follows a text-size change. The arithmetic is in the header of [`ghostty.conf`](ghostty.conf).

Script: [`ghostty.sh`](ghostty.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
