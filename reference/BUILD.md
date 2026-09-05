# macOS — theme specification for Omarchy 4

Reference for building an Omarchy theme named **`macOS`** that reproduces the
macOS system appearance. This document specifies *what* the values are, not how
to apply them.

**Target:** Omarchy **v4.0.2** ("Quattro"), branch **`quattro`**. The `master`
branch is stale at 3.8.5 and describes an incompatible theme format (ANSI
`color0`–`color15`, Waybar/Walker/Mako/SwayOSD). Read `quattro`.

**Colour provenance:** read from Apple's live AppKit palette on macOS 27 via
`NSColor` under `NSAppearance.aqua` and `.darkAqua`, converted to sRGB. macOS 26
retuned the palette — published tables older than that disagree (`systemRed` was
`#FF3B30`, is now `#FF383C`; `systemBlue` was `#007AFF`, is now `#0088FF`). Use
only the values below.

**The colours are authoritative.** They are what macOS reports and are not to be
adjusted, substituted, or reconciled against any other theme. Everything else —
window geometry, blur, spacing — is marked **[measured]**, **[reported]**
(third-party) or **[chosen]** (tune freely).

Ship two themes: `macOS` (dark) and `macOS-light`. Each needs at least one image
in `backgrounds/` or it will not apply. In v4 the neovim, VS Code and btop
themes are generated from `colors.toml` — don't hand-author them.

---

## 1. Palette — dark

Every value below is an `NSColor` read from macOS. `↓` = the source colour
carries alpha and has been composited over its own `windowBackgroundColor`.

```toml
mode = "dark"

accent = "#007AFF"                 # controlAccentColor
selection = "#3F638B"              # selectedTextBackgroundColor
muted = "#565656"                  # tertiaryLabelColor ↓

background = "#1E1E1E"             # windowBackgroundColor
dark_background = "#1A1A1A"        # gridColor
darker_background = "#000000"      # shadowColor
lighter_background = "#282828"     # underPageBackgroundColor

foreground = "#DDDDDD"             # labelColor ↓
dark_foreground = "#9A9A9A"        # secondaryLabelColor ↓
light_foreground = "#FFFFFF"       # textColor
bright_foreground = "#FFFFFF"      # textColor

red = "#FF383C"                    # systemRed        aqua
yellow = "#FFCC00"                 # systemYellow     aqua
orange = "#FF8D28"                 # systemOrange     aqua
green = "#34C759"                  # systemGreen      aqua
cyan = "#00C0E8"                   # systemCyan       aqua
blue = "#0088FF"                   # systemBlue       aqua
magenta = "#CB30E0"                # systemPurple     aqua
brown = "#AC7F5E"                  # systemBrown      aqua

bright_red = "#FF4245"             # systemRed        darkAqua
bright_yellow = "#FFD600"          # systemYellow     darkAqua
bright_green = "#30D158"           # systemGreen      darkAqua
bright_cyan = "#3CD3FE"            # systemCyan       darkAqua
bright_blue = "#0091FF"            # systemBlue       darkAqua
bright_magenta = "#DB34F2"         # systemPurple     darkAqua
```

The greys are macOS's own label hierarchy composited over `#1E1E1E`, giving the
ramp `#000000 → #1A1A1A → #1E1E1E → #282828 → #565656 → #9A9A9A → #DDDDDD →
#FFFFFF`. macOS has a single tier above `labelColor`, so `light_foreground` and
`bright_foreground` are both `textColor`.

Hues take the normal row from the light appearance and the bright row from the
dark one.

## 2. Palette — light

```toml
mode = "light"

accent = "#007AFF"                 # controlAccentColor
selection = "#B3D7FF"              # selectedTextBackgroundColor
muted = "#BDBDBD"                  # tertiaryLabelColor ↓

background = "#FFFFFF"             # windowBackgroundColor
dark_background = "#F6F6F6"        # underPageBackgroundColor
darker_background = "#E6E6E6"      # gridColor
lighter_background = "#FFFFFF"     # windowBackgroundColor

foreground = "#272727"             # labelColor ↓
dark_foreground = "#808080"        # secondaryLabelColor ↓
light_foreground = "#000000"       # textColor
bright_foreground = "#000000"      # textColor

red = "#FF383C"                    # systemRed        aqua
yellow = "#FFCC00"                 # systemYellow     aqua
orange = "#FF8D28"                 # systemOrange     aqua
green = "#34C759"                  # systemGreen      aqua
cyan = "#00C0E8"                   # systemCyan       aqua
blue = "#0088FF"                   # systemBlue       aqua
magenta = "#CB30E0"                # systemPurple     aqua
brown = "#AC7F5E"                  # systemBrown      aqua

bright_red = "#FF383C"             # systemRed        aqua
bright_yellow = "#FFCC00"          # systemYellow     aqua
bright_green = "#34C759"           # systemGreen      aqua
bright_cyan = "#00C0E8"            # systemCyan       aqua
bright_blue = "#0088FF"            # systemBlue       aqua
bright_magenta = "#CB30E0"         # systemPurple     aqua
```

