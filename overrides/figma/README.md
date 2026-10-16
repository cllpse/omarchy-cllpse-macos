# Figma Desktop

The one application this repo's overrides assume but `apply.sh` does not
install. Installing and updating are the same operation, because the app has no
self-updater: you replace the extracted directory and put the launcher entry
back.

```bash
./overrides/figma/figma.sh            # latest release, then apply.sh --all
./overrides/figma/figma.sh --check    # installed vs. latest; changes nothing
./overrides/apply.sh figma            # same, from the apply picker (--no-apply)
```

Opt-in in [`../apply.sh`](../apply.sh): it appears in the picker but **not** in
`--all`. It reaches the network and installs an application, which nothing else
here does — and this script ends by calling `apply.sh --all` itself, so putting
it in `--all` would recurse. The picker passes `--no-apply` for the same reason.

## What it does

1. resolve the installed version from the app's **own** bundled desktop entry
2. resolve the target version + asset from the GitHub release
3. refuse to extract over a **running** Figma
4. download, verify it is really an AppImage, extract to a scratch dir
5. gate the swap on the extracted tree actually being the app
6. swap the app directory, keeping the old one until the new one is in
7. hand off to `apply.sh`, which owns the launcher entry (step `applications`)

No sudo of its own, and nothing it writes is outside `$HOME`. The
`apply.sh --all` it hands off to is what asks for sudo (8b, 9, 11), as any
full run does; `--no-apply` skips it.

Step 4's download is bounded by a **stall**, not by a duration:
`--connect-timeout 30 --speed-limit 1024 --speed-time 60`, i.e. give up after
60s below 1 KB/s. `curl -f` only reacts to an HTTP status, so a peer that
holds the socket open without sending bytes would otherwise hang here
forever — and `apply.sh` can reach this script. A `--max-time` is the wrong
bound: it would have to be generous enough for a slow line to pull several
hundred MB, which is no bound at all. The two metadata calls above are small
and fixed, so those do take `--max-time 30`.

## Upstream

`IliyaBrook/figma-linux` — the official Figma Desktop Windows build, patched
for Linux and repacked as an AppImage. **Not** `Figma-Linux/figma-linux`, a
community Electron wrapper around the web app with a different settings schema.

The AppStream id is `io.github.nickvdp.figma-desktop-linux`, inherited from an
earlier project of nickvdp's and hardcoded upstream. That id is why this repo's
docs once named a `nickvdp/figma-desktop-linux` repo, which does not exist —
the id is real, the slug never was.

## Inside the app directory

The argv cap and the UI scale below are the only things in the repo written
**inside** the app directory. An update replaces the directory and takes them
with it, so `figma.sh` reapplies both on every run, including the
already-up-to-date one: `./overrides/figma/figma.sh --no-apply` repairs an
install without touching anything else. Both patch
`usr/lib/figma-desktop/launcher-common.sh`, each behind a marker comment, so a
second run changes nothing.

## The argv cap

