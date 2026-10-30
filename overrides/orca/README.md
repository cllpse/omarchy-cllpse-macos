# Orca

Orca, the agent IDE (an AppImage, `stablyai/orca`), draws its terminals with
xterm.js and themes them from its own list, not from Omarchy. `orca.sh` renders
[`warp-theme.yaml.tpl`](warp-theme.yaml.tpl) once per theme, from each theme's
`colors.toml`, into the folder Orca's Warp import scans:

```
~/.local/share/warp-terminal/themes/cllpse-macos-light.yaml   "cllpse-macos Light"
~/.local/share/warp-terminal/themes/cllpse-macos-dark.yaml    "cllpse-macos Dark"
```

Both files are written on every run, whichever theme is active, because Orca
keeps a light and a dark terminal theme of its own and picks between them from
the system's colour scheme.

## Why Warp's YAML

Read from the bundle, `resources/app.asar`, 1.4.239, on 2026-10-24:

- Orca has no theme file it reads at startup. Imported terminal themes are
  copies kept in its settings (`terminalCustomThemes`, in
  `~/.config/orca/profiles/<profile>/profile-state.db`), and it imports them
  from two places: Warp theme YAML, or the Ghostty config.
- **Import from Ghostty** reads `~/.config/ghostty/config` (and
  `config.ghostty`) and does not follow `config-file =`. The bundle never
  mentions it. That is how Omarchy gives Ghostty its colours
  (`~/.local/state/omarchy/current/theme/ghostty.conf`), so here it finds none.
  Where it does find colours, it writes them as `terminalColorOverrides`, which
  Orca lays over *whichever* terminal theme is showing, in both modes, and it
  takes Ghostty's font, size and padding too.
- **Import from Warp** turns each YAML file into a named theme that can be
  picked separately for dark and for light. On Linux, the automatic scan reads
  `$XDG_DATA_HOME/warp-terminal/themes/` (then `~/.local/share`), along with the
  `warp-*` variants, down into subfolders. It does not need Warp installed. A
  real Warp reads the same folder, so the two themes would show up there too.

The parser (`out/main/warp-theme-parser-worker.js`) reads `name`,
`background`, `foreground`, `cursor` (falling back to `accent`, Warp's own key)
and `terminal_colors.normal` / `.bright`. It reads the theme's mode from the
background's luminance, with `details` (`darker` / `lighter`) as a fallback.
Nothing else is read.

## What it carries: Ghostty's palette, slot for slot

The template uses the keys Omarchy's own `ghostty.conf.tpl` uses, in the same
slots, so what Orca imports is what Ghostty is given:

| Warp key | Ghostty key | `colors.toml` |
|---|---|---|
| `background` | `background` | `background` |
| `foreground` | `foreground` | `foreground` |
| `cursor` | `cursor-color` | `bright_foreground` |
| `normal.black` | `palette = 0` | `background` |
| `normal.red` … `normal.cyan` | `palette = 1` … `6` | `red` … `cyan` |
| `normal.white` | `palette = 7` | `foreground` |
| `bright.black` | `palette = 8` | `muted` |
| `bright.red` … `bright.cyan` | `palette = 9` … `14` | `bright_red` … `bright_cyan` |
| `bright.white` | `palette = 15` | `bright_foreground` |

Checked on 2026-10-24 by running Orca's own parser worker over both files and
comparing its output with `ghostty.conf.tpl` rendered from the same
`colors.toml`. All 19 slots matched under both themes, and the light render was
byte-identical to the live `ghostty.conf`.

`accent` is in the file only because a Warp theme needs it. Orca uses it only
when `cursor` is missing.

## What does not carry over: the selection colour

Ghostty also gets `selection-background` and `selection-foreground`
(`#B3D7FF` / `#000000` light, `#3F638B` / `#FFFFFF` dark). Warp's format has no
selection key. Orca's custom themes do have the slots, but its Warp parser
never fills them, and it falls back to nothing in between. xterm.js then draws
its default, `rgba(255, 255, 255, 0.3)`: a grey wash under the dark theme, and
**invisible on the light theme's `#FFFFFF`**.

Orca's Settings has a Selection Background colour, but it is one of the
`terminalColorOverrides` above. It applies in both modes, so it cannot hold the
two themes' values. Writing the slots into each imported theme would mean
editing Orca's settings database, which this step does not touch.

## Setting it up in Orca

Once, after the first run. In Orca's Settings, under **Terminal Themes**:

1. **Import from Warp**: both themes are listed under "Warp themes". Import them.
2. Turn **Match dark mode** off. While it is on, Orca shows the dark terminal
   theme in light mode too (`terminalUseSeparateLightTheme: false`).
3. Set **Theme Mode** to Dark and pick *cllpse-macos Dark*, then set it to Light
   and pick *cllpse-macos Light*.

Orca's app theme must be *System* (its default) for the terminal to follow
`omarchy theme set`. Orca then takes light or dark from the renderer's
`prefers-color-scheme`, which Omarchy's theme set drives through the GNOME
`color-scheme` key. That is read from the code. A live switch has not been
watched yet.

## After a colour change

Orca keeps the copy it imported, so a `colors.toml` change reaches it only
through another import. `apply.sh orca` names each file it changed, then
**Import from Warp** again. The scan gives each file the id
`warp:<name>:<file name>`, and an import replaces a theme with the same id in
place, so the Dark and Light picks stay put.

Script: [`orca.sh`](orca.sh) — runnable on its own; [`../apply.sh`](../apply.sh)
owns the order. It skips when `~/.config/orca/profiles` does not exist, which
means Orca has never run (the GNOME screen reader of the same name keeps its
files in `~/.local/share/orca`, so `command -v orca` would not do).
