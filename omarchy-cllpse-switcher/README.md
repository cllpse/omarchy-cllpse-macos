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

## Input path

**Keybinds arrive over Hyprland's global-shortcuts protocol, not over IPC.**
`Hud.qml` registers three `GlobalShortcut`s under appid `cllpse-switcher`
(`next`, `prev`, `commit`) and `overrides/hypr/window-switcher-bindings.lua`
binds them with `hl.dsp.global(...)`.

This is where the switcher's sluggishness lived. The old path summoned the
plugin with `omarchy-shell shell summon`, which is bash → `timeout` → `qs ipc`
— and `qs ipc` starts an entire Quickshell binary to deliver one message.
Measured on this machine at **31–35ms per call, spiking to 130–166ms**, and paid
on *every* keypress. `hl.dsp.global` hands the event straight to the running
process: no fork, no exec, no Qt startup.

| | summon → strip mapped |
|---|---|
| IPC summon | 39–40ms |
| `hl.dsp.global` | **9–10ms**, of which ~4–5ms is `hyprctl` itself in the test harness — a real keypress does not pay that |

`commit` is a shortcut for the same reason: `hl.dsp.global` is a dispatcher, so
the Lua key-release poll fires it through the same channel instead of shelling
out. The IPC `summon` entry point still works and is unchanged — it is what the
tests drive, and what any other caller would use.

## Input

The surface is a full-screen layer surface with **no mask**, so it takes every
click while it is up: one on a tile focuses that window, one beside the card
dismisses the strip. Eating clicks is only a hazard for a surface that is up
when you are not looking at it, and `visible: root.opened` means this one never
is. (It was masked to the card once — `mask: Region { item: card }`, the idiom
Omarchy uses for notification toasts. Toasts are passive and long-lived; a
switcher is modal for the moment it is on screen.)