`figma://` login needs the launch to stay
under 9 argv elements and `FIGMA_USE_WAYLAND=1` pushes it over
([electron/electron#52020](https://github.com/electron/electron/issues/52020)):
at 9 or more, the second instance's argv fails to parse across the singleton
socket, and it then seizes the lock and kills the first. The symptom is not a
login error — the app closes, reopens and asks you to log in again, forever.
The script comments out the two Wayland IME flags to bring the native path to 7,
one under the most that parses. The UI scale flag took it to 8 from 2026-10-12
to 16 (below). **One flag of headroom** is left: a second one added here, or
by upstream, must replace one. Diagnose
from `~/.cache/figma-desktop-linux/launcher.log`, which records every launch's
full argv.

## UI scale

Since 2026-10-16 Figma's UI scale is not pinned: it is the GTK text factor,
like every other Electron app's (1.4375 at text size 17), at the monitor's
scale 1, so 1.4375 screen pixels per Figma pixel at 100% canvas zoom. At scale
1 the pin below would be 1, a UI 30% smaller than the rest. `figma.sh` removes
the pin where an earlier run left it in the launcher. The canvas is
antialiased at that fraction, as in the "no flag" rows of the table below, but
Hyprland no longer resamples it: at monitor scale 1 the buffer is the window
(reasoned, not measured). Judged by eye.

From 2026-10-12 to 16, on native Wayland Figma got `--force-device-scale-factor`
= 1 / the monitor scale: **0.8 at 1.25**, 0.75 at 4/3. That flag replaces
Chromium's UI scale, which here is the GTK text factor. The window still
rendered at the monitor scale, and the flag on top made it 1.25 × 0.8 = **one
screen pixel per Figma pixel** at 100% canvas zoom, two at 200%. Every edge on a whole design pixel then lands on a whole screen pixel. At
the monitor's 4/3 alone (the flag at 1, used until 2026-10-12), only one edge
in three did: the other two fell between screen pixels and were antialiased
into a two-pixel grey smear, which is what read as a fuzzy canvas. The
interface is one screen pixel per CSS pixel, 25% smaller than at 4/3.

`figma.sh` worked the flag out from `monitor-scale` in
[`../display/display.conf`](../display/display.conf), snapped to the 1/120
steps of the fractional-scale protocol as Hyprland snaps it (1.33333 is
160/120, so exactly 0.75), and fell back to the first monitor's live scale.
After a scale change it had to run again, to rewrite the flag in the launcher.

Chosen by eye on 2026-10-12, at 4/3, against 1 and 1.5. At 1.5 it was two
screen pixels per Figma pixel, every edge crisp too, but the interface was 50%
larger than at 1 and the canvas showed a third less of the design. Canvas text is a separate
matter: Figma antialiases its own glyphs, their edges measured 0.75–0.80
screen px at every setting below, and fontconfig's hinting does not reach
them. They only read firmer when they get more pixels.

Hyprland does not resample Figma at any of these. Figma uses the
fractional-scale protocol, and Hyprland 0.56.2 draws such a window pixel for
pixel, switching to nearest-neighbour when the buffer is a pixel or two off its
box (`MISALIGNEDFSV1` in `ElementRenderer.cpp`). Chromium's flags do not reach
Figma either: `~/.config/chromium-flags.conf` is read only by
`/usr/bin/chromium`, and under Chromium's 2× setup none of Figma's processes
carried `WaylandFractionalScaleV1` or another scale (checked 2026-10-12).

Without a forced scale the canvas is blurred. At 4/3 × 1.109375 the tiled window's CSS
size is not a whole number of device pixels, Chromium's output lands a
fraction of a pixel off its buffer and Hyprland resamples the whole window.
Snapping the window to whole device pixels by hand recovers it, but only for
that one size. Forcing a scale removes the factor (1 when this was measured,
0.75 now), so the tiled and snapped captures are identical.

Measured 2026-10-12 on the + button and text of one file, across every
combination of backend (Wayland, XWayland), fractional scaling (on, off) and
forced scale, at 100%, 120% and 200% canvas zoom. Edge width is the mean
background-to-ink transition in screen pixels, lower is sharper; tiled window:

| Setup | Screen px per Figma px | + edge 100 / 120 / 200% | Text edge 100 / 120 / 200% |
|---|---|---|---|
| Wayland, forced 1 (until 2026-10-12; XWayland at 1.3333333 gives the same results) | 1.333 | 0.54 / 0.93 / 0.57 | 0.76 / 0.78 / 0.80 |
| Wayland, no flag (the GTK text factor) | 1.479 | 1.20 / 1.43 / 1.41 | 1.02 / 1.12 / 1.14 |
| Same, window snapped to whole device pixels | 1.479 | 0.93 / 0.95 / 0.92 | 0.76 / 0.79 / 0.80 |
| Fractional scaling off (`WaylandFractionalScaleV1`), forced 2 | 1.333 | 1.14 / 1.16 / 0.54 | 0.75 / 0.79 / 0.78 |
| **Wayland, forced 0.75** (XWayland forced 1 or none gives the same results) | 1.0 | 1.00 / 0.95 / 0.96 | 0.75 / 0.77 / 0.77 |
| Wayland forced 1.5, XWayland forced 2 | 2.0 | — / 0.74 / 0.12 | — / 0.79 / similar |

- **The + glyph's sharpness depends on its stroke.** The stroke is 1.5 design
  px, which at 4/3 is exactly 2 screen px at 100% and 4 at 200%, so it is
  pixel-exact there. At 120% it is 2.4, and every setup at this interface size
  gets one soft edge. At 0.75 it is 1.5 screen px, half a pixel, hence 1.00:
  the one shape here that 0.75 makes softer. Edges on whole design pixels,
  most of a design, were not in this measurement; 0.75 is what puts all of
  them on screen pixels.
- **Fractional scaling off gains nothing in Figma.** Its Electron then always
  draws at buffer scale 2, and the forced flag only sizes the UI, at 2/3 ×
  the flag. Hyprland's 1.5:1 downscale leaves a grey fringe at 100% and 120%.
  Forced 2.6666667 in that mode is broken: Figma fills only the top-left
  two-thirds of its window.
- **Bigger is sharper, not fixed:** 2 screen px per Figma px is crispest, but
  only because the whole interface is 1.5× larger.

The flag sits in the Wayland branch only. XWayland, used without
`FIGMA_USE_WAYLAND`, already renders 1:1 under `xwayland:force_zero_scaling`
and would need 1.3333333 to match.