In the light appearance macOS uses the `aqua` hues; the `darkAqua` variants are
lighter and belong to dark mode. The bright row therefore carries the same
values as the normal row. White is the lightest surface macOS has, so
`background` and `lighter_background` are both `windowBackgroundColor`, and
`light_foreground` and `bright_foreground` are both `textColor`.

## 3. Reserve hues

macOS ships thirteen system hues; the schema holds eight. These five have no
slot — use them for anything hand-authored. Format: light / dark appearance.

| Colour | light | dark |
|---|---|---|
| systemMint | `#00C8B3` | `#00DAC3` |
| systemTeal | `#00C3D0` | `#00D2E0` |
| systemIndigo | `#6155F5` | `#6D7CFF` |
| systemPink | `#FF2D55` | `#FF375F` |
| systemGray | `#8E8E93` | `#98989D` |

---

## 4. Fonts

Three families, all Nerd Font-patched. _(In this repo the font files live in
`../overrides/fonts/`, and the working fontconfig is
`../overrides/fontconfig/conf.d/99-cllpse-macos-ui-font.conf` — the `fonts.conf` beside this
document is BUILD's original, superseded on Arch. See `overrides/README.md`.)_

| Family | Use |
|---|---|
| **`SFMono Nerd Font Mono`** | terminals, editors, btop, anything on a character grid |
| **`SFProText Nerd Font Propo`** | all UI below 20pt |
| **`SFProDisplay Nerd Font Propo`** | 20pt and above |

macOS selects between the two proportional faces by optical size — **Text below
20pt, Display at 20pt and up**. Reproduce that crossover in fontconfig rather
than per-application; it works on both `size` and `pixelsize` and composes
correctly with weight (verified with `fc-match`).

### Generic and alias targets

| Requested | Resolves to |
|---|---|
| `monospace`, `ui-monospace` | SF Mono |
| `sans-serif` | SF Pro Text |
| `system-ui`, `-apple-system`, `BlinkMacSystemFont` | SF Pro Text |
| `serif` | leave as Omarchy has it — macOS has no system serif |

Omarchy's shipped `fonts.conf` already points those three Apple aliases at
`Liberation Sans` — the families every web page and Electron app names when it
wants the Apple system font. Repointing them is the single highest-leverage
change in the theme.

A working, verified `fonts.conf` is included beside this document.

### Weights available

Verified with `fc-scan` against the 20 files in `fonts/` — this is what was
supplied, not the full extent of Apple's families. Grouping is correct: every
weight reports the base family name, so weight selection resolves within one
family.

| Family | Weights | Italics |
|---|---|---|
| SF Mono | Light, Regular, Medium, SemiBold, Bold, Heavy | all six |
| SF Pro Text | Regular, Medium, SemiBold, Bold | **none** |
| SF Pro Display | Light, Regular, SemiBold, Bold | **none** |

SF Pro needs synthetic oblique — without it, italic requests render upright.
SF Mono has real italics and must be excluded from any synthesis rule.

### Surface → face → weight

| Surface | Face | Size | Weight |
|---|---|---|---|
| Terminals | SF Mono | 9 (Omarchy default) | 400 / 700 |
| btop, Helix | SF Mono | — | 400 |
| Bar labels | SF Pro Text | 13 (`NSFont.menuBarFont`) | 400 |
| Bar clock, active workspace | SF Pro Text | 13 | 500 |
| Notification title | SF Pro Text | 13 | 600 |
| Notification body | SF Pro Text | 13 | 400 |
| OSD label | SF Pro Text | 13 | 500 |
| Launcher results | SF Pro Text | < 20 | 400 |
| Launcher input | SF Pro Display | ≥ 20 | 400 |
| Lock-screen clock | SF Pro Display | large | 300 |
| Lock prompt, labels | SF Pro Text | < 20 | 400 |
| GTK apps, dialogs | SF Pro Text | 13 | 400 / 700 |
| Web, Electron | SF Pro Text | — | 400–700 |

### Type scale [measured]

`NSFont.systemFontSize` is **13.0** on macOS 27, not 12. The shell's `base-size`
should be 13. Sizes below are macOS's own text styles, read from
`NSFont.preferredFont(forTextStyle:)`:

```
caption 10   (caption1 / caption2 / footnote)
body-small 11 (subheadline)          callout 12
body 13      (body / headline)       title 15  (title3)
heading 17   (title2)                display 22 (title1)
display-large 26 (largeTitle)
```

Note `headline` is 13pt Bold and `body` 13pt Regular — macOS separates them by
weight, not size.

### Line height

**The shell does not expose it.** `Style.font.*` carries sizes only — there is no
line-height, leading or vertical-spacing key in `shell.toml`. Vertical rhythm in
the bar, menus, launcher and notifications is set by the box around the text
instead: `control-height`, `popup-row-height`, `row-gap`, `label-gap` and
`control-padding-y` in `[spacing]`. Treat those as the line-height equivalent.

**Terminals don't need it.** The supplied fonts carry hhea `ascender 1950`,
`descender -494`, `lineGap 0` at `unitsPerEm 2048` — a line box of **1.193 em**,
identical across all three families. macOS's own ink height is 1.178 em, so the
patching did not inflate the metrics: a terminal using these fonts untouched
lands within ~1% of macOS. At 9pt both give exactly 11px. Leave cell height
alone unless something looks visibly wrong; the lever, if ever needed, is the
emulator's own setting (Ghostty `adjust-cell-height`, foot `line-height`, kitty
`modify_font cell_height`) — not a theme file, and terminal configs are stripped
from git-cloned themes anyway.