**Getting the press here at all took a change on the compositor side.**
Hyprland resolves mouse *binds* before handing a button to a layer surface, so
while `SUPER + mouse:272` was bound the HUD's input region never saw the press —
confirmed on this machine: it started a window drag (`SUPER + mouse:272` is
Omarchy's "Move window", `default/hypr/bindings/tiling.lua:70`) and the tile was
never hit. A mask cannot win that race; the bind is resolved first.

That was first worked around by making the bind itself know about the strip:
while it was up, `SUPER + left-click` dispatched a `click` shortcut into the
plugin instead of dragging, and the plugin decided what it meant (over the card,
commit; outside it, dismiss). It could not go further than that. **A bind reports
a press and nothing else**, and drag-and-drop needs press, motion *and* release.

So `overrides/hypr/window-switcher-bindings.lua` now keeps a handle to that bind
and **switches it off for exactly as long as the strip is on screen** (the same
`ws_watching` flag the key-release poll uses). With nothing matching, the
compositor forwards the button to the surface under the cursor — the HUD — and
the plugin gets ordinary Qt press / move / release events. `hl.bind` returns the
keybind and `set_enabled` toggles it in place, so nothing is unbound and rebound
per gesture. Resize (`mouse:273`) is left alone.

One consequence worth knowing: if you dismiss the strip by clicking beside it
and keep holding SUPER, the drag bind stays off until SUPER comes up, because
the plugin has no way to tell the Lua side it closed. `SUPER + drag` to move a
window is inert for those few hundred milliseconds. It re-arms on release.

The `MouseArea` also supplies **hover**, which used to be a poll. Because the
surface was click-through it received no Qt pointer events at all, so hover was
done by running `hyprctl cursorpos -j` on a 40ms timer — 25 process spawns a
second, ~3–4ms each, for the entire time the strip was on screen. A real input
region gave it `hoverEnabled` for free. Measured shell CPU with the strip open:
**1.0% → 0.0%**. `onPositionChanged` only fires on actual movement, which also
replaced the old `hoverBase` distance threshold that existed to stop a resting
cursor yanking the keyboard's selection.

The `MouseArea` carries `cursorShape`: a pointing hand over the tiles, closing
on one while it is being dragged.

## Drag to arrange

Press a tile, move past the drag threshold, release over a workspace's group:
the window moves there, landing at the **start or the end** of that workspace
depending on which half of the group you let go over. Dropping on its own group
is allowed and is how you send a window to the front or the back of where it
already is. Press and release without travelling, and it is still a click, and
still focuses.

Start and end, and nothing between. A strip of tiles is not a layout tree, and a
workspace that mixes horizontal and vertical splits has no "third position" that
one row of tiles could point at.

Ordinary press / move / release — no `Drag`/`DropArea`, because there is nothing
for a `DropArea` to *be*. The drop targets are workspace groups, and a group is
not an item: it is a run of tiles inside one `ListView`, drawn as a group by the
gap in front of it. So the hit-test is the same arithmetic the rules and the
hover already use.

- **The target is a workspace, not a tile.** `_wsAt` takes the nearest tile
  centre, so the gap between two groups belongs to whichever side is closer and
  every x over the card resolves to exactly one workspace. A drop can miss the
  card, but it cannot fall between two groups and quietly do nothing.
- **The threshold is `Qt.styleHints.startDragDistance`** (8px here), so the
  strip agrees with everything else on the desktop about where a click stops
  being a click.
- **The highlight follows the tile in the hand** for the whole gesture, not the
  pointer. Releasing SUPER has to focus what you were dragging, not whatever it
  passed over.
- **`follow = false`** — the same dispatcher `SUPER + SHIFT + ALT + <n>` uses
  (`default/hypr/bindings/tiling.lua:24`), with `window` naming the dragged tile
  rather than the focused window. The HUD never takes focus, so the active
  window is emphatically not the one in the hand.
- **The list unfreezes for the drop.** It is otherwise frozen while the strip is
  up — see below — but a drop changed the list *itself*, and freezing it out
  would leave the tile sitting in the group it was just dragged out of. The
  exception is a 600ms window rather than a single rebuild, because the move is
  a `hyprctl` process: the debounced refresh can beat it, see nothing changed,
  and the `movewindow` event that follows would then find the freeze back on.
  The highlight is re-homed by address, so it lands on the moved tile wherever
  the re-sort put it.
- **Releasing SUPER mid-drag drops and stops there** rather than also
  committing. The move is a process and so is the focus; if the focus won that
  race Hyprland would send you to the workspace the window is about to leave.
- **The ghost is a reduced copy of the tile, not the tile.** A `ListView`
  delegate cannot leave its viewport, and taking the real item out of the model
  for the length of a gesture is a far larger change than a drag ghost is worth.
  The tile it came from fades to a hole in the strip so the two never read as
  two copies of the same window.
- **The ghost rounds like a menu row.** `radius: Style.cornerRadius` — the same
  token a SUPER+SPACE menu row binds (`Menu.qml:1222` → `Menu.qml:98`), which is
  `decoration:rounding`, 18 here. Bound rather than copied as a number, so the
  chip, the tiles and the card all round alike and a change to the compositor's
  rounding carries every one of them. The proportions line up as well as the
  number does: measured 48px tall against a menu row's 54 (`baseRowHeight`,
  `Menu.qml:102`).
- **The strip auto-scrolls at the edges.** It is wider than the card as soon as
  there are more windows than fit, and the group you most want to drop on is
  then exactly the one off the end.

### Placing it at an end

There is no "insert at index" to dispatch — Hyprland moves a window one
neighbour at a time — so the distance is counted and issued as exactly that many
steps in a single `hyprctl --batch`.

- **`movewindow` takes a `window` argument; `swapwindow` does not.** That is
  what lets a window be shuffled on a workspace nobody is looking at without
  touching focus — verified on this machine, including that the active window on
  another workspace stayed put. `swapwindow` looks like the better primitive,
  being inherently edge-safe ("No window to swap with in that direction" at the
  end of a run), but it ignores `window` and acts on the active one, which here
  is never the window in the hand.
- **Counted, not repeated-until-it-stops.** Two reasons, and the second is the
  one that matters: it is one process rather than a round trip per step, and an
  overshoot is not harmless. `binds:window_direction_monitor_fallback` defaults
  on, so a step past the last window hands it to the next *monitor* rather than
  doing nothing — inert on this single-monitor machine, not in general.
- **The placement is deferred, not sent with the workspace move.**
  `movetoworkspacesilent` puts the window wherever the layout decides, and only
  once that has landed does the strip know how far from the requested end it
  came to rest. So the drop records the intent and the first rebuild that sees
  the window on the workspace it asked for counts the distance and closes it.
  The 600ms unfreeze covers that round trip (measured chain: ~75ms) and is
  restarted by the placement so the strip shows where the steps left it.
