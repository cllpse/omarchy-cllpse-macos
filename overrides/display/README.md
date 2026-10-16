# Display scaling + text size

Three machine-level values — text size, monitor scale, GDK scale — captured from a live machine and restored on every apply.

Restore overrides/display/display.conf (written by ./overrides/display/save-display.sh).
key left empty is skipped, and a missing file skips the step entirely.

These are a machine preference, not part of the macOS look -- re-running
apply.sh reasserts them, so if you retune the text size or scale by hand, run
save-display.sh to make that the saved state rather than having the next
apply.sh pull you back.

## The files here

| file | what it is |
|---|---|
| [`display.sh`](display.sh) | the apply step (was `apply.sh` step 7b): restores the saved values |
| [`save-display.sh`](save-display.sh) | capture the live machine's values into `display.conf` |
| [`display-lib.sh`](display-lib.sh) | shared readers/writers for scale + text size — **sourced, never run** |
| [`display.conf`](display.conf) | the saved values: `text-size`, `monitor-scale`, `gdk-scale` |

```bash
./overrides/display/save-display.sh   # capture this machine's values
./overrides/display/display.sh        # restore them (apply.sh does this too)
```

`display-lib.sh` is sourced by all three of `display.sh`, `save-display.sh` and
`../revert.sh`, which is why it is a library rather than a step and has no
executable bit to invite running it.

**Figma's canvas no longer follows `monitor-scale`.** From 2026-10-12 to 16
`../figma/figma.sh` forced Figma's scale to 1 / this value, one screen pixel
per Figma pixel. It now leaves Figma at the GTK text factor and removes that
pin (see `../figma/README.md`).

**These values are hardware-specific.** What ships here is tuned for one
~102 PPI 3840x2160 display (a 43" TV): monitor scale 1 and Omarchy's default
GDK scale of 2 since 2026-10-16 (1.25 and 1 before). `gdk-scale` 1 is right for
standard DPI and 2 for a HiDPI panel; the 2 here is the author's choice, and
it reaches only X11 apps under XWayland, which it draws at twice the size at
monitor scale 1. Re-run `save-display.sh` on your
own machine before the first apply, or `apply.sh` will confidently assert
someone else's sizing.

Script: [`display.sh`](display.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
