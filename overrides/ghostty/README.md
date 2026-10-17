# Ghostty

Ghostty reads its own hinting knob rather than fontconfig's. Its default is the same slight hinting as the system's, so this block no longer sets it; it forced `no-hinting` until 2026-10-12 (see [`../fontconfig/README.md`](../fontconfig/README.md)). Everything else about Ghostty's colours comes from the theme.

The font size is pinned at 9pt, overruling what `omarchy display text size` writes, so terminal text is Omarchy's text size like every other app's ([`../README.md`](../README.md), "One text size"). Ghostty multiplies its points by the GTK text factor, so it still follows a text-size change. The arithmetic is in the header of [`ghostty.conf`](ghostty.conf).

An unfocused Ghostty draws its cursor as a hollow outline, and no key changes that alone: `cursor-color` and `cursor-opacity` reach the focused block too. [`unfocused-cursor.glsl`](unfocused-cursor.glsl) fills the cursor's cell instead, with the cursor colour at 10% over the character, when the surface is unfocused. It is a custom shader with `custom-shader-animation = false`, so it draws only when the terminal does. `ghostty.sh` links it into `~/.config/ghostty/shaders/`; open Ghostty windows keep what they started with. It replaced `adjust-cursor-thickness = 200%` on 2026-10-17, which at text size 18 drew a thick frame rather than a block.

Script: [`ghostty.sh`](ghostty.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