- **One row or one column**, decided from the group's own `at` coordinates. A
  workspace split top-and-bottom sorts by y in the strip, so "start" there means
  the top and stepping it left would do nothing at all — the drop would look
  broken. That is the whole of the layout-awareness here, deliberately.
- **The caret marks the end**, drawn over the tiles in the selection accent and
  hugging the group's outer edge rather than sitting mid-gap where the group
  rules are, so a rule and a caret never read as the same thing. It is sized to
  the ROW rather than the card, which is the other half of that distinction: the
  group rules are the card's own divisions and run its full height, while this
  is a mark on the tiles and takes the tiles' box — the same `list` geometry the
  group highlight and every cell use, inset top and bottom by the card's own
  padding so it sits within a tile rather than running its full height, with ends
  rounded to half its own width — a cap on a stroke, so it follows the stroke
  rather than the card's radius token. It is clamped into the viewport, which is
  what covers the first and last groups: their outer edge is the card's own
  padding, with no gap to sit in.
- **No caret when there is nothing to arrange against.** A workspace has to hold
  a window other than the one in the hand before start-or-end is a choice:
  dropping onto an empty desktop, or back onto a group whose only window is the
  one being dragged, has one outcome however it is aimed. The group highlight
  still shows — that is the drop target, and an empty workspace is a perfectly
  good one — but the caret stays down rather than pointing at a choice that does
  not exist.

## Back-and-forth

A single `SUPER+TAB` returns to the window you came from, and a second brings you
back — the alternation every Alt+Tab has. **The tiles are not reordered to do
it.** They stay sorted by workspace then on-screen position; the focus history
only moves where the highlight *starts*.

- The **first forward tap** lands on the previously focused window.
- **Further taps in the same gesture** walk the positional order from there, so
  the highlight moves along the strip the way it looks like it should rather
  than hopping around a history the tiles do not show.
- **SHIFT+TAB** is purely positional. Stepping backwards through a history the
  strip does not display has no visible meaning.

The history is kept in the plugin (`activeAddr` / `prevAddr`, updated from
`Hyprland.activeToplevel`) because nothing compositor-side offers it in a usable
form: `activated` only ever says what is focused *now*, and `lastIpcObject`'s
`focusHistoryID` is a stale snapshot — measured sitting at `2/1/0` across two
focus changes. It shifts only when the focused window actually changes, so
committing to the window you are already on cannot erase the one you wanted to
go back to.

If the remembered window is gone — closed, or moved to a special workspace the
list filters out — `_mruIndex()` returns -1 and the tap falls back to the next
window positionally. Verified by hiding it to the scratchpad mid-test: the tap
landed on a live window rather than doing nothing.

Measured, four tiles, focus set to tile 2 having come from tile 0:

| gesture | lands on |
|---|---|
| tap, tap, tap, tap | 0, 2, 0, 2 — alternating |
| two taps in one gesture | 1 (MRU 0, then +1 positional) |
| SHIFT+TAB | 1 (positional back) |

## Window list

The list is **kept in memory and maintained from Hyprland's event socket**
(`Quickshell.Hyprland`), not rebuilt by shelling out to `hyprctl clients -j` on
every summon. Opening is therefore synchronous: the cached list is already
there, so `open()` steps the index and shows the strip with no process to spawn
and nothing to wait for.

It replaced a real bug. The old path rebuilt the list on every open and assigned
`root.wins` unconditionally — and a repeat open produced a list that was
byte-identical yet still reset the `ListView`, destroying and recreating cells.
A recreated cell's icon `Image` starts at `Loading`, so the delegate falls back
to its Nerd Font glyph for a frame or two before the icon appears: a visible
flicker on the icons, every single open. Measured with a delegate lifecycle
probe, before → after: `destroy 2 / create 2` on each open → **0 / 0**.

Two fixes were needed, because there were two independent causes:

- `_rebuild()` diffs (`_sameWins`) and only assigns `root.wins` when the address,
  title, class or workspace of some row actually changed.
- The `ListView` needs `cacheBuffer` covering the whole strip. Even with the
  model left alone, the rightmost cell sat a fraction of a pixel outside the
  viewport and was culled and rebuilt on every open.

The list is also **frozen while the strip is on screen** — a macOS Cmd-Tab list
does not reshuffle under the hand holding it, and re-assigning the model
mid-open is the same flicker by another route. `close()`/`dismiss()` rebuild on
the way out.

### What Quickshell actually gives you here

Measured against this build; each of these cost a debugging pass:

