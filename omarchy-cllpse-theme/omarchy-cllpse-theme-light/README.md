# omarchy-cllpse-theme-light

A macOS-style theme for [Omarchy](https://omarchy.org) 4. Palette read from
macOS 27 (Tahoe) `NSColor` under the aqua appearance, converted to sRGB.

Colours, shell surfaces, icon theme and wallpapers. Installs and works on its
own. Nothing is shared with `omarchy-cllpse-theme-dark`.

## Install

```bash
omarchy theme install https://github.com/cllpse/omarchy-cllpse-theme-%s
```

Omarchy derives the installed name by stripping a leading `omarchy-`, so this
lands as **`cllpse-theme-%s`**, not the repo name.

This theme is colours only — palette, shell surfaces, icon theme, Chromium
frame, wallpapers. The macOS **window decoration** (rounding, borders, gaps,
blur, window opacity, animations) is not here and cannot be: Omarchy stages no
`.lua` from an installed theme, because it would execute in the compositor
(`omarchy-theme-set:204`). That lives in
[omarchy-cllpse-macos](https://github.com/cllpse/omarchy-cllpse-macos), which
appends it to your own `~/.config/hypr/looknfeel.lua`.

## What is in here

| file | what it does |
|---|---|
| `colors.toml` | the palette and `mode`; drives every generated config |
| `shell.*.toml` | per-section shell surface overrides (opacity, spacing) |
| `icons.theme` | the GTK icon theme name |
| `chromium.theme` | Chromium's frame colour |
| `backgrounds/` | wallpapers; the `00-` prefix pins the default |
| `colors.svg` | generated reference sheet, read by nothing |
| `unlock.png`, `preview*.png` | Plymouth/SDDM art and the picker thumbnail |

Editing `colors.toml` means regenerating `colors.svg`; it does not stay in sync.
