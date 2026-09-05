# Working on omarchy-cllpse-macos

Two Omarchy 4 themes reproducing the macOS appearance, plus the machine-level
overrides and the window-switcher plugin they need.

Start with [`README.md`](README.md) for layout, [`overrides/README.md`](overrides/README.md)
for what `apply.sh` touches, and [`reference/BUILD.md`](reference/BUILD.md) for the
spec. This file is only for what those don't say: how Omarchy itself behaves, and
the traps that have already cost time.

Target is **Omarchy 4.0.2** (`quattro`). The `master` branch is stale at 3.8.5 and
documents an incompatible theme format — don't read it.

---

## Omarchy mechanics worth knowing

**`omarchy theme set` copies, it does not symlink.** It runs
`cp -r ~/.config/omarchy/themes/<name>/* ~/.local/state/omarchy/current/theme/`.
So editing a theme folder changes nothing on the live desktop until a theme-set
re-runs — that step is what *publishes* a new background or a changed
`shell.*.toml`. `apply.sh` step 8 exists for this as much as for switching.

Because it is `cp -r`, **symlinks inside a theme folder are copied as symlinks**
and any relative link pointing outside the folder breaks in the state copy.
That killed an attempt to de-duplicate wallpapers through a shared directory.
Keep real files in `backgrounds/`; git already stores identical content as one
blob, so duplicates cost checkout space, not repo size.

**Hyprland config load order** (from `~/.config/hypr/hyprland.lua`):
`default.hypr.omarchy` — which pulls in `default/hypr/looknfeel.lua`, then
`input.lua`, then `windows.lua`, then the current theme's `hyprland.lua` — and
*then* the user files `hypr/monitors|input|bindings|looknfeel|autostart`. Our
overrides live in the user files, so they land last and win. `hl.*` is
Hyprland's native Lua API; `o.*` is Omarchy's helper layer over it
(`o.window` → `hl.window_rule`), defined in `default/hypr/helpers.lua`.

**Window opacity runs through a tag.** `windows.lua` tags every window
`+default-opacity`, per-app files under `default/hypr/apps/` strip that tag from
things that must stay opaque (DaVinci Resolve, PiP and webcam overlays, Steam,
QEMU, RetroArch, YouTube/Zoom web apps; browsers set their own `1.0 0.985`), and
only then is `opacity = "0.985 0.96"` applied to whatever still carries it.
**Match the tag, never `.*`** — a blanket match silently overrides every one of
those deliberate exclusions and dims colour-critical and video windows.

**Backgrounds are filtered by extension.** Both `omarchy-theme-bg-next` and
`omarchy-menu-images` enumerate with
`-iname '*.jpg' -o '*.jpeg' -o '*.png' -o '*.gif' -o '*.bmp' -o '*.webp'`.
**`.heic` is invisible** — not listed, not selectable, not displayable. They use
`find -L`, so symlinked images *are* followed and matched on the target's type.

**Fonts.** `omarchy-font-set` generates `~/.config/fontconfig/fonts.conf`
wholesale (deleting it is the clean undo) *and* sed-edits the Alacritty, Kitty,
Ghostty and Foot configs in place. There is no `omarchy font reset` and no
`theme reset`; `gsettings reset` is the only true reset available. The font
switcher is monospace-only (`fc-list :spacing=100`), so SF Pro can never appear
in it.

Hinting has three separate knobs that don't share state: the fontconfig drop-in
(Qt, Alacritty, Electron), `gsettings font-hinting` (GTK/GNOME), and Ghostty's
own `freetype-load-flags`. Kitty hardcodes light hinting with no override.

**Unreachable on 4.0.2** — don't re-litigate these:
- *Bar font family*: `Style.qml` hardcodes `fontFamily = "monospace"`. BUILD.md
  §4's "bar in SF Pro Text" cannot be done through config.
- *Bar-only text/icon sizing*: `[bar] icon-font` / `icon-slot` / `icon-canvas` /
  `status-slot` are read by `Style.bar` but never populated by
  `applyShellValues` — dead keys. A shell-source patch was tried and fully
  reverted.
- Font *size* is machine-level only: `~/.config/omarchy/shell.toml` `[font]
  base-size` (currently 14, via `omarchy display text size`). The theme must not
  touch it — pinning text while icons still scale with `base-size` makes bar
  icons look oversized. `shell.toml` is merged with the theme's **per key**
  (`mergeShell` in `Color.qml`).

