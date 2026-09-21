# omarchy-cllpse-theme-dark

A macOS-style theme for [Omarchy](https://omarchy.org) 4. Palette read from
macOS 27 (Tahoe) `NSColor` under the darkAqua appearance, converted to sRGB.

Self-contained: colours, shell surfaces, icon theme, wallpapers, and the window
decoration. Nothing is shared with `omarchy-cllpse-theme-light`.

## Install

**Clone and symlink — do not `omarchy theme install` it.**

```bash
git clone https://github.com/cllpse/omarchy-cllpse-theme-dark ~/src/omarchy-cllpse-theme-dark
ln -sfn ~/src/omarchy-cllpse-theme-dark ~/.config/omarchy/themes/omarchy-cllpse-theme-dark
omarchy theme set omarchy-cllpse-theme-dark
```

The symlink is load-bearing. `hyprland.lua` carries the decoration — rounding,
borders, gaps, blur, window opacity, layer rules and animations — and Omarchy
refuses to stage `.lua` from a theme it considers repo-installed, because it
executes in the compositor. The test is
`[[ ! -L $source && -d $source/.git ]]` (`omarchy-theme-set:204`): a symlink is
never repo-installed, whatever its target contains. Clone into
`~/.config/omarchy/themes/` directly and the decoration is silently dropped
while the colours still arrive.

## What is in here

| file | what it does |
|---|---|
| `colors.toml` | the palette and `mode`; drives every generated config |
| `hyprland.lua` | window/shell decoration, loaded from the active theme |
| `shell.*.toml` | per-section shell surface overrides (opacity, spacing) |
| `icons.theme` | the GTK icon theme name |
| `chromium.theme` | Chromium's frame colour |
| `backgrounds/` | wallpapers; the `00-` prefix pins the default |
| `colors.svg` | generated reference sheet, read by nothing |
| `unlock.png`, `preview*.png` | Plymouth/SDDM art and the picker thumbnail |

Editing `colors.toml` means regenerating `colors.svg`; it does not stay in sync.