- `Hyprland.rawEvent` is **live** — `openwindow`, `closewindow`, `movewindow`,
  `windowtitle` … arrive as they happen. A debounced `refreshToplevels()` hangs
  off it (a single move emits a burst).
- `toplevel.activated` is **live** and tracks focus with no refresh at all. The
  focused window must come from it.
- `toplevel.lastIpcObject` is a **snapshot, not live** — it holds the full
  `hyprctl clients` object (`at`, `class`, `workspace`, `hidden`), but its
  `focusHistoryID` sat at `2/1/0` across two focus changes. Ordering fields need
  an explicit `refreshToplevels()`; `focusHistoryID` must never be trusted for
  "what is focused now".
- `refreshToplevels()` rewrites each `lastIpcObject` **in place**, so the values
  array is unchanged and **`valuesChanged` does not fire**. The rebuild after a
  refresh has to be scheduled by hand.
- `Hyprland.toplevels` is populated lazily: empty in a bare Quickshell instance
  until something refreshes, but already populated by the time this plugin loads
  inside the Omarchy shell. So the prime does both a refresh and a rebuild —
  waiting on `valuesChanged` alone leaves the list empty forever in the
  already-populated case.
- Addresses carry an `0x` prefix in `lastIpcObject` but **not** on the toplevel
  handle. Compared raw, nothing ever matches and every open starts from index 0.
- `activated` is only set once Quickshell has seen an `activewindow` event, so on
  the very first summon after a shell restart nothing reports it. There is a
  `focusHistoryID` fallback for exactly that one cold case — accurate there,
  because the snapshot was just refreshed.

## Look

The card binds `Color.menu.background` / `Color.menu.scrim` / `Color.menu.border`
and `Style.cornerRadius`, so it tracks the active theme's menu chrome with no
plugin-side theming. Under **omarchy-cllpse-theme** that means:

- corner radius follows `decoration:rounding` (16) like every shell surface;
- the card is opaque — `[menu] background-alpha` is 1.0 in
  `omarchy-cllpse-theme/*/shell.menu.toml`, so the card is solid and the layer
  blur rule is inert for it;
- the scrim **binds `Color.menu.scrim`**, so it is the same dim the SUPER+SPACE
  menu draws. It used to compose its own colour at 0.35 — the value the inert
  `[launcher]` section intends — on the theory that a switcher wants a little
  more separation from the desktop than a menu. Measured side by side (solving
  `composited = a*background + (1-a)*backdrop`) that was 0.37 against the menu's
  0.22 and the mismatch was visible, so the two were aligned. Binding the role
  rather than composing a literal is also what makes light and dark both correct
  with no second value in the plugin: `Color.menu.scrim` resolves `scrim` /
  `scrim-alpha` from each theme's own `shell.menu.toml` against that theme's
  palette — `background` over `#1E1E1E` in dark, over `#FFFFFF` in light.
  Retune it in `shell.menu.toml`, not in `Hud.qml`. At 0.25 it stays below the
  layer rule's `ignore_alpha` (0.6), so it renders unblurred and the windows
  being switched between remain readable;
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
this machine, 5 of the 24 entries declaring `StartupWMClass` use a class that is
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
- `nameFor`'s curated list is **not** the last word: anything it does not match
  falls through to the desktop entry's `Name=` (via `classIndex`) before the
  title-cased-class fallback, so the switcher and the launcher print the same
  string without a second list kept in step by hand. The list is now only for
  names we deliberately disagree with the entry about — measured on this
  machine, keeping it ahead of the lookup is what preserves `mpv` over
  `mpv.desktop`'s "Media Player" and `Qt V4L2` over "Qt V4L2 test Utility".
  Figma Desktop is the case that exposed the split: the launcher read
  `Name=Figma Desktop` off the entry while a hardcoded `has("figma")` here
  answered "Figma".
- That lookup is only as good as the entry's `StartupWMClass`. Figma's upstream
  entry declares `Figma` against a live class of `figma-desktop`, which joins to
  nothing — the local entry is corrected to the class Hyprland actually reports.
  A name that still resolves to a title-cased class is the signal to check that
  declaration first.
- If a hand-placed icon exists for the window's class in
  `~/.icons/cllpse-flat/apps/` (synced from `overrides/icons/fallbacks/`), an
  `Image` replaces the text cell for that tile. `.svg` is probed first, then
  `.png`. Everything else stays text — a glyph is crisper at this size than any
  bitmap, and it recolours for free.
