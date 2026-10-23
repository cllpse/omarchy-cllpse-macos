# fontconfig

Two drop-ins: point the UI font at SF Pro, and hint the SF faces with FreeType's
autohinter.

Hinting is the system's `hintslight`, from `/etc/fonts/conf.d/10-hinting-slight.conf`.
Until 2026-10-12 a third drop-in here, `11-cllpse-macos-hinting.conf`, forced
`hintnone` on the reasoning that SF is drawn to render unhinted and that slight
hinting snaps its stems hard under the greyscale antialiasing fractional scaling
forces. Side by side on this ~102 PPI TV, slight read sharper, and the drop-in
went. [`fontconfig.sh`](fontconfig.sh) deletes it where an earlier run installed
it. GTK and Ghostty read their own hinting knobs: apply.sh step 5 resets GTK's
to its default, also slight, and [`../ghostty/`](../ghostty/README.md) no longer
sets Ghostty's.

**SF has no hints, so slight did nothing to it** (found 2026-10-20). Apple ships
SF Pro and SF Mono unhinted: 0 of 35,683 glyphs in SF Pro Text, 0 of 1,628 in SF
Mono, no instructions in the variable TTFs, checked against Apple's own DMGs. The
Nerd Font patcher adds none. For a CFF font, slight hinting runs the font's own
hints, so `hintslight` and `hintnone` rendered SF identically, and the 2026-10-12
comparison could only have changed hinted fonts (Comic Code in Ghostty).
Apple's alignment data is broken too (a duplicated cap zone, the baseline zone
in `OtherBlues`, `BlueScale` 0), but nothing reads it while the glyphs carry no
stem hints.

[`99-cllpse-macos-autohint.conf`](conf.d/99-cllpse-macos-autohint.conf) forces
the autohinter for `SFProText`, `SFProDisplay` and `SFMono Nerd Font`, still at
slight: horizontal edges (baseline, x-height, cap height, crossbars) land on
whole pixel rows, while vertical stems and spacing stay where they were. At
18.67 px the top row of an H goes from 35/255 coverage to 255. Picked by eye on
2026-10-23 from a Qt Quick render of the switcher's and supermenu's text, against
unhinted and against Adobe's `otfautohint` baked into a rebuilt font. The baked
hints came within a level or two of the autohinter, with slightly firmer
crossbars, but needed the alignment data repaired first and a font rebuild to
ship. Hinting a TrueType copy with `ttfautohint` is no route: at slight, FreeType
ignores TrueType hints and autohints any TTF anyway.

What the autohinter reaches, and what it doesn't:

- **GTK 3 and 4**: yes, through cairo, which reads the drop-in's `autohint`.
  GTK 4's default `automatic` font rendering ignores `gsettings font-hinting`
  and hardcodes slight with greyscale antialiasing (`gtk_widget_update_pango_context`, 4.22).
- **The Omarchy shell, the switcher and the supermenu**: only because
  `QML_DISABLE_DISTANCEFIELD=1` ([`../hypr/hyprland-env.lua`](../hypr/hyprland-env.lua))
  switches Qt Quick from distance-field text, which takes no hinting, to native FreeType glyphs.
- **Chromium and Electron apps**: no. Above a device scale of 1 they turn on
  subpixel positioning and with it set hinting to none (`font_render_params_linux.cc`),
  and every one of them runs above 1 here. `--disable-font-subpixel-positioning`
  would bring it back; not used.
- **Not at all**: Figma's canvas (its own glyphs), Ghostty (its own load flags,
  and Comic Code is hinted), Kitty (hardcoded).

Scripts: [`fontconfig.sh`](fontconfig.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
