# Superset theme

Superset (Paradev), the agent workspace app, draws its own chrome, terminals and
code views from a theme list of its own, not from Omarchy. `superset-theme.sh`
renders both themes' `colors.toml` as two Superset custom themes and points the
app's system light and dark slots at them:

```
cllpse-macos-light   "cllpse-macos Light"   systemLightThemeId
cllpse-macos-dark    "cllpse-macos Dark"    systemDarkThemeId
```

The active theme is set to `system`, so Superset follows the OS appearance, and
the OS appearance follows `omarchy theme set`. Nothing here needs a theme-set
hook: both themes are written on every run, whichever Omarchy theme is active.
Superset's icon fix is a separate step, [`../superset/`](../superset/README.md).

## How it gets in

Read from the bundle (`resources/app.asar`, source maps included), 2.0.0, on
2026-10-29:

- A custom theme is `{id, name, type, ui, terminal, editor?}`. The importer
  (`packages/shared/src/themes/import.ts`) takes one theme, an array, or
  `{themes: [...]}`, and lays each over the built-in light or dark, so a missing
  token inherits instead of failing. The *persisted* schema is stricter: every
  `ui` key and a full `terminal`. The importer's output satisfies it; a hand
  edit of `app-state.json` has to.
- `themeState` lives in `~/.superset/app-state.json` and Superset holds it in
  memory. The CLI writes it and nudges the running app (`/settings-changed`),
  which reloads `themeState` from disk and applies it live. A hand edit while
  the app runs is overwritten at its next flush, so the script goes through the
  CLI only:

  ```
  superset settings theme import <pack.json>
  superset settings theme set system --system-light cllpse-macos-light --system-dark cllpse-macos-dark
  ```

- Importing an id that exists replaces it in place, so a run is idempotent and
  a changed `colors.toml` lands by running the step again.
- `system` resolves through `prefers-color-scheme`, i.e. Electron's
  `nativeTheme`, i.e. the portal colour scheme Omarchy flips. Superset does not
  force a theme source.
- `light`, `dark` and the other built-ins are reserved ids. Ours are not.

`superset-theme.sh --print` writes the pack to stdout and changes nothing.

## What it carries

**Terminal**: Ghostty's palette, slot for slot, the keys Omarchy's
`ghostty.conf.tpl` uses: `black` is `background`, `white` is `foreground`,
`brightBlack` is `muted`, `brightWhite` and the cursor are `bright_foreground`,
the rest are the matching hue and `bright_` hue. It also carries the selection
(`selectionBackground`, `selectionForeground`), which a terminal theme in
Warp's format cannot.

**Chrome** (`ui`):

| Superset token | `colors.toml` |
|---|---|
| `background`, `foreground` | `background`, `foreground` |
| `sidebar`, `tertiary` | `dark_background` |
| `card`, `popover` | `lighter_background` |
| `mutedForeground` | `dark_foreground` |
| `primary`, `ring`, `sidebarPrimary`, `highlight` | `accent` |
| `destructive`, `success` | `red` / `green` (the `bright_` pair in dark) |
| `warning` | `orange` |
| `chart1` … `chart5` | `blue`, `green`, `orange`, `magenta`, `cyan` |
| `highlightMatch`, `highlightActive` | `yellow` at 35%, `orange` at 55% |

The only tones not read from `colors.toml` are the borders and fills, which
macOS cuts from `textColor` at fixed alphas, so they are `light_foreground`
over `background`: 10% for `border`, `input`, `sidebarBorder` and the active
fills, 5% for `secondary`, `muted` and hover. In the light theme the 10% tone is
`#E6E6E6`, which is `darker_background` exactly: the rule reproduces a value the
palette already holds.

**Editor and diff** are not written. Superset derives them from the terminal
palette and `ui` when a theme has no `editor` block, so syntax follows the macOS
hues.

## Known gap: the light theme's syntax colours

Measured on 2026-10-29 with the app's own `getEditorTheme` and culori's WCAG
ratio, on `#FFFFFF`: numbers and class names (`#FFCC00`) 1.5, strings (`#34C759`)
2.2, types (`#00C0E8`) 2.2, comments (`#BDBDBD`) 1.9. Dark is 4.0 to 11.0, with
comments at 2.3. Fixing light needs an `editor.syntax` block with darker hues,
and those are not in `colors.toml`, which is authoritative. They are left as the
palette gives them, the same yellow and green light Ghostty already shows.

## Undoing it

`superset-theme.sh --revert`, which `revert.sh` runs, sets a system slot back to
Superset's own (`light` / `dark`) only if it still names ours, and removes both
themes. It leaves the active theme at `system`.
