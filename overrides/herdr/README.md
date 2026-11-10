# Herdr theme

Herdr, the terminal workspace for coding agents, draws its terminals and the
panels around them (sidebar, tabs, cards, status dots) from a theme of its own,
not from Omarchy: four presets (`graphite`, `ink`, `moss` dark, `paper` light)
or any `~/.config/herdr-app/themes/<name>.json`. `herdr.sh` renders both
themes' `colors.toml` as two such files and makes them the app's light/dark pair:

```
themes/cllpse-macos-light.json   light
themes/cllpse-macos-dark.json    dark
```

Light or dark is the desktop portal's colour scheme
(`org.freedesktop.appearance color-scheme`), which `omarchy theme set` flips
through gsettings, so the app follows the theme with no hook of its own. Both
files are written on every run, whichever theme is active. The `herdr` TUI and
its `~/.config/herdr/config.toml` are a different program and untouched.

The app's icon is not this step's: `overrides/icons/verbatim/herdr-app.svg`
(Herdr's own ram-on-tile mark, kept in its colours) reaches the menu and the
switcher through `~/.icons/cllpse-color/apps/` on every theme set, outranking
the `hicolor` copy `~/.local/share/icons/` carries. See `../icons/AGENTS.md`.

## How it gets in

Read from the app's own `~/.config/herdr-app/AGENTS.md` and its `themes()`
API, 0.1.14, on 2026-11-09:

- A theme file is `{ background, foreground, selection, cursor?, ansi[16],
  colors? }`. Herdr derives the panel colours from the terminal ones and lays
  `colors` over that by name; the theme's lightness comes from `background`.
  The names are what the mods' `theme()` returns: `background`, `surface`,
  `canvas`, `chrome`, `popover`, `raised`, `hover`, `selected`, `border`,
  `input`, `foreground`, `muted`, `dim`, `accent`, `accent_foreground`,
  `solid`, `solid_foreground`, `selection`, `ring`, `working`, `blocked`,
  `done`, `idle`, `unknown`, `cursor`, `terminal_foreground`, `ansi0..15`.
  A probe mod that throws `JSON.stringify(themes())` under `herdr-app check`
  prints every preset with its derived values; that is how the list above and
  the derivation were read.
- Three places say which theme shows, in this order: the theme picker's saved
  choice for the layout (`layouts/.state/main.json`, key `theme`), the layout
  file's own `theme` (the shipped `main` has none), then `settings.json`'s.
  Each is a name or a `{light, dark}` pair. The step writes the pair into
  `settings.json` (merged; fonts and zoom stay) and into the picker's state,
  because a machine where the picker was ever used has that state and the
  setting is never consulted.
- The picker's state is the window's: held in memory while it is open, written
  when its own pick changes, never read back. So with a window open the step
  goes through the CLI, `herdr-app do app.theme --name <theme>`, which sets the
  half of the pair matching the named theme's lightness, re-reads the theme
  file, and writes the state. A pick the window already has writes nothing, so
  when the file still disagrees afterwards (an edit made while the window was
  open) the step picks `paper`/`graphite` and ours again to force the write.
  Without a window `herdr-app do` fails and the file is edited directly, which
  is safe exactly then.
- A theme file is re-read on `app.theme`, so a changed `colors.toml` lands in
  the open window by running the step again; a closed app reads it at start.

`herdr.sh --print` writes both files to stdout and changes nothing.

## Keys: the keys dialog unbound

`herdr.sh keys`, the `herdr-keys` step, merges [`keys.json`](keys.json) in this
directory into `~/.config/herdr-app/keys.json`, which Herdr reads live. It has
the shape of Herdr's own file, sections of chord to action; a `null` action
removes the chord, anything else sets it, and chords not named are left alone.
Today it unbinds the three chords of `app.help`, the keys dialog: `ctrl-?`,
`ctrl-shift-/` and `ctrl-shift-?`, which Cmd+Shift+/ reaches through the keyd
forwarder and lands on while typing `?` into an agent. The dialog stays
reachable from the command palette (`ctrl-shift-p`).

Herdr treats any edited `keys.json` as the person's and stops refreshing it on
upgrade (its `AGENTS.md`, *Keys*), so once this has run a new default chord of
a later release has to be added by hand. `herdr.sh keys --revert` puts each
chord back as recorded on the first apply
(`~/.local/state/cllpse-macos/previous-herdr-keys`), where it is still unbound.

## What it carries

**Terminal**: Ghostty's palette, slot for slot, the keys Omarchy's
`ghostty.conf.tpl` uses: `ansi0` is `background`, `ansi7` is `foreground`,
`ansi8` is `muted`, `ansi15` and the cursor are `bright_foreground`, the rest
the matching hue and `bright_` hue. Plus `selection`.

**Panels** (`colors`), every one named so nothing is derived:

| Herdr | `colors.toml` |
|---|---|
| `foreground` | `foreground` (labelColor) |
| `muted` | `dark_foreground` (secondaryLabelColor) |
| `dim`, `idle`, `unknown` | `muted` (tertiaryLabelColor) |
| `surface` | `background` |
| `chrome`, `canvas` | `dark_background` (the sidebar) |
| `popover` | `lighter_background` |
| `accent`, `ring` | `accent`; `accent_foreground` white |
| `solid` / `solid_foreground` | `light_foreground` / `background` (a primary button, ink on paper) |
| `selection` | `selection` |
| `working` | `orange` |
| `blocked` | `red` (`bright_red` in dark) |
| `done` | `green` (`bright_green` in dark) |

The tones not in the palette are macOS's cuts from `textColor`, so they are
`light_foreground` over `background`: `border` 10% (light: `#e6e6e6`, which is
`darker_background` exactly), `hover` 5%, `selected` 10%, `input` 20%, and
`raised` 5% over `popover`. Herdr's presets use translucent whites for these;
opaque mixes are used here because the theme file's format is documented as
`#rrggbb`.

Herdr's own status colours are yellow for working and blue for done. Orange
and green are the palette's: the system's warning and success hues, and the
light theme's yellow is unreadable on white.

## Undoing it

`herdr.sh --revert`, which `revert.sh` runs, puts `settings.json`'s `theme` key
back as recorded on the first apply (`~/.local/state/cllpse-macos/previous-herdr-theme`,
absent means removed), moves the main layout's pick back to what it was
(`previous-herdr-picker`; through the open window if there is one, where a
pick cannot be removed, only moved, so Herdr's own `paper`/`graphite` stand in
when nothing was recorded), and removes both theme files.