**Theme `mode`** resolves as `mode` key → legacy `theme_type` → `light.mode`
marker → background luminance → dark. It only *signals*: it drives
`gsettings color-scheme` + `gtk-theme` (flipping GTK/libadwaita and web
`prefers-color-scheme`), VS Code's `type`, and Claude's `base`. Terminals, bar,
btop and Hyprland just render the hex from `colors.toml`.

**Generated, never committed:** `btop.theme`, `chromium.theme`, `hyprland.lua`,
`vscode-theme.json`, `neovim.lua` and the terminal colour files are produced from
`colors.toml` on every theme-set. Omarchy strips `.lua` from *git-cloned* themes,
which is why window decoration lives in `overrides/hypr/`, not in a theme folder.
Our themes are symlinked rather than cloned, so nothing is stripped.

**Shell surfaces** read `shell.<section>.toml`, spliced in by
`omarchy-theme-set-templates`, which **replaces the whole section** — any key you
omit falls back to the `Color.qml` default, not the generated value. That is why
each file restates its full section. In those files `background` / `border` /
`scrim` accept role-name tokens (resolved via `composed()` → `flatColor()`), but
`text`, `active`, `selected-text` and `countdown` are read with a plain `pick()`
that never unwraps a role name — those **must be literal hex** or they render
black.

A live `hyprctl reload` does not update a running shell; `omarchy-restart-shell`
or `omarchy theme set` does.

---

## Conventions in this repo

**Fenced blocks.** `apply.sh` injects `>>> cllpse-macos overrides >>>` blocks into
`~/.config/hypr/{hyprland,looknfeel}.lua`, `~/.config/ghostty/config` and
`~/.bashrc`. Comment leader is `--` for `.lua` and `#` elsewhere — a `#` line is a
Lua syntax error. `sync_fenced` **replaces** an existing block, so editing a
snippet reaches an already-applied machine; it refuses to write an empty result,
so a failed rewrite cannot truncate a real config.

`~/.config/hypr/looknfeel.lua` holds three independent regions: a hand-written
inactive-border block, our fenced block, and an Omaland-managed block. Only ours
is safe to rewrite, and edits must preserve the other two.

**`revert.sh` only undoes.** It never picks a font or theme. `apply.sh` records
the pre-existing font and theme once, into `~/.local/state/cllpse-macos/`,
refusing to record values that are already ours; revert restores those, or falls
back to deleting the generated `fonts.conf`.

**BUILD.md is reconciled to what ships.** Where a shipped value differs from the
spec's starting figure, the table row carries the shipped value tagged `[chosen]`
and the original is kept in prose as provenance. Don't leave the two out of sync.

---

## Traps already hit

- **`awk -v close=...` is fatal** — `close` is a gawk builtin. It failed silently
  mid-pipeline and truncated the target file to zero bytes. Test any script that
  rewrites a real config against a harness first.
- **`Style.qml`'s trailing size comments are base-12 annotations, not sizes.**
  `heading: fontToken("heading", fontPx(1.333)) // 16` reads as "16px", but
  `fontPx(mult) = round(fontBaseSize * mult)` and this machine runs
  `base-size = 14` — so heading is 19, body 14, `iconLarge` 21, `display` 28.
  Compute against the live base, never quote the comment. Check it with
  `omarchy display text size`.
- **Size from a token, not a multiple of one.** Every `Style.font.*` value is
  already rounded, so scaling one rounds twice and lands on numbers that drift
  off the scale as base-size moves (`iconLarge * 1.4` → 25/29/34/38 px at base
  12/14/16/18, versus `display` → 24/28/32/36). `Style.space(px)` is the same
  deal for geometry — it scales by `spacingScale * fontScale`, so pass the
  base-12 pixel value and let it scale.
- **`hl.animation` `speed` is inverse**: *smaller is faster*. Every leaf in our
  block is Omarchy's stock speed halved to run 2× faster. Doubling the number
  would have made it 2× slower.
- **Omaland**, if installed, writes its own `hl.animation` block into the same
  `looknfeel.lua` and wins by file position. Accepted — our block exists to be
  self-sufficient on a machine without it.
- **Blur only shows through what a surface leaves translucent.** At
  `background-alpha` 0.92 barely 8% of the backdrop shows, so widening the blur
  radius there is close to invisible; `background-alpha` is the stronger lever.
- The repo carries ~229 MB of Apple fonts and wallpapers it does not own, on a
  public remote. See [`THIRD-PARTY.md`](THIRD-PARTY.md) before adding more.

## Still open

- Light-specific `preview*.png` / `unlock.png` — both themes still ship identical
  art.
- `revert.sh`'s restore paths have unit-tested helpers but have never been run
  end-to-end; that needs a spare machine or VM, not this one.
