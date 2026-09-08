# omarchy-cllpse-switcher

A macOS-style window switcher HUD for the Omarchy 4 (Quickshell) shell — hold
`SUPER`, tap `TAB` / `SHIFT+TAB` to cycle a horizontal strip of open windows,
release `SUPER` to focus the highlighted one.

Plugin id **`cllpse.window-switcher`** (kept for the `shell.json` `plugins[]`
entry and the `omarchy-shell shell summon` keybinds in `~/.config/hypr/bindings.lua`).
`overrides/apply.sh` symlinks this folder to
`~/.config/omarchy/plugins/cllpse.window-switcher`; `revert.sh` removes the
symlink.

## Files

| File | Role |
|---|---|
| `manifest.json` | schemaVersion 1, `kinds: ["panel"]`, `keepLoaded: true`, entry point `Hud.qml`. |
| `Hud.qml` | The whole plugin. Click-through `Overlay` layer surface, namespace `omarchy-window-switcher-hud`. Keyboard-driven only — Hyprland keybinds `summon` it with a `{"action":"next|prev|commit"}` payload. |

## Look

The card binds `Color.menu.background` / `Color.menu.scrim` / `Color.menu.border`
and `Style.cornerRadius`, so it tracks the active theme's menu chrome with no
plugin-side theming. Under **omarchy-cllpse-theme** that means:

- corner radius follows `decoration:rounding` (16) like every shell surface;
- translucency comes from `[menu] background-alpha` (0.92) in
  `omarchy-cllpse-theme/*/shell.menu.toml`;
- the scrim is composed in `Hud.qml` at 0.35 rather than bound to
  `Color.menu.scrim` (0.25) — a switcher wants a little more separation from the
  desktop than a menu. It is built from the live palette background so it still
  follows theme switches. 0.35 is the value `[launcher]` intends, which Omarchy
  4.0.2 never reads: there is no launcher surface in `Color.qml` and no launcher
  plugin, so that section is inert and the value is applied here directly. The
  scrim sits below the layer rule's `ignore_alpha` (0.6), so it stays unblurred
  and the windows being switched between remain readable;
- the card and cells track the SUPER+SPACE menu (`shell/plugins/menu/Menu.qml`)
  token for token: `Style.spacing.panelPadding`, `Style.spacing.xs` between
  items, `Style.cornerRadius`, the same `Border.surfaceSpec("menu", …)` card
  border and `selected-border` spec on the cursor cell, labels in
  `Style.font.heading`/Medium and the secondary line in `Style.font.bodySmall`
  at 0.52. Cell height derives from those tokens with a floor, the way the
  menu's `baseRowHeight` does, so it survives `omarchy display text size`.
  **The one deliberate departure is the icon** at `Style.font.display` (2.0 rem):
  in the menu the icon sits inline beside a label, here it is the primary
  element of a card, like a macOS Cmd-Tab tile;
- blur comes from the `hl.layer_rule` in
  `overrides/hypr/looknfeel-decoration.lua`, whose namespace match includes
  `window-switcher-hud` so the HUD blurs exactly like the Omarchy menu.

### Icons

The tile's mark is a Nerd Font **glyph rendered as text**, coloured from
`Color.menu.text`, so it is flat and tracks the theme with no file on disk and
nothing to regenerate. That is the same track the Omarchy menu uses for its
non-app rows; the menu's *app* rows are the exception — they draw a plain
`Image` of the vendor icon with no recolouring, which is what
`overrides/icons/fallbacks/` and the `app-icons.sh` theme-set hook exist to
replace.

The switcher keys on the **window class** while a drop-in is named for the
desktop entry's `Icon=`. Those agree for most apps but not all — measured on
this machine, 6 of the 23 entries declaring `StartupWMClass` use a class that is
not their icon name, and Chromium's is the literal unsubstituted
`@@startup_wm_class`. A drop-in whose filename differs from the class reaches
the menu but not the switcher; drop a second copy named for the class to cover
both.

### Spacing

The icon/title gap is one named knob on `card`:

```qml
readonly property int iconTitleGap: Style.spacing.lg      // xs 3 / sm 4 / md 6 / lg 8 / xl 10
readonly property int iconTitleTopUp: Math.max(0, card.iconTitleGap - Style.space(3))
```