**Nothing else is reachable.** GTK apps take line height from font metrics, and
web content from page CSS; neither is themeable.

macOS line heights, measured with `NSLayoutManager.defaultLineHeight` — note it
rounds to whole points rather than applying a constant ratio, so the effective
ratio drifts between 1.15 and 1.25:

| size | 10 | 11 | 12 | 13 | 15 | 17 | 22 | 26 |
|---|---|---|---|---|---|---|---|---|
| line height | 12 | 13 | 15 | 16 | 18 | 20 | 26 | 30 |

SF Pro and SF Mono share these metrics, so mixed text and code align vertically.

---

## 5. Window treatment

Omarchy 4 defaults: `gaps_in 5`, `gaps_out 10`, `border_size 2`, `rounding 0`,
shadow off, blur off. Windows are **not** opaque — `windows.lua` tags every
window `default-opacity` and applies `opacity = "0.985 0.96"`. That rule has to
be overridden; opacity 1.0 is not the default you inherit.

Three facts drive the mapping:

1. **macOS app windows are opaque.** Translucency is reserved for shell
   surfaces — menu bar, Spotlight, notifications, popovers. Override Omarchy's
   `default-opacity` rule to `1.0 1.0`.
2. **Blur belongs on layer surfaces**, not windows — the shell's layers, via
   Hyprland layer rules.
3. **Focus is signalled by shadow depth**, not a coloured border: a hairline
   edge plus a large soft shadow.

| Setting | Value | Basis |
|---|---|---|
| rounding | `14` | macOS window corner radius [chosen] — 26 is the reported Tahoe toolbar-window figure, but it is third-party and dramatic on tiled windows; 14 sits just above the 12 fallback below and is treated as satisfying this row |
| border_size | `2` | macOS hairline edge is 1, but that is a weak focus cue in a tiling WM [chosen] — 2 is also the Omarchy default |
| gaps_in | `8` | Apple 8pt layout grid [chosen] |
| gaps_out | `16` | 2× inner step [chosen] |
| shadow range | `40` | large and soft [chosen] |
| shadow offset | `0 8` | macOS shadows sit below the window [chosen] |
| shadow colour | `rgba(00000040)` | [chosen] |
| blur size / passes | `10` / `4` | NSVisualEffectView is a heavy blur [chosen] — effective spread ≈ size × 2^(passes−1), so ≈80. `size` scales sampling offsets and is essentially free; each `pass` adds a downsample+upsample iteration (~+30% blur work). 4 passes for the soft, diffuse falloff of a large macOS material; size trimmed from 12 (≈96), which washed the backdrop out rather than suggesting it |
| blur vibrancy / vibrancy_darkness | `0.30` / `0.30` | macOS boosts saturation behind glass [chosen] — Hyprland leaves vibrancy_darkness at 0, which barely touches dark backdrops and left the dark theme's glass flat next to the light one; matched so both saturate alike |
| blur brightness / contrast | `1.0` / `1.0` | macOS does not darken [chosen] — Hyprland defaults to 0.8172 / 0.8916 |
| blur noise | `0.02` | frosted grain, just above Hyprland's 0.0117 [chosen] — largely academic at these alphas: only 8–12% of the noisy backdrop shows through the menu (0.92) or a window (0.875) |
| active / inactive opacity | `1.0` / `0.875` | focused opaque per macOS; unfocused translucent so the blur pass renders through them — glass, not a flat dim [chosen] — overrides Omarchy's 0.985/0.96 |
| dim_inactive | `false` | [chosen] — tried at 0.10 and removed; a darkening pass stacked on the unfocused opacity muddied it and worked against the blur-through the opacity is there for |