- The drop-in is named for the desktop entry's `Icon=` while the switcher only
  has a window class. They agree for most apps but not all (5 of the 24 entries
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
- `sourceSize` is **set**, and for a reason that differs by format. On a raster
  it picks the decode resolution, and leaving it unset merely uses the file's
  own — which is why it was deliberately unset while drop-ins were PNGs
  (`Screen.devicePixelRatio` reports the *screen's* ratio, 2 on this display,
  not this window's 1.25, so deriving from it decoded at 56px for a 35px draw
  and Qt bilinear-downscaled — softer than letting Qt pick from the drawn size).
  On a **vector** it instead picks the *rasterisation* resolution, and unset
  makes Qt rasterise at the SVG's intrinsic size — 24x24 for simple-icons,
  16x16 for symbolic — then scale that up. Once drop-ins became SVGs that was
  the source of the blur, and over-decoding stopped being a cost; Omarchy's
  `Menu.qml` sets it, which is why the menu was never affected.
- `layer.textureSize` is *not* a factor — forcing it changes nothing, tested.
  Some softness against hinted, natively rendered glyphs is irreducible for a
  raster drop-in, but not for an SVG one.

## Notes

- **The switcher mirrors the SUPER+SPACE menu's behaviour: it appears instantly,
  with no delay and no fade.** Two separate things have to be right for that,
  and they fail independently.
  - *No timer in the QML.* The panel maps as soon as its content is ready,
    exactly as `Menu.qml:1019` does (`visible: root.opened && root.rowsLoaded`;
    here `opened` is set when the client list parses). A 150ms show delay was
    tried — borrowed from GNOME's `POPUP_DELAY_TIMEOUT`, to stop a quick tap
    flashing the strip — and removed. Don't re-add one.
  - *A scrim-only fade, 120ms.* The scrim `Rectangle` in `Hud.qml` animates its
    own `opacity` (`Behavior` + `NumberAnimation`, 120ms, `Easing.OutCubic`)
    while the card maps at full opacity. The compositor cannot express this: a
    card and its scrim are one layer surface, so a layer-rule fade takes both
    and the card stops landing under the keypress. Measured — card interior
    `269 → 118` in a single step, scrim `259 → 230 → 228 → 227 → 225`
    decelerating over ~120ms. The layer rule keeps `no_anim` on this namespace
    so the compositor fade does not stack on top.
  - *The Omarchy panels cannot do the same.* Their scrim lives in Omarchy's own
    `Menu.qml`; editing that is a patch to `/usr/share/omarchy` that the next
    update overwrites. They keep the whole-surface compositor fade, measured at
    ~100ms, re-enabled by a layer rule (see below).
  - *Historic:* Hyprland fades a layer surface
    as it maps (`layersIn`, `style=fade`, ~130ms at our speeds). Omarchy opts
    its own panels out of that in `default/hypr/apps/omarchy-shell.lua` — line 5
    for the bar, line 10 for
    `^(omarchy-menu|omarchy-image-selector|omarchy-emojis|omarchy-clipboard|omarchy-keyboard-panel)$`
    — a literal alternation a third-party namespace cannot join, so the HUD
    faded while the menu snapped, and that mismatch was the original complaint.
    It was first fixed by opting the switcher out too. It is now fixed the other
    way: `overrides/hypr/looknfeel-decoration.lua` re-enables the fade for the
    whole panel family *and* the switcher, so they match and are consistent with
    notifications / OSD / polkit, which were never opted out and always faded.
    A later layer rule wins over an earlier one, so this needs no edit to
    Omarchy's file. Measured by burst-`grim`ing the scrim as it opens: menu
    276 → 271 → 254 → 239 → 238, switcher 276 → 273 → 265 → 255 → 246 → 239,
    both ~100ms ramps where they were previously a single hard step.
    The compositor cannot fade the scrim alone — a card and its scrim are one
    surface — and duration is `layersIn`'s speed, shared with every animated
    layer. For scrim-only or a different duration, animate the scrim
    `Rectangle`'s `opacity` in `Hud.qml` instead.
- The plugins dir is watched with `inotifywait -r`; live edits inside a
  *symlinked* plugin may not auto-reload. Run `omarchy-restart-shell` after
  changing files here.
- The dir name is cosmetic — Omarchy keys plugins by `manifest.json` `id`, not
  the folder. The symlink is named for the id so enablement and keybinds don't
  care that the source moved.