It exists because the delegate's `Column` has a **single uniform `spacing`**
that sets the title/subtitle gap as well, and those two lines want to stay a
pair — so the Column keeps its `xs` and the title tops the rest up with
`topPadding`. Both that padding and `card.rowH` derive from `iconTitleGap`, so
there is one place to retune and the fixed cell height cannot drift out of sync
with the padding. Raising the padding without raising `rowH` clips the stack.

### Rendering

Worth knowing about `glyphFor`, which is still the default for every tile:

- `glyphFor` must use `String.fromCodePoint`, never `fromCharCode` — the latter
  is 16-bit and silently truncates the Material Design range this map now uses
  (`0xf0219` → U+219, `0xf082e` → U+82E), rendering unrelated glyphs with no
  error.
- Codepoints are verified against `Style.font.menuFamily` — `SFProText Nerd Font
  Propo` here, via `OMARCHY_MENU_FONT` — not against the monospace face. A glyph
  present in SF Mono is not necessarily present in SF Pro Text.
- Ordering in `glyphFor`/`nameFor` is load-bearing: `obsidian` is tested before
  `obs`, and the specific `libreoffice-*` classes before the bare `libreoffice`.
- If a hand-placed icon exists for the window's class in
  `~/.icons/cllpse-flat/apps/` (synced from `overrides/icons/fallbacks/`), an
  `Image` replaces the text cell for that tile. `.svg` is probed first, then
  `.png`. Everything else stays text — a glyph is crisper at this size than any
  bitmap, and it recolours for free.
- The drop-in is named for the desktop entry's `Icon=` while the switcher only
  has a window class. They agree for most apps but not all (6 of the 23 entries
  declaring `StartupWMClass` differ), so a drop-in whose name differs from the
  class keeps its glyph here — drop a second copy named for the class to cover
  both.
- That image is recoloured through `MultiEffect`, not blitted. The PNG is baked
  at the theme `foreground`, but a selected tile draws in `selected-text`
  (`#007AFF` in both our themes) — so a plain `Image` would leave the *focused*
  tile showing a grey icon under a blue label. Same technique Omarchy uses to
  tint symbolic tray icons (`Tray.qml:789`), measured at ~0.002 ms per icon.
- The fallback is `status !== Image.Ready`, so on a machine where `apply.sh`
  step 7f never ran — no `~/.icons/cllpse-flat/` at all — every tile simply
  stays a glyph and nothing breaks.
- The image box is `iconSize * 256/200`, not `iconSize`. `app-icons.sh` centres
  each mark in 200 of 256 px, but a text glyph at `pixelSize` N fills close to
  N — so drawing the PNG into a plain `iconSize` box renders it visibly smaller
  than the glyph beside it, and downscales the 256px master harder. Measured on
  screen before the fix: 27px of ink against the Chromium glyph's 33; after,
  35 against 33. Match the **ink**, not the canvas.
- `sourceSize` is deliberately left unset. `Screen.devicePixelRatio` reports the
  *screen's* ratio (2 on this display), not this window's (1.25), so deriving
  `sourceSize` from it decodes at 56px for a 35px draw and Qt then bilinear
  downscales — measurably softer than letting Qt pick from the drawn size.
- `sourceSize` is **required**, and for a reason that differs by format. On a
  raster it picks the decode resolution and leaving it unset merely uses the
  file's own. On a vector it picks the *rasterisation* resolution, and unset
  makes Qt rasterise at the SVG's intrinsic size — 24x24 for simple-icons,
  16x16 for symbolic — then scale that up. That was the source of the blur once
  drop-ins became SVGs; Omarchy's `Menu.qml` sets it, which is why the menu was
  unaffected.
- `layer.textureSize` is *not* a factor — forcing it changes nothing, tested.
  Some softness against hinted, natively rendered glyphs is irreducible for a
  raster drop-in, but not for an SVG one.

## Notes

- The plugins dir is watched with `inotifywait -r`; live edits inside a
  *symlinked* plugin may not auto-reload. Run `omarchy-restart-shell` after
  changing files here.
- The dir name is cosmetic — Omarchy keys plugins by `manifest.json` `id`, not
  the folder. The symlink is named for the id so enablement and keybinds don't
  care that the source moved.