The 26pt figure comes from third-party reporting on Tahoe, not from a
measurement of this machine — treat it as approximate. Tahoe radii are not
uniform: windows without a toolbar are less rounded, and pre-Tahoe macOS used
~10–12pt. 26 is also dramatic on tiled windows.

**Shipped: 14**, just above the 12 fallback and inside the pre-Tahoe range. This
is the settled value, not a deferred approximation — it satisfies this row, and
the 26 above is kept only as the provenance of where the number came from.
`border_size = 2` likewise settles the row below.

`border_size = 1` is the faithful hairline, but a weak focus cue in a tiling WM —
hence the 2 above.

Window decoration belongs in the user Hyprland config, not the theme: v4 strips
`.lua` files from git-cloned themes, so a theme-shipped decoration file would
silently stop working if the theme is ever shared.

---

## 6. Shell surfaces

Omarchy 4's shell reads surface roles, control states, spacing, typography and
bar sizing from `shell.toml`. Sections can be overridden individually.

### Opacity

The Omarchy column is [measured] from `shell.toml`; the macOS column is
[chosen] — tune against a real screenshot:

| Surface | Omarchy | macOS |
|---|---|---|
| bar | 1.0 | **0.72** — menu bar is translucent over the wallpaper |
| launcher | 0.95 | **0.85** — Spotlight is more translucent |
| launcher scrim | 0.5 | **0.35** — macOS dims the desktop only lightly |
| menu | 1.0 | **0.92** — near-opaque glass |
| tooltip | 0.97 | 0.97 — already correct |
| notifications | 1.0 | **0.92** |
| lock | 0.8 | 0.8 — already correct |

**All of these depend on layer blur reaching the shell's surfaces.**
Translucency without blur looks washed out, not like macOS. If blur can't be
applied to those layers, set every value back to 1.0 and say so — don't ship
half the effect.

### Bar

macOS menu bar is **22pt** tall — `NSStatusBar.system.thickness` on macOS 27
[measured]. Omarchy's bar size default is 26.

### Spacing — Apple 8pt grid [chosen]

```
xxs 2 · xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 24 · xxxl 28 · huge 32
```

Omarchy's defaults are tighter (2/3/4/6/8/10/12/14/18). The 8pt grid is more
generous — that is the macOS feel, but check it doesn't overflow a 22pt bar.
Prefer scaling over hand-editing individual tokens.

### Corner radius

Shell surfaces (menus, popovers) want ~12 [chosen] — distinct from the window
`rounding` of 26. The shell exposes a corner-radius style token; its config key
is not documented and needs discovery on the running system.

---

## 7. Notes

1. **macOS has no bright colour tier.** The two appearance variants sit close
   together: orange +3.9%, red +4.8%, yellow +7.6%, blue +10.6%, green +11.0%,
   magenta +18.5%, cyan +25.7% luminance. Terminal convention expects 25–40%, so
   `bright_red` will read much like `red`. That is what the system palette is —
   ship it as given.
2. **Light-appearance hues are low-contrast on white**: yellow 1.51:1, cyan
   2.16:1, green 2.22:1, orange 2.31:1. macOS uses them as fills behind dark
   text rather than as text itself. Use them the same way; do not darken them.
3. **`omarchy-font-set` destroys this typography.** It is monospace-only and
   rewrites `fonts.conf` wholesale. Style ▸ Font in the Omarchy menu runs it.
4. **SF Pro Text has no Light; SF Pro Display has no Medium.** fontconfig falls
   to the nearest weight silently — Display@500 rounds *down* to Regular, not up
   to SemiBold. Adding SF Pro Text Light and SF Pro Display Medium would close
   the ladder across 300–700.
5. **`conf.d` differs between distributions.** Font resolution was verified
   against Homebrew's fontconfig; Arch ships a different set. Confirm
   `ui-monospace` resolves to SF Mono and not SF Pro on the target box.
