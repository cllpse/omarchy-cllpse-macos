# omarchy-cllpse-macos

Two Omarchy 4.0.4 themes (`quattro` branch) reproducing the macOS appearance, plus
machine-level overrides and a window-switcher plugin. **`master` is stale at 3.8.5**
and documents an incompatible theme format — do not read it.

**The window switcher is a submodule:** `omarchy-cllpse-plugin-switcher/` →
[cllpse/omarchy-cllpse-plugin-switcher](https://github.com/cllpse/omarchy-cllpse-plugin-switcher).
Clone with `--recurse-submodules`. Edits to `Hud.qml` require commits in that repo
plus a submodule pointer bump here — two commits, not one.

Start with [`README.md`](README.md) for repo layout,
[`overrides/README.md`](overrides/README.md) for what `apply.sh` touches,
and [`reference/BUILD.md`](reference/BUILD.md) for the colour spec.

**Before editing anything, read [`AGENTS.md`](AGENTS.md) for task patterns.**

---

## Mechanics that silently break

### Themes and the live desktop

**`omarchy theme set` copies, it does not symlink.** It runs
`cp -r ~/.config/omarchy/themes/<name>/* ~/.local/state/omarchy/current/theme/`.
Editing a theme folder changes nothing until a theme-set re-runs. Symlinks
inside a theme folder are copied as symlinks and relative links pointing
outside the folder break. Keep real files in `backgrounds/`.

### Hyprland config load order

`default.hypr.omarchy` → `default/hypr/looknfeel.lua` → `input.lua` →
`windows.lua` → **theme's `hyprland.lua`** → user files
(`hypr/monitors|input|bindings|looknfeel|autostart`). Our overrides live in
the user files, so they land last and win.

### Window opacity works through a tag

`windows.lua` tags every window `+default-opacity`. Per-app files under
`default/hypr/apps/` **strip that tag** from things that must stay opaque
(DaVinci Resolve, PiP, Steam, browsers, QEMU, etc.). Only then is
`opacity = "0.985 0.96"` applied to whatever still carries it.

**Match the tag, never `.*`.** A blanket match silently overrides every
deliberate exclusion and dims colour-critical and video windows.
Figma Desktop was added: `.*[Ff]igma.*` against the class (live class is
lowercase `figma-desktop`), untagged and pinned to `1 1`.

### Generated files (never commit)

`btop.theme`, `hyprland.lua`, `vscode-theme.json`, `neovim.lua`, and terminal
colour files are produced from `colors.toml` on every theme-set. Omarchy strips
`.lua` from git-cloned themes; our themes are symlinked so nothing is stripped.

### App icons

The Omarchy menu draws app rows as a plain `Image` with no recolouring
(`Menu.qml:1253`). Vendor logos stay full-colour.

`AppLibrary.iconSource()` consults its own index before the themed lookup, so
`icon-theme` barely matters for apps. `$HOME/.icons` is the **first directory
scanned**, so a file dropped there outranks every installed theme. We use this
for our drop-in icon sets (`~/.icons/cllpse-flat/` and `cllpse-color/`).

The switcher reads four icon sources; the optional `~/.icons/cllpse-flat/apps/`
is one of them. See `overrides/icons/AGENTS.md`.

## Unreachable on 4.0.4 — don't re-litigate

These were checked against 4.0.4, not carried forward. The probes are named so
the next bump is a re-run.

- **Bar font family:** `Style.qml` hardcodes `fontFamily = "monospace"`. Cannot
  be done through config. Probe:
  `grep -n fontFamily /usr/share/omarchy/shell/Commons/Style.qml`

- **Bar-only text/icon sizing:** `[bar] icon-font` / `icon-slot` /
  `icon-canvas` / `status-slot` are read by `Style.bar` but never populated
  by `applyShellValues` — dead keys.

- **The whole `[launcher]` section** is a dead section. SUPER+SPACE is the
  **menu** plugin (`omarchy-menu`), so `shell.menu.toml` styles it. The
  `shell.launcher.toml` files are spliced into `shell.toml` and read by nobody.

- **Font size** is machine-level only: `~/.config/omarchy/shell.toml`
  `[font] base-size`. Themes must not touch it.

- **`Style.qml` and `Color.qml` live in `shell/Commons/`, not `shell/Ui/`**.

## Traps already hit

Selective — the full list is in git history of this file. What's worth
retaining across version bumps:

### jq `//` drops `false`

`.bar.transparent // empty` emits nothing for `false`. Use:
`.key | if . == null then empty else tostring end`. Same trap for any
boolean or zero default behind `//`.

### Lua `{ class = nil }` is `{}` — matches everything

`hl.get_windows({ class = x })` with nil `x` is `hl.get_windows({})`,
matching every window. Guard the value before it reaches the table.

### `grep -qxF` with pattern starting with `-`

`grep -qxF "-- >>> cllpse-macos overrides >>>"` fails with
`invalid option`. Always pass with `-e`:
`grep -qxF -e "-- >>> cllpse-macos overrides >>>"`.

### `sed` range matching on `.lua` files

GNU sed's range address re-arms after each closing match, so one pass removes
all fenced blocks, not just the first.

### Hyprland `hl.dsp` takes keyword args

`hl.dsp.window.close({ window = w })` closes that window.
`close(w)`, `close(w.address)`, `close("address:0x…")` all close **nothing**
with no error. Test on an unfocused window.

### `hyprctl dispatch` takes an expression

Multi-statement chunks silently fail with `expected a dispatcher` on stdout.
Use `hyprctl eval` for anything with more than one statement.

### `hyprctl keyword` / `dispatch` are Lua-only now

They print a helpful error and change nothing. Use `hyprctl eval` with
`hl.config(...)` or `hl.dispatch(...)`.

### `keyd` group membership

`usermod -aG` does not reach existing processes; supplementary groups are
fixed at process creation. `systemctl restart user@1000` reseeds it (kills
the desktop). `newgrp keyd` runs a command with the correct group set.

### `pgrep -f` matches whole command lines

It matches the *caller*. Resolve `/proc/<pid>/exe` instead.

### `keyd check <file>` validates without root

Worth using before anything reaches `/etc`: keyd exits on parse errors and
presents as a quietly unmappable keyboard.

### `keyd bind` / `keyd listen` / `keyd monitor`

These are the runtime inspection tools. There is **no way to query runtime
binds** — the only check is issuing one and reading the exit status.

### Bash `printf` parses `\u` in the format string

`printf "\u%04x" 0xf268` is a parse error. Build the escape as data:
`printf '%b' "\u$hex"`.

### ImageMagick `-extent` pads with background colour

A transparent icon centred on a canvas gains an opaque white box unless
`-background none` is repeated before `-extent`.

### ImageMagick `-strip` before output filename

PNG `date:create`/`date:modify` chunks make two runs differ. `-strip` makes
idempotent output.

### `String.fromCharCode` is 16-bit, truncates codepoints

Use `String.fromCodePoint` for U+10000+ (Material Design range).

### `sourceSize` on SVG means rasterization resolution

Leaving it unset rasterises at the SVG's intrinsic size, then scales up.
Set it to `drawn × Screen.devicePixelRatio` (2 here, not 1.25).

### Recolouring SVGs with regex has three failure modes

Single-quoted attributes (Inkscape), character classes that run past `}`
or `<`, and files with no paint at all (simple-icons bare `<path>`).

## Where to find things

| Question | File |
|---|---|
| What does `apply.sh` touch? | `overrides/README.md` |
| Colour spec and provenance | `reference/BUILD.md` |
| App icon adding workflow | `overrides/icons/AGENTS.md` |
| Switcher icon contract | `omarchy-cllpse-plugin-switcher/AGENTS.md` |
| Task patterns for agents | `AGENTS.md` (this dir) |
| Per-app override details | `overrides/<app>/README.md` |
| Window switcher design log | `reference/window-switcher-notes.md` |
| Keybind parity audit | `KEYBINDS-PARITY.md` |

