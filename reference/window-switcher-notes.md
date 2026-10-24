# omarchy-cllpse-plugin-switcher

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

The surface is a full-screen layer surface whose input region is **everything
but the four corner pixels**, so it takes every click while it is up: one on
a tile focuses that window, one beside the card dismisses the strip. Eating
clicks is only a hazard for a surface that is up when you are not looking at it,
and `visible: root.opened` means this one never is. (It was masked to the card
once — `mask: Region { item: card }`, the idiom Omarchy uses for notification
toasts. Toasts are passive and long-lived; a switcher is modal for the moment it
is on screen. It was then unmasked entirely, which is what the cut-outs below
walked back by four pixels.)

**Those four cut-outs are what the corner trigger rests on**, and they are not
cosmetic — see *The screen corners* below.

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
**1.0% → 0.0%**. This paragraph went on to say `onPositionChanged` only fires on
actual movement, and the old `hoverBase` distance threshold, which stopped a
resting cursor yanking the keyboard's selection, was dropped on the strength of
it. That was wrong, and the threshold is back: see *A resting pointer is not
hover* below.

### A resting pointer is not hover (2.7.1)

A quick `SUPER+TAB` with the pointer resting where the strip appears committed
the tile under the pointer, not the window you came from. On Qt 6.11.2,
`QQuickMouseArea::hoverEnterEvent` emits `positionChanged` as well as `entered`
(`qquickmousearea.cpp`, tag `v6.11.2`), so the strip mapping under a still
pointer reports a position at once. Only `hoverMoveEvent` checks that the
position changed. A tile row shifting under a still pointer reports one too:
the frame-synchronous hover Qt Quick sends while items are dirty arrives at a
new item-local position.

`_hoverAt` gates the hover branch, using two rules taken from shipped code:

- **Distance, from Qt's `QMenu`.** `QMenuPrivate::hasMouseMoved` takes the mouse
  as moved once it is more than `QApplication::startDragDistance()` from where
  the menu popped up, manhattan (or after six motion events, which an 8000Hz
  mouse produces in under a millisecond, so that half is left out). Here it is
  `hoverDistance`, twice `Qt.styleHints.startDragDistance`: 16px, measured in
  scene coordinates so the row moving is not motion. It was the 8px drag
  threshold itself until 2.8.1, doubled on request. The strip's drags keep 8.
- **Time, from GNOME Shell's switcher.** `switcherPopup.js` calls
  `_disableHover()` at construction ("so we ignore the enter-event if the
  switcher appears underneath the current pointer location") and on every key
  press and scroll. Hover is off for `DISABLE_HOVER_TIMEOUT`, 500ms. Here
  `hoverHold` is 250ms, half that (500 at first, halved on request: still
  longer than a quick tap, and the highlight lags a deliberate pointer less).
  It restarts on every `next`/`prev`, the opening one included.

Motion inside the hold moves the anchor instead of counting toward the 16px. A
mouse knocked 30px during the tap therefore cannot arm hover later: the 16px
have to be travelled after the hold. Once armed, hover stays armed until the next
key press. A corner summon (`show`) starts armed, since there the pointer is the
gesture. Clicks are not gated.

What others do, for reference. GNOME also delays showing its popup by
`POPUP_DELAY_TIMEOUT` (150ms) "so that fast Alt+Tab users aren't disturbed by
the popup briefly flashing", and selects only on motion events, never on enter.
KWin's TabBox delays its show the same way (`[TabBox] DelayTime` in `kwinrc`).
Neither delay is used here: the strip appears at once on purpose.

**Verified** with `qmltestrunner` on `QT_QPA_PLATFORM=offscreen`, so no display,
pointer or keyboard is touched. The gate's text is cut out of `Hud.qml` and
dropped into a test item with four 100px tiles under a real `MouseArea`. Six
cases passed: strip appearing under a still pointer, a 15px bump inside the
hold followed by a 1px nudge, jitter up to manhattan 8, a `TAB` after hover had
taken over, a corner summon, and the row shifting 20px under a still pointer.
With the gate replaced by `return true` (the old behaviour), five of the six
fail. Only the corner summon passes, as it should.

The `MouseArea` carries `cursorShape`: a pointing hand over the tiles, closing
on one while it is being dragged.

### One overlay at a time

The strip and the supermenu cannot both be up. Each announces its opening on
Hyprland's event socket and closes on anyone else's announcement, so the last
one opened wins:

```
custom>>overlay-open>><plugin id>      # sent by hl.dsp.event("overlay-open>><id>")
```

Neither plugin names the other. Each sends its own `pluginId` from
`onOpenedChanged` and ignores its own echo. The strip cancels through
`dismiss()`, which focuses nothing, so releasing SUPER after SUPER+SPACE took
the strip away reaches `commit()` with `opened` false and switches nothing.

The shell offered nothing to build this on. `PluginShellApi` lets a plugin
summon and hide only itself and emits no signal when another panel opens, and
`openPanelIds` is a set, not a slot. Watching keyboard focus fails too: the
strip is `WlrKeyboardFocus.None`, so opening it takes nothing from the
supermenu. Hyprland's custom events need no shared code. `hl.dsp.event` is a
0.56 dispatcher, `Hyprland.dispatch()` reaches it, and `Hyprland.rawEvent`
delivers the line back as name `custom`, data `overlay-open>><id>`. All three
were probed from a bare Quickshell instance before use.

Probe on the live strip: open it with
`omarchy-shell shell call cllpse.window-switcher open '{"action":"show"}'`, then
`hyprctl dispatch 'hl.dsp.event("overlay-open>>x")'` — `hyprctl layers` loses
`omarchy-window-switcher-hud` at once, and socket2 shows `custom>>overlay-open>>x`
followed by `closelayer>>omarchy-window-switcher-hud`.

## The screen corners

Four more layer surfaces, one logical pixel square, one in each corner of the
output, each with `exclusionMode: ExclusionMode.Ignore` and their own namespace
(`omarchy-window-switcher-corner`). Crossing into one calls
`open('{"action":"show"}')`. Nothing polls: the compositor sends one
`wl_pointer.enter` when the cursor crosses in. They are one `Variants` delegate
rather than four blocks — the only thing that differs between corners is which
pair of edges it anchors to — and `hyprctl layers` is how you check all four
mapped: `0 0 1 1`, `2879 0 1 1`, `0 1619 1 1`, `2879 1619 1 1` on this
2880×1620 output (`3071`/`1279` on the earlier 3072×1280 one).

**Each set of four is bound to its output** — an outer `Variants` over
`Quickshell.screens`, `screen: modelData` on every corner, the idiom Omarchy's
own `Bar.qml` uses. The first version named no screen, and that held only while
the output did. Changing the scale on the 43" TV (behind a USB-C→HDMI adapter)
dropped the link for ~3s: the shell logged `There are no outputs - creating
placeholder screen`, recreated the unbound corners with `Layershell screen does
not correspond to a real screen. Letting the compositor pick.` — which put them
on Hyprland's temporary `FALLBACK` output — and when `FALLBACK` was removed they
went with it. Nothing mapped them again; `hyprctl layers` showed no
`omarchy-window-switcher-corner` at all until a shell restart. Bound, `Variants`
drops the delegate with the output and builds a fresh one when it returns. The
HUD needs none of this: it is mapped per open, so it lands on whatever output
exists at the time.

**It was the whole left edge first (2.1.0), and the corners are that trigger
with the accidents taken out.** An edge is crossed by every gesture that
overshoots something near it — a window's left side, a scrollbar, a tab strip —
so it kept opening the switcher over work that was aimed somewhere else. A
corner is a place the pointer only reaches on purpose, and by the clamp below it
is no harder to hit. Both halves of that are the reason not to walk it back.

**A polling rate is not an event rate, and that is the whole answer to "won't an
8kHz mouse cost something".** A rate is reports *while the mouse moves*. Measured
on the 8000Hz mouse on this machine, while the trigger was still a full-height
edge — so these are an upper bound on four single pixels:

| | |
|---|---|
| cursor parked on the trigger, 32s | **~0 motion events** |
| cursor sliding along it | ~500 events/s |
| client CPU, ~2500 events | **under 10ms** — under 4µs each |

So the idle case — a pointer resting in a corner — is free, and the moving case
is a few percent of one core for the fraction of a second the pointer is
physically on it.

**One pixel is enough because the cursor is clamped, and in a corner it is
clamped on both axes at once.** Hyprland pins the cursor to the output, so a
fast throw cannot overshoot: on a 3072×1280 logical output a warp to
`99999, 99999` lands at `3071, 1279` — inside the bottom-right pixel — and one
to `-9999, -9999` lands at `0, 0`, however fast the pointer was travelling.
Re-measured at scale 4/3 on 3840×2160 (2880×1620 logical): all four corners
land on the last pixel, `2879, 1619` / `2879, 0` / `0, 1619` / `0, 0`, three
rounds out of three, so a fractional scale does not break the clamp. The
same pixel anywhere else on screen would be missed by exactly the fast gesture
people use.

Take that measurement rather than reasoning about it, and take it twice: a first
pass here read `3070, 1277` and `3066, 0`, which is not the clamp but the
physical mouse drifting a few pixels under the user's hand between the warp and
the `hyprctl cursorpos` that followed. Warp and read back-to-back, repeatedly,
and the numbers land on the last pixel every time.

**The HUD must leave those four pixels out of its own input region, or
dismissing becomes a reopen loop.** Wayland delivers pointer events to exactly
one surface. If the HUD covered a corner it would take pointer focus off that
corner's surface the moment it mapped — and hand it *back* on dismiss, as a
fresh `entered`, with the cursor never having moved. Every version of that needs
either a latch that can tell a real crossing from a remap, or a settle timer.
Leaving the pixels alone means the corner keeps focus throughout, no second
`entered` is ever generated, and dismissing with the cursor still parked in the
corner simply stays dismissed (verified after the change: committed with the
cursor in the bottom-right pixel, closed, and still closed a second later).
Each corner carries the click-away for its own pixel so nothing is lost.

**Subtracted, not inset.** The mask is `Region { item: hudInput }` with four
children at `intersection: Intersection.Subtract`, so the HUD gives up exactly
the hot area. Insetting the whole input region by one pixel (`anchors.*Margin`
on `hudInput`, which is what the left-edge version did with `leftMargin`) is
shorter and would clear the corners too, but it would also make every other
pixel of that frame a place where clicking beside the card did not dismiss it.

For the same reason the corners are **mapped for the whole session**, not bound
to `opened`. A surface that unmaps and remaps gets a fresh `entered` the moment
it comes back under a stationary cursor.

**`exclusionMode: ExclusionMode.Ignore` is load-bearing**, not tidiness: an
exclusive zone here would reserve the pixel and shove every window on the output
across. Verified while this was an edge — with the strip mapped, windows stayed
at `x = 26`.

It opens with a step of **zero**, so `_openStepped(0)` lands on `_activeIndex()`
and the window you are already in is highlighted. A TAB's step *is* the gesture;
a pointer's is the click that follows, and pre-stepping to the MRU entry only to
overwrite it the moment the cursor reaches the tiles is a highlight that means
nothing. Routing it through `open()` rather than calling `_openStepped()`
directly is what gets it the cold path for free.

**The guard is `Hyprland.focusedWorkspace.hasFullscreen`, read as a function.**
A fullscreen window is the one case where something real is drawn under a corner
— Omarchy's `gaps_out` (24) plus `border_size` (3; 2 until 2026-10-16) put every window at `27, 27`,
so ordinary windows never reach one — and the one case where a switcher
appearing because the pointer was thrown into a corner is actively unwanted.
Both that property and `ToplevelManager.activeToplevel.fullscreen` are live, but
they are not equally prompt: across a fullscreen toggle `hasFullscreen` was
already `true` by the time the matching `fullscreen>>1` raw event ran, while the
toplevel property still read `false` and caught up afterwards. Reading it as a
function rather than binding it means it does not matter whether the property
carries a change notification.

The keyboard path is untouched by all of this: opened from a corner there is no
key held, so the Lua `ws_watching` poll never starts and Omarchy's
`SUPER + mouse:272` bind is never stood down. It does not need to be — there is
no SUPER in the gesture, so a plain click reaches the surface anyway.

## Drag to arrange

Press a tile, move past the drag threshold, release over a workspace's group:
the window moves there, landing **at the boundary you let go over** — before its
first window, after its last, or between any two. Dropping on its own group is
allowed and is how a workspace of three gets its last window moved to the
middle. Press and release without travelling, and it is still a click, and still
focuses.

One row or one column. A workspace that mixes horizontal and vertical splits has
no ordering that a single strip of tiles could point at, and none is invented —
see the walk below, which stops as soon as the layout declines to move.
A drop on a window has a second offer that needs no ordering: it splits that
window — see *Splitting a window* below.

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
- **The wheel scrolls it kinetically, as the supermenu's list scrolls.** The
  supermenu's `ListView` is interactive, so Qt's `QQuickFlickable::wheelEvent`
  takes the wheel: velocity from the delta over the time since the last event,
  averaged over three samples, then a decelerating flick. The switcher cannot use
  that path. It flicks horizontally only on `angleDelta.x`, so a vertical wheel
  over a horizontal list does nothing (Qt 6.11.2 source). So `tiles.onWheel`
  reproduces the arithmetic and hands it to the public `flick()`, which does not
  check `interactive`. The list carries `flickDeceleration: 15000` because
  `flick()` uses the touch deceleration (1500) where the wheel path uses
  `wheelDeceleration` (15000). One isolated detent glides `wheelScrollLines × 24`
  = 72px. Checked offscreen with the handler's own arithmetic: 72px in ~50ms,
  decelerating 22 → 39 → 53 → 63 → 70 → 72; back to 0 on the reverse notch; no
  overshoot at an end. A press stops a glide, and each open starts still.
  Before, each wheel event moved the strip by the raw delta in one jump.

### Placing it in the slot

There is no "insert at index" to dispatch — Hyprland moves a window one
neighbour at a time — and **the distance cannot be sent at once.**

Measured on a three-window workspace: two `r` steps in a single
`hyprctl --batch` advanced the window *one* position, not two. A dwindle
workspace is a tree and every step reshapes it — the widths change, not just the
order — so the second dispatch in a batch resolves against a layout the first
has already invalidated. Sent one at a time, each step moves exactly one place,
every time:

| step | result |
|---|---|
| start | `A@26  B@1550  C@2306` |
| `r` on `B` | `A@26  C@1550  B@2306` |
| `l` on `B` | `A@26  B@1550  C@2306` |
| `l` on `B` | `A@26(w740)  B@794  C@1550(w1496)` — reshaped |

- **One step per rebuild.** Each step is resolved against the list the refresh
  just read back from the compositor, so it cannot be resolved against a layout
  an earlier step has already invalidated. The cost is a round trip per step,
  ~75ms, which no drag notices.
- **The walk steps off the computed list, not off the model, and the model is
  held back until the walk is over.** Assigning the model resets the `ListView`
  and takes every delegate with it — measured on a nine-tile strip, one reorder
  is create 9 / destroy 9 — and a walk paid that *per step*. Measured on a real
  two-step walk: **36 / 36 before, 9 / 9 after**, i.e. one assignment instead of
  four. The walk never needed the model, only a current list, which is exactly
  what `_rebuild` has just computed and not yet assigned. So the strip updates
  once, at the end, showing where the window came to rest rather than blinking
  the whole strip at every step.
- **Silence ends the walk, not an unchanged reading** (with a hard cap of 8
  besides). A step Hyprland declines emits no `movewindow`, so no refresh and no
  rebuild follow it — a refusal arrives as an *absence*, and `placeSettle` is
  that absence made concrete. Conflating the two cost a real bug: a stale
  snapshot reads identically to a refusal, so a two-step walk gave up after
  gaining one place. Confirmed by hand — the step the walk had written off moved
  the window perfectly well when it was re-sent with a second to settle. The
  unchanged reading is still tested for, but it means "wait", not "stop":
  stepping again on a stale read would send a second step for one place of need
  and overshoot.
- **`movewindow` takes a `window` argument; `swapwindow` does not.** That is
  what lets a window be shuffled on a workspace nobody is looking at without
  touching focus — verified on this machine, including that the active window on
  another workspace stayed put. `swapwindow` looks like the better primitive,
  being inherently edge-safe ("No window to swap with in that direction" at the
  end of a run), but it ignores `window` and acts on the active one, which here
  is never the window in the hand.
- **A slot is not an index.** They differ by one whenever the window is already
  in the group and is moving to the *right* of where it sits: taking it out
  shifts everything after it down a place, so the boundary it was aimed at moved
  too. Dropping into a group it is not yet part of has no such shift.
- **The placement is deferred, not sent with the workspace move.**
  `movetoworkspacesilent` puts the window wherever the layout decides, and only
  once that has landed does the strip know how far from the requested end it
  came to rest. So the drop records the intent and the first rebuild that sees
  the window on the workspace it asked for starts the walk. The strip then shows
  the result in one update when the walk finishes, not step by step — see below.
- **One row or one column**, decided from the group's own `at` coordinates and
  re-read every step, because a step reshapes the tree. A workspace split
  top-and-bottom sorts by y in the strip, so "earlier" there means the top and
  stepping it left would do nothing at all. That is the whole of the
  layout-awareness here, deliberately.
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
- **The caret marks a boundary, not an end.** Within a group the tiles are one
  `gap` apart and nothing else, so half a gap back from a tile's left edge *is*
  the boundary in front of it — the same arithmetic at both ends and in between,
  with no special case.
- **No caret when there is nothing to arrange against.** A workspace has to hold
  a window other than the one in the hand before start-or-end is a choice:
  dropping onto an empty desktop, or back onto a group whose only window is the
  one being dragged, has one outcome however it is aimed. The group highlight
  still shows — that is the drop target, and an empty workspace is a perfectly
  good one — but the caret stays down rather than pointing at a choice that does
  not exist.

### Splitting a window (2.7.0)

Over a tiled window's tile, on any workspace, a drop is aimed at that window
rather than a boundary. The tile is cut into thirds of the row: the top third
puts the dragged window above it, the bottom third below, the middle beside it,
on whichever half the pointer is over. The bar on the tile's top or bottom edge
(the caret turned on its side) and the caret at its side read one value,
`dropSplit`, which is a dwindle direction (`u`/`d`/`l`/`r`). So what is drawn and
what is dispatched cannot disagree.

**The hint is the bar or the caret and nothing else.** The first cut also tinted
the band the pointer was in and drew rules between the three bands. Both went
on 2026-10-22, at the user's call. The bar is drawn at `card.ruleStroke`, the
weight of the group rule — the strip's main separator — which is also the
caret's weight. The tint under it had made it read heavier. The ghost still
thins to 0.55 over a split. It is a 48px chip centred on the pointer, and in the
top or bottom third of a 104px tile it sits right over the edge the bar is on.

Dwindle has no "open A against B" to dispatch. What it has is the path a window
takes into the tree, `CDwindleAlgorithm::addTarget` (read in Hyprland 0.56.2's
source, not assumed). That path picks the window to split (`OPENINGON`), then the
axis and side. So the drop is one `hyprctl eval` chunk (`_splitChunk`) that sets
the path up to pick B and the side asked for, then floats A and tiles it again,
which sends it through. That works whether A starts on B's workspace or another,
and takes a window that started floating into the split too. What the path picks
depends on whether B's workspace is on screen, so the chunk takes one of two
roads, chosen live.

**On screen.** With `use_active_for_splits` on (the default) and no focal point,
`OPENINGON` is the *focused* window. The axis and side come from `preselect` if
one is pending. Otherwise the target's shape decides (wider than tall: side by
side) and `force_split = 2` puts the newcomer second, which is why the boundary
walk can never put a window above a full-width one. So: focus B,
`preselect <dir>`, tile A, `preselect none`, refocus whatever had focus.
`preselect` is a layout message, and `CLayoutManager::layoutMsg` sends it to the
focused monitor's active workspace (its special workspace if one is shown) with
no workspace or window argument. That is why this road cannot leave the screen.

**Off screen.** The focused window is not on that workspace, so `addTarget` falls
through to `getClosestNode(MOUSECOORDS)`, the window nearest the pointer. With
`smart_split` on, the pointer's offset from that window's centre picks the side
by triangle: top, bottom, left or right, independent of the window's shape. So:
read `smart_split`, set it on, `cursor.move` to the middle of B's half on that
side (a quarter of B from its centre), tile A, then restore `smart_split` and the
pointer. Nothing is focused and the visible workspace never changes.
`hl.config` at runtime only parses the value and schedules a refresh
(`hlConfig`, `LuaBindingsConfigRules.cpp`), so the toggle is cheap. This road
can split a tall window left and right, which dwindle's shape rule never would.

Ruled out on the way there:

- **Targeted moves can't stand in for either road.** `window.move({ direction })`
  splits whatever is next to A, on the axis its shape dictates, and its own
  special case overwrites a pending `preselect` when A moves toward a
  single-window partner. `window.swap({ target })` swaps, it does not split.
  `movetoroot` takes a window but is still a layout message.
- **Moving to a workspace passes no focal point**, so on a hidden workspace a
  window lands next to whatever is nearest the pointer, wherever that happens to
  be. The off-screen road works by choosing that position deliberately.
- **`use_active_for_splits = false` doesn't help off screen.** With it off, a
  hidden workspace falls through to `getFirstNode()`, the oldest node in the
  tree, which may be an internal one.

Both roads, the details:

- **The pointer.** On screen it stays put with `cursor:no_warps` on (set here):
  `Actions::focus` calls `warpCursor()`, and `CPointerController::warpTo` returns
  early on `no_warps` unless forced. Without it the pointer would warp to B. Off
  screen it is moved on purpose. Either way the chunk compares
  `get_cursor_pos()` before and after and moves it back, and since `cursor.move`
  forces the warp, only if it actually moved.
- **The warp reaches the strip as motion.** `cursor.move` ends in
  `simulateMouseMovement()`, and both warps arrive at the HUD's surface. Left
  alone, that motion is hover and would move the highlight off the window that
  was just dropped. `splitSettling` holds hover off for 600ms.
- **Focus.** With `follow_mouse = 2` (set here) a warp only moves keyboard focus
  if the window under the pointer differs from the focused one in floating
  state (`float_switch_override_focus`). The tail refocuses the window that had
  focus if anything changed, but **only if it is still on the visible
  workspace**. Focusing a window anywhere else would switch to it, and the
  window that had focus may be A, now on another workspace.
- **The tail runs whatever happens.** The steps run under `pcall`, then
  `preselect none` or the `smart_split` restore, plus a second unfloat of A,
  always follow. A pending preselect would apply to the next window opened, and
  a `smart_split` left on would steer every split after it.
- **The checks run again live in Lua:** B tiled, no fullscreen on its workspace,
  A not fullscreen, neither window in a group, layout `dwindle`, and on screen
  no special workspace shown. A refusal falls back to the plain workspace move.
  The strip checks what it can see beforehand (`_splitTileAt`): floating tiles,
  the tile in the hand, a workspace with a fullscreen window and a non-dwindle
  one keep the boundary offer.
- **The focus round trip is kept out of the history.** On screen, both
  activewindow events reach `onActiveToplevelChanged`. `splitFocusGuard`
  ignores B for 600ms, and the hand-back is a no-op there because it returns to
  the front of `focusHistory`. Without the guard, the next `SUPER+TAB` would
  alternate to B.
- **The auto-scroll redoes the whole hit-test** (`_dragTo`) rather than updating
  only `dropWsId`. A strip scrolling under a still pointer changes the tile and
  the slot as well. The slot was going stale before this.

Verified on throwaway `foot` windows (2026-10-22), running the chunk exactly as
`_splitChunk` generates it:

- **On screen**, on the focused workspace: `u`, `d`, `l` and `r` each put A on
  that side of B at half of B's box. A sent to workspace 9 first came back above
  B with the view still on 3. Focus returned every time, the pointer never
  moved, and closing both left the workspace exactly as it started. That was
  before the chunk grew its second road; the on-screen steps are the same ones,
  re-ordered under an `if`, and have not been re-run since.
- **Off screen**, on workspaces 8 and 9 opened with `workspace = "8 silent"` so
  nothing was focused. P and Q were side by side and A came in from 9: above P,
  below P, left of P (a left/right split of a tall window), right of Q and above
  Q all landed as aimed. `smart_split` read false after every chunk, and the
  view stayed on 4 throughout.

### Where each window sits (2.7.0)

While a drag is over a workspace, each of its tiles carries a dot in the
theme's accent (`#007AFF` in these themes) at the point of the tile matching
where the window is on that workspace: a corner for a quarter, the middle of an
edge for a half. `_placePositions` classifies each tiled window against the
box its workspace's tiled windows cover between them, not against the monitor,
so gaps, the bar and reserved space drop out without being known. Touching that
box's left edge and not its right is left; both is the full width; neither is a
middle column. Windows on an edge sit on it exactly, and a 4px slack absorbs
rounding. **No dot for a window that would get the centre**, i.e. one that
spans or sits in the middle of both axes: alone on its workspace, a middle
column the full height, a middle row the full width. The centre says nothing
about where to aim, and it lands on the tile's mark (2026-10-22, the user's
call; it used to show). Floating and fullscreen windows are not part of the
tiling and get none either, and nor does an empty workspace's tile. It sits in from the tile's edge by the card's padding
(6px), the distance the tiles sit from the card's edge. It started at the tile's
content padding (12px) and moved closer to the edges at the user's call.

**Only during a drag, and only on the workspace under it** (2026-10-22, the
user's call). It is the map a split is aimed by, and shown on every tile all the
time it was noise. The dot's `visible` is bound to `dropReady` and
`dropWsId`, the same pair the group highlight reads, so the dots and the
highlight always mark the same workspace. Showing them on hover as well, for
the workspace under the pointer, was tried on 2026-10-23. The user rolled it
back the same day and preferred drag-only.

The position is part of `_sameWins`, because a split can change it without
changing the order. Two windows side by side, stacked instead, sort the same, and
the dots would otherwise go stale.

## Re-arranging workspaces (2.8.0)

Each group has a handle floating under the card, centred on its run of tiles: a
plain pill of solid accent (`#007AFF`), no border, nothing in it. **It is
measured in one unit, the card's bottom inset** (border plus padding, the
distance from the tiles down to the card's lower edge). A handle is
`card.handleUnits` tall (1.75, stepped by quarters) and twice that wide: at
base-size 18 the unit is 12 (3 + 9), so 42×21. It follows the text size and
`switcher-card-padding` with the card.

**It floats twice the card's padding below the card**, as the theme step
nearest that: `Style.spacing.xxl`, which is exact, 2×6 = 12 at scale 1 and
2×9 = 18 at base-size 18 (the user's call, 2026-10-23). It was one unit, 12
here, as far outside the card as the tiles sit inside. "Padding" is taken
without the border: twice the inset would be 24, equidistant from `xxxl` (21)
and `huge` (27).

**A handle takes a press `handleReach` below its pill**, the same unit as the
gap (the user's call, the same day), so 18px of target under a 21px pill
here, with nothing drawn there. The row is that much taller to carry it: it
clips, and Qt delivers no input to a child outside a clipping parent. The
hover band in `_overSwitcher` and the drop zone in `_wsDragTo` both read the
row's height, so the handle stays shown over its reach and a carry there still
drops.

**Only the hovered workspace's handle shows**, crossfading between groups the
way the highlight crossfades between tiles. **Its fade takes the items'
length, `animDuration` (58ms), on its own curve:** `Easing.OutCubic`,
Omarchy's QML fade curve, not `animCurve`. A separate `handleFadeDuration`
existed briefly and was folded back into `animDuration` at the user's call. Both are the user's calls from
2026-10-23. Doubling the length to 116ms came first and changed nothing on
screen. Hyprland's `default` curve front-loads the change: at 120Hz a handle
reached 60% in one frame and 73% in two at 116ms (73 and 87 at 58ms). An
offscreen `qmltestrunner` copy of the delegate showed the fade running, with
no delegates rebuilt, and jumping 0 → 77% on its first 60Hz tick. So it was
the curve. The selection survives that curve because it steps the card's
colour by a shade; a saturated pill on the desktop does not. OutCubic over
116ms ran 20, 37, 52, 64, 73, 81% by frame (43, 72, 82, 94% on the test's
ticks), and the outgoing handle ended at 0 and not visible. The user then took
the length back to 58ms, where OutCubic runs 37, 64, 82, 92, 98%. `handleWsId` is a binding off
the pointer's last panel position, not a value set on hover. Every MouseArea
the pointer can be over reports to `_notePointer`: the click-away (made
`hoverEnabled` for this), the tiles and the shown handle. So it follows the
strip moving under a still pointer: a scroll, or the re-sort after a drop.
`_wsUnder` works by x alone on `_wsAt`'s nearest-tile rule, over the card, the
gap and the handle row, so the pointer can travel down from the tiles to the
handle without crossing a gap where it hides. A carried handle stays shown
wherever the pointer goes. None shows during a tile drag. A hidden handle is
`visible: false`, so a press there reaches the click-away.

How it got there, all on 2026-10-23 at the user's call: first 48×24 through
`Style.space()` in the card's own chrome (menu background and border, a 3×2
grip of dots at 0.52, the selected fill under the pointer), which drew at 72×36
here; then solid accent with white dots at 44×22 the same way, 66×33 here and
still too big; then this unit at two units, 48×24; then the dots dropped and
1.5 units; then 1.75, every handle hidden until the pointer was over the
switcher, and straight after, before it was ever seen, only the hovered
workspace's. The first report gave 48×24 without saying it was at scale 1, so
the 44×22 asked for next was a reduction from a size never on screen.

**Using a handle never switches** (the user's call, the same day). A press sets
`stayPut`: `commit()` then dismisses without focusing, `_stayPut` moves the
highlight to `_hereIndex()` (the empty workspace on screen, else the focused
window), and hover stops moving it. A SUPER+TAB strip opens on the MRU window,
so before this a re-arrange followed by the release went there. A TAB, a click
on a tile or `_dragStart` clears it, since each is a choice again, as do
`_openStepped`, `close` and `dismiss`. A press on a handle without a drag counts
too.

Carrying one along the row moves that workspace to the boundary dropped on.
The handle follows the pointer along the row, the group's tiles fade to 0.3 as
a dragged tile does, and the target boundary is a group rule lit in
`selectedText`, at the rules' full card height. It is centred in the padding at
either end. The boundaries either side of the carried group are no-ops and draw
nothing. The handles live outside the ListView, so their presses never reach
`tiles`, and the two drags cannot overlap: `_dragCancel` clears both.

**The places keep their numbers; the workspaces move between them.** The
groups' ascending ids are the places, the carried workspace is taken out and put
back at the boundary, and the workspace in place *p* takes place *p*'s id. An
empty group is a place like any other. On a strip of 1–5 plus 8, dragging 8 to
the front makes the old 5 the new 8. Compacting to 1–6 was the alternative,
and it renumbers workspaces nobody touched.

**Renumbered, not moved.** Hyprland 0.56.2 has `hl.dsp.workspace.change_id`
(`CWorkspace::changeID`): same object, new id, the name following unless
renamed, and it posts `changeworkspaceid>>OLD,NEW`. Windows, layout tree, split
ratios and which workspace is on screen are all untouched. Moving every window
instead would rebuild each tree in arrival order and lose the split ratios.
`change_id` refuses a held id (`Actions::changeWorkspaceID`: "ID is taken"), so
the chunk parks every moving workspace at 2000000000 + its old id, then places
it. It checks first, and on any refusal it undoes in reverse: placed ones back to
their parking ids, then all back home. `hl.dispatch` returns `{ ok, error,
code }` rather than raising, which is what the chunk tests. `hyprctl eval`
prints only `ok` or an error, so results were read back through a global
and `error()`.

**Layout has to be carried by hand.** Omarchy's toggle keeps dwindle or
scrolling per id: a runtime `hl.workspace_rule` plus
`~/.local/state/omarchy/workspace-layouts/<id>.lua`, loaded on every config
load. Rules re-apply by the new id (hyprtester
`workspaceChangeIDUpdatesRules`), and `CWorkspaceAlgoMatcher::
updateWorkspaceLayouts` rebuilds a workspace only when its layout differs. So
the chunk adds a rule on the new id where the layout differs from what that id
already had, and permutes the files in the toggle's own format. It reads all
of them before writing any. The rules land in the same pass, because
`changeID` only schedules its refresh.

**Quickshell 0.3.1 ignores `changeworkspaceid`** (`connection.cpp` has no
branch for it), and a `HyprlandWorkspace`'s id is fixed once set. Omarchy's
bar reads per-object `toplevels` and `focusedWorkspace`, so it would show the
old numbers. `workspaceResync`, 120ms after the event, runs
`refreshWorkspaces()` and `refreshMonitors()` after the 24ms
`refreshToplevels()`. Toplevels re-link by workspace *name*, creating missing
objects with id -1. `refreshWorkspaces` fills those ids, and `refreshMonitors`
moves the active workspace. Both QML entry points run with `canCreate` false,
so an object whose id stopped existing is never removed. **Open:** a re-arrange
that empties an id above 5 leaves a dim bar pip until a config reload or a
destroy event for that id. Every way found to force one has side effects: a
`configreloaded` injected through `hl.dsp.event` reaches every socket2 client,
and a focus round trip pollutes the workspace history.

**Verified.** On the live desktop, the chunk swapped workspaces 3 and 4 (both
off screen, all dwindle, no layout files): four windows changed workspace with
identical geometry, names followed, and running the same chunk again restored
`hyprctl clients` byte for byte. The rest ran against a mock `hl` in Lua 5.4,
with the chunk generated from `Hud.qml` by Node. Five cases: a scrolling
workspace dragged to the front of two saved dwindle ones (rules `1=scrolling
3=dwindle`, files permuted), a refusal in phase 1 and in phase 2 (full
rollback, no rules, files untouched), a drag past an empty place, and a target
held by a workspace that is not moving (nothing changes). The drag itself, the
handles' look and the bar's resync are for the user to judge on screen.

## Back-and-forth

A single `SUPER+TAB` returns to the window or empty workspace you came from, and
a second brings you back — the alternation every Alt+Tab has. **The tiles are not reordered to do
it.** They stay sorted by workspace then on-screen position; the focus history
only moves where the highlight *starts*.

- The **first forward tap** lands on the previously focused window or empty
  workspace.
- **Further taps in the same gesture** walk the positional order from there, so
  the highlight moves along the strip the way it looks like it should rather
  than hopping around a history the tiles do not show.
- **SHIFT+TAB** is purely positional. Stepping backwards through a history the
  strip does not display has no visible meaning.

The history is kept in the plugin (`focusHistory`, updated from
`Hyprland.activeToplevel` and `Hyprland.focusedWorkspace`) because nothing
compositor-side offers it in a usable form: `activated` only ever says what is
focused *now*, and `lastIpcObject`'s `focusHistoryID` is a stale snapshot —
measured sitting at `2/1/0` across two focus changes. It shifts only when where
you are actually changes, so committing to the window you are already on cannot
erase the one you wanted to go back to.

**It holds tiles, not windows** (2.8.2): a window by its address, an empty
workspace by the `ws:N` its tile carries. Until 2.8.2 it held windows only, and
a blank desktop broke the alternation both ways (the user's report,
2026-10-24). A tap from one went to the window *before* the one you left, and a
tap from that window never went back to the blank desktop. The cause is in
Quickshell, not the plugin. Hyprland reports focus moving to an empty workspace
as `activewindowv2>>` with no address, and Quickshell's handler returns on the
failed parse (`connection.cpp:601`, 2b4501a). So `activeToplevel` and
`activated` go on naming the window you left, and the history never moved.
`_hereKey()` therefore reads "on an empty workspace" as *the active window is
not on the focused workspace*, compared by id. `_activeIndex()` checks for the
focused workspace's tile before `activated`, since `activated` is stale there.

**A list, most recent first, eight deep**, not the last two. A switch to a
window on another workspace arrives as two events, `workspacev2` first, and
between them `_hereKey()` reads `ws:<new workspace>` with the old window still
active. That workspace holds the window being switched to, so it has no tile.
`_mruIndex()` returns the newest entry that has a tile and is not where you are,
and steps over that key. With only two entries, the passing key would have
pushed the real one out.

The same skip covers an entry that has gone: a window closed or moved to a
special workspace, or an empty workspace that has since got a window. The tap
goes to the one before it. Before 2.8.2 that fell back to the next tile
positionally. `_mruIndex()` returns -1, and the tap goes positional, only when
no entry in the history is on the strip.

Three details hold it together:
- **Where you are is noted again at every open** (`_openStepped`). Closing the
  last window on a workspace clears `activeToplevel` before the window leaves
  the workspace, so no signal fires once the state is consistent.
- **An empty workspace with no tile** (above 5) leaves `_hereIndex()` at -1. The
  strip still steps from the window you left, but `_mruIndex()` does not skip
  that window. It is the one to go back to.
- **A workspace re-arrange renumbers the history** with the same `newId` map
  that carries the highlight, and `_noteHere()` records nothing while the chunk
  runs or `workspaceResync` is pending. In that window Quickshell's workspace
  objects can disagree with the windows on them.

Verified on 2026-10-24 against a mock `Hyprland` in Node. The harness ran
`_hereKey`, `_noteHere`, `_hereIndex`, `_activeIndex` and `_mruIndex` extracted
verbatim from `Hud.qml`, fed Quickshell's event order. Window to empty
workspace and back, empty to empty, empty to a window on another workspace,
the remembered window closed, the last window on a workspace closed, an empty
workspace above 5 and the cold `focusHistoryID` path all land as described;
HEAD's logic on the first case lands on the window before. Not yet exercised on
the live desktop.

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
  the very first summon after a shell restart nothing reports it.
- **Focusing an empty workspace does not clear `activeToplevel`.** Hyprland
  sends `activewindowv2>>` with no address, Quickshell's handler returns on the
  failed parse, and the window you left stays `activated`. Only `closewindow`
  of that window clears it. See *Back-and-forth*. There is a
  `focusHistoryID` fallback for exactly that one cold case — accurate there,
  because the snapshot was just refreshed.

## Look

The card binds `Color.menu.background` / `Color.menu.scrim` / `Color.menu.border`
and `Style.cornerRadius`, so it tracks the active theme's menu chrome with no
plugin-side theming. Under **omarchy-cllpse-theme** that means:

- corner radius follows `decoration:rounding` (16) like every shell surface;
- the card is opaque — `[menu] background-alpha` is 1.0 in
  `*/shell.menu.toml`, so the card is solid and the layer
  blur rule is inert for it;
- the scrim **binds `Color.menu.scrim`**, so it is the same dim the SUPER+SPACE
  menu draws — **when it is drawn at all: it is switched off for now.**
  `readonly property bool showScrim: false` in `Hud.qml` hides it, and the card
  sits straight on the desktop with only its border separating the two. The
  scrim, its binding and its fade are all kept, so turning it back on is that
  one line; clicking beside the card still dismisses either way, since the
  click-away is the window's input region and not the scrim. Everything below
  describes it as it is when on. It used to compose its own colour at 0.35 — the value the inert
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
  token for token: `Style.spacing.xs` between items, `Style.cornerRadius` on the
  card, the same `Border.surfaceSpec("menu", …)` card border and
  `selected-border` spec on the cursor cell, labels in
  `Style.font.heading`/Medium and the secondary line in `Style.font.bodySmall`
  at 0.52. (Since 2026-10-11 the label is `Style.font.title`/Medium, the
  supermenu's item size, now that SUPER+SPACE opens the supermenu. The
  secondary line was `title` at 0.52 too until 2026-10-17, now `Style.font.body`
  at 0.52: a stacked detail line a step under its name, as the menu's is.)
  Cell height derives from those tokens with a floor, the way the
  menu's `baseRowHeight` does, so it survives `omarchy display text size`.
  **The one deliberate departure is the icon** at `Style.font.display` (2.0 rem):
  in the menu the icon sits inline beside a label, here it is the primary
  element of a card, like a macOS Cmd-Tab tile;
- **the padding departs too, so the highlight's corner can be concentric.** The
  highlight, and the drop target, use `card.innerRadius`: the card's radius less
  its inset to the tiles (border + padding), so the two curves run parallel. At
  the menu's `panelPadding` (18, 20 at text size 13) the tiles sat 22 in from an
  18 corner, where concentric works out to 0, and the highlight drew at the
  card's full 18 instead, which read as too round for where it sat. The card's
  padding is now its own token, `switcher-card-padding`, defaulting to 6 (7 at
  text size 13): inset 2 + 7 = 9, corner 18 − 9 = 9. The card draws in closer
  around the strip as a result. The rounding is Hyprland's and does not scale,
  so a larger text size, which grows the padding, rounds the highlight less;
  `innerRadius` floors at 0;
- **the group rules sit the card's padding from their tiles.** A rule runs the
  card's full height and divides it the way the border bounds it, so the run
  between two groups is padding + stroke + padding, and `groupGap` is derived as
  that less the ordinary tile gap (14 at text size 13). It was a flat 36 (39),
  which put ~19.5 either side of a rule and matched the menu-sized padding; once
  the padding came down to 7 the rules sat in nearly three times the border's
  margin. Measured from a screenshot at 4/3: border to first tile 9 device px,
  rule to neighbouring tiles 9.5–10. A theme's `switcher-group-gap` still
  overrides the derived value;
- **the highlight fades, and the name does not change colour.** Each tile
  carries the selected fill and `selected-border` as its own `selectionFill`,
  beneath its content, and fades it over 58ms on Hyprland's `default` curve
  rather than switching it. It shares `root.animDuration` / `root.animCurve`
  with the scrim's fade. It was 140ms on `OutCubic`, Omarchy's opacity fade
  for a hovered widget (`WidgetButton.qml`). The tile losing the selection fades out while the one gaining it fades
  in, under the pointer and under TAB alike, since both move `root.index`. The
  fade is enabled only while the strip is open, and `_openStepped()` sets the
  index before `opened`, so an open shows the selected tile already lit. A slide
  was tried first — one surface beneath the list, moving between tiles; it
  measured 1044 → 1221 → 1263 → 1266 on a step — and dropped for the fade. The
  tile name stays `Color.menu.text` when selected. It used to switch to
  `selected-text` (blue) the way a menu row does, but with an animated fill the
  colour arrived before the highlight did. The Nerd Font glyph fallback still
  takes the selection tint;
- **no blur.** The HUD used to be in the blur `hl.layer_rule` in
  `overrides/hypr/looknfeel-decoration.lua`, so it would frost exactly like the
  Omarchy menu. With the card opaque and the scrim off, that blur drew nothing,
  and it halved the frame rate of everything that animates on this full-screen
  layer. Measured with Qt's render-loop timing (`quickshell --log-rules
  'qt.scenegraph.time.renderloop.debug=true'`) while stepping the highlight:
  16–17ms between frames (60 fps) with the namespace in the rule, 8ms (120 fps,
  the output's rate) without it, Qt rendering in ~0ms in both. It was taken out
  of the rule. Add it back only alongside a translucent card, and expect the
  60 fps.

### Icons

The tile's mark is a Nerd Font **glyph rendered as text**, coloured from
`Color.menu.text`, so it is flat and tracks the theme with no file on disk and
nothing to regenerate. That is the same track the Omarchy menu uses for its
non-app rows; the menu's *app* rows are the exception — they draw a plain
`Image` of the vendor icon with no recolouring, which is what
`overrides/icons/icons/` and the `app-icons.sh` theme-set hook exist to
replace.

The switcher keys on the **window class** while a drop-in is named for the
desktop entry's `Icon=`. Those agree for most apps but not all — measured on
this machine, 5 of the 24 entries declaring `StartupWMClass` use a class that is
not their icon name, and Chromium's is the literal unsubstituted
`@@startup_wm_class`. A drop-in whose filename differs from the class reaches
the menu but not the switcher; drop a second copy named for the class to cover
both.

### Terminal icons

A terminal tile carries a second mark for **what is running inside it** —
two-thirds the size of the terminal's own icon, flush into its bottom-right
corner.

**The title is the only signal there is**, and that took measuring to establish.
Ghostty runs `--gtk-single-instance=true`, so every one of its windows reports
the *same* pid — measured here, four windows all `pid=3242`. The compositor
cannot say which process belongs to which window, and no process-tree walk
recovers it: the shells are all children of that one pid with nothing tying a
child back to a surface.

The title turns out to be the better signal anyway. Ghostty's shell integration
sets it to the command **as typed**, so an alias arrives as itself and
`windowtitle`/`windowtitlev2` are already in `refreshEvents` — an icon follows
the foreground command live with no new machinery. Verified against the live
window set:

| title | reads as |
|---|---|
| `◑ Switcher plugin drag to workspace` | `claude` |
| `✳ App and TUI logo fetcher` | `claude` |
| `diff` | `hunk` (alias, `shell.sh:150`) |
| `~/Sites/omarchy-cllpse-macos/logos` | idle shell — no icon |
| `btop` | `btop` |

- **Aliases are the join, for two separate reasons.** The title carries what was
  *typed*, so `diff` and `log` map back to `hunk`, `dash` to `gh`, `edit` to
  `msedit`, `ls` to `lsd` — each carrying the `shell.sh` line it comes from. And
  the drop-ins are named for a desktop entry's `Icon=` rather than for anything
  you would run, so `claude` maps to `claude-code`, `node` to `nodejs`, `psql`
  to `postgresql`, `ytm` to `youtube-music` and so on — a mark is named for the
  app or the service, never for the command that happens to start it. Everything unlisted resolves by its own name, which
  is most of the set — `bat`, `curl`, `docker`, `fd`, `ffmpeg`, `git`,
  `mongosh`, `npm`, `nvim`, `python`, `ruby`, `sqlite`, `starship`, `tmux`,
  `uv`, `zoxide`. **Alias after the branches, never inside one**: the table sat
  in the last branch once, so a claude session — recognised by its marker and
  never by a command name — skipped it entirely, looked for `claude`, found
  nothing and drew no icon while every other program resolved correctly.
- **Claude Code is recognised by its status marker.** It overwrites the title
  with `<marker> <what it is working on>`; the markers seen here are U+25D0,
  U+25D1 and U+2733, and the rest of that family is included rather than waiting
  to be surprised. There is a looser fallback — a leading symbol followed by a
  space — which is the one guess in the file, on the grounds that nothing else
  on this machine titles itself that way. If something starts, tighten that line.
- **The marks came from `../icons/color/`** — the verbatim set, the one the
  Figma logo lives in; it lives in both repos now, the plugin's own `icons/` and
  `overrides/icons/verbatim/`, which is what `app-icons.sh` reads — reached
  through that sync to `~/.icons/cllpse-color/apps/`, which the plugin's vendor
  sweep already covers.
  The path mattered then: it was *not* under `flatIconDir`, so the icon was
  drawn in its own colours rather than repainted, and that was the whole point
  of that directory. **Both halves of that are gone now.** The plugin ships all
  77 of those marks itself, and it recolours nothing at all, so a mark is drawn
  as authored wherever it resolves from and the directory it came from decides
  nothing. Resolution still goes through the same indexes a window class does,
  in the same order, so a terminal icon and an app tile can never disagree
  about what a program looks like. **No glyph fallback**: at that size a Nerd
  Font glyph is a smudge, and "no icon for this" reads better as none than
  as a mark nobody can identify.
- **Nothing sits behind the icon.** Two separation layers were tried and both
  were worse than nothing. A filled rounded rect in the tile's background colour
  is a *box*, and it is visible as a box the moment the theme stops matching the
  art — invisible on light, then punching a dark square through the ghost on the
  first dark theme, which made a Claude mark look like it had a backdrop it does
  not have. A `MultiEffect` shadow at zero offset in the same colour fits the
  shape rather than a rectangle, which is the right idea and still failed on the
  mark that matters most: Claude's logo is a sparse radial burst, so a
  silhouette blurred and scaled 18% up has more area than the rays casting it
  and pools into a smudge between them, landing on the ghost's white body at
  maximum contrast. It read cleanly on solid marks like `btop`'s, which is
  exactly why it survived a first look. The icon hangs mostly *outside* the
  icon at the current offset, so it needs less separation than either attempt
  assumed. If some future mark does need it, fit it to that mark — don't
  reintroduce a global one.
- **One `MultiEffect` used to serve both kinds of icon** — colorization off for
  a vendor mark so its own colours reached the screen, on for a flat drop-in. It
  arrived with the shadow, outlived it, and then went the same way: an icon is
  the source of truth now and nothing here paints over one. The effect, the
  flat/colour split it keyed on and the `QtQuick.Effects` import are all gone.
- **Behind a `Loader`**, active on the cached `hasProcessIcon`, so a tile
  without one pays for no `Image`. Keyed on the index and never on
  `Image.status`, for the reason `iconFor()` sets out at length.
- **The icon is only as good as what has been synced.** A name that resolves to
  no file draws nothing at all, and the sync is the usual reason: the live
  `~/.icons/cllpse-color/apps/` was holding 4 of the repo's 74 when this was
  written, so `claude-code` and `hunk` both existed and neither appeared.
  `overrides/hooks/theme-set.d/app-icons.sh` is what publishes both directories,
  and it runs on every theme-set and after an `omarchy update` — but not when a
  file is merely added to the repo.

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

- **A mark carries no container of its own.** The switcher draws icons against
  a tile whose colour follows the theme, so a background baked into the file is
  a square of the wrong colour the moment the theme moves — which is what made
  a Claude icon look like it had a backdrop it does not have. Audited by alpha
  across all 99 files: exactly three had a full-canvas background (`hunk`,
  `tldr`, `grok`); everything else is a shaped mark with transparent edges, and
  a high opaque fraction on its own means nothing — Ghostty is 88% opaque
  because the ghost is a solid shape, not because it sits on anything.
  - `grok` was already broken and nobody had noticed: it lives in the
    **repainted** set, so its black background rect and its white slash were
    both rewritten to the theme foreground and the file rendered as a solid
    block. Dropping the rect is the whole fix. *(Correction, 2026-10-09: the
    rect was not actually dropped — grok kept shipping as a solid block until
    then, when the rect went and the `viewBox` was tightened to the slash.)*
  - `tldr` lost only its full-canvas navy rect; the rounded terminal mark and
    its gradients are the logo and stay.
  - `hunk` lost its cream box, which left an `#16140F` glyph against a
    `#1E1E1E` card — a contrast ratio of about 1.05, i.e. invisible. It was
    restored from backup and **kept its box**, staying in the colour set, because
    the box is part of the logo. The alternative was dropping the background and
    moving it to `icons/` where the theme supplies the colour — the rule for
    a monochrome mark that only reads against its own background, and not what
    was done here.
- **A drop-in renders at exactly the size its own ink fills its `viewBox`.**
  The Image draws at `iconDrawn` with `PreserveAspectFit`, so a mark padded
  inside its canvas is scaled to that canvas and comes out small — there is no
  compensation for it and deliberately shouldn't be, since a ratio baked into
  the drawing code is what caused the 256/200 mess this file already records.
  Measured across both icon directories: Ghostty filled 99% x 100% of its box
  while Figma filled 52% x 78% and hunk 42% x 67%, which is precisely how much
  smaller they looked. 29 of 99 files were under 99% on their long axis; each
  had its `viewBox` retightened to its ink bounding box (with `width`/`height`
  brought along, or rsvg reintroduces the old aspect and undoes it).
  **Measure the alpha extent, never a colour trim.** `magick -trim` trims
  whatever colour the corner pixel is, so on the three icons with a full-bleed
  background rect — `hunk`, `tldr`, `grok` — it ate the background and reported
  the inner mark as the ink. Retightening to that cropped hunk's cream box down
  to sit behind its own glyph, which is how the box "disappeared". An icon with
  nothing transparent in it is already edge-to-edge by definition and wants
  leaving alone. That is
  compliance with the contract in `../overrides/icons/icons/README.md`, not
  a new rule: edge-to-edge in the file is what makes every tile agree on size.
  When a mark still looks small, measure its ink before touching anything in
  the QML.
- **The vendor sweep dedupes in the subprocess, not in QML.** It walks ~34k
  files and used to hand back 9106 paths, of which `_applyVendorIndex` kept
  1364 — first hit wins, so 85% of what it parsed was discarded on arrival.
  Measured: 544KB and 9ms of main-thread parse, against 79KB and 4ms once one
  `awk` collapses it to a line per name. Ranking is untouched, and that was
  verified rather than assumed: awk keeps the first path per name walking the
  stream in emission order, so the svg pass still outranks the png pass and
  `$HOME/.icons` still outranks every installed theme — both indexes were built
  and compared key by key, 1364 names each, identical mapping. The awk uses
  `[.]` rather than an escaped dot, because a backslash in that QML string is
  eaten by the JS lexer before bash sees it; `sub(/.[^.]*$/…)` would strip from
  the first character rather than the last dot, silently.
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
  `~/.icons/cllpse-flat/apps/` (synced from `overrides/icons/icons/`), an
  `Image` replaces the text cell for that tile. `.svg` is probed first, then
  `.png`. Everything else stays text — a glyph is crisper at this size than any
  bitmap, and it recolours for free.
- The drop-in is named for the desktop entry's `Icon=` while the switcher only
  has a window class. They agree for most apps but not all (5 of the 24 entries
  declaring `StartupWMClass` differ), so a drop-in whose name differs from the
  class keeps its glyph here — drop a second copy named for the class to cover
  both.
- That image *was* recoloured through `MultiEffect`, not blitted. The PNG is
  baked at the theme `foreground`, but a selected tile draws in `selected-text`
  (`#007AFF` in both our themes) — so a plain `Image` left the *focused* tile
  showing a grey icon under a blue label. Same technique Omarchy uses to tint
  symbolic tray icons (`Tray.qml:789`), measured at ~0.002 ms per icon.
  **Removed since.** The plugin draws every icon exactly as authored, so a flat
  drop-in under a selected tile now keeps the theme foreground instead of
  following the label. That is the accepted cost of "the icon is the source of
  truth", and it is why the plugin ships full-colour marks rather than flat
  ones. (The label has since stopped following the selection too — see *Look* —
  so a flat drop-in and its name agree again.)
- The fallback is `status !== Image.Ready`, so on a machine where `apply.sh`
  step 7f never ran — no `~/.icons/cllpse-flat/` at all — every tile simply
  stays a glyph and nothing breaks.
- The image box is `iconDrawn` — `iconSize * 0.9`, a small optical trim — with
  **no** 256/200 ink-ratio compensation on top of it. It was
  `iconSize * 256/200` while drop-ins were rasters: `app-icons.sh` trimmed each
  mark and re-padded it into 200 of 256 px, so a PNG's ink really was 78% of its
  canvas, while a text glyph at `pixelSize` N fills close to N — drawing one
  into a plain box rendered it visibly smaller than the glyph beside it
  (measured on screen: 27px of ink against the Chromium glyph's 33, 35 against
  33 after). The SVG branch never had that padding, so the same factor drew
  every vector 28% oversized, clipping top and bottom. Dropping the rasters left
  one convention — every drop-in is an edge-to-edge SVG — and `iconDrawn` is
  the whole of the sizing. (This said "in a square `viewBox`"; with
  `PreserveAspectFit` into a square box the canvas need not be square, and 26
  of the 101 marks are not.) Match the **ink**; fix it in the
  file, not with a factor at draw time.
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

- **The switcher appears with no delay, and fades in with the panels.** The
  whole strip ramps in on Hyprland's layer fade, the same as the SUPER+SPACE
  menu. Two separate things have to be right for that.
  - *No timer in the QML.* The panel maps as soon as its content is ready,
    exactly as `Menu.qml:1019` does (`visible: root.opened && root.rowsLoaded`;
    here `opened` is set when the client list parses). A 150ms show delay was
    tried — borrowed from GNOME's `POPUP_DELAY_TIMEOUT`, to stop a quick tap
    flashing the strip — and removed. Don't re-add one.
  - *The fade is the compositor's.* `omarchy-window-switcher-hud` is in the
    `animation = "fade"` layer rule in `overrides/hypr/looknfeel-decoration.lua`
    alongside the panels, so it fades in over `fadeLayersIn` and out over
    `fadeLayersOut`: 58ms (7 frames at 120Hz) on `almostLinear` at our speeds. Those two leaves
    drive a layer's alpha (Hyprland v0.56.2 `LayerSurface.cpp:213-215`, :251-253).
    `layersIn` / `layersOut` drive only its position and size, which the `fade`
    style leaves still. Duration is the fade leaves' speed, shared with every
    animated layer. There is no per-rule duration or curve.
  - *The scrim is off, and its own fade is kept.* With `showScrim` false (see
    *Look*) the card is all there is to fade. The scrim `Rectangle` in
    `Hud.qml` still carries its own `opacity` animation (`Behavior` +
    `NumberAnimation`, 58ms on Hyprland's `default` curve, cubic-bezier(0, 0.75,
    0.15, 1); it was 120ms on `Easing.OutCubic`, Omarchy's own curve for a QML
    fade), written for a surface the compositor does *not* fade. Turned back on
    as things stand, the scrim fades with the card and that ramp stacks on top,
    so the dim lands a little behind. For a card that lands instantly with only
    the scrim fading, the namespace needs `no_anim = true, animation = "none"`
    as well as leaving the fade rule: Omarchy's own `no_anim` list does not name
    it, so leaving it out alone still fades it.
  - *History.* Hyprland fades a layer surface as it maps (`layersIn`,
    `style=fade`, ~130ms at our speeds). Omarchy opts its own panels out of that
    in `default/hypr/apps/omarchy-shell.lua` — line 5 for the bar, line 10 for
    `^(omarchy-menu|omarchy-image-selector|omarchy-emojis|omarchy-clipboard|omarchy-keyboard-panel)$`
    — a literal alternation a third-party namespace cannot join, so the HUD
    faded while the menu snapped, and that mismatch was the original complaint.
    It was first fixed by opting the switcher out too, with the scrim-only fade
    above: card interior `269 → 118` in a single step, scrim
    `259 → 230 → 228 → 227 → 225` decelerating over ~120ms. Then
    `overrides/hypr/looknfeel-decoration.lua` re-enabled the fade for the whole
    panel family, so they are consistent with notifications / OSD / polkit,
    which were never opted out and always faded, and the switcher joined them.
    Measured by burst-`grim`ing the scrim as it opens: menu
    276 → 271 → 254 → 239 → 238, switcher 276 → 273 → 265 → 255 → 246 → 239,
    both ~100ms ramps where they were previously a single hard step. The
    switcher then went back to the scrim-only split, because a card that ramps
    in reads as slower than one that is simply there. Then its scrim was
    switched off, which left nothing fading at all, and it rejoined the fade
    rule. The panels kept the fade throughout; their scrim lives in Omarchy's own
    `Menu.qml`, so the split is not available to them without patching
    `/usr/share/omarchy`. A later layer rule wins over an earlier one, so none
    of this needs an edit to Omarchy's file.
- The plugins dir is watched with `inotifywait -r`; live edits inside a
  *symlinked* plugin may not auto-reload. Run `omarchy-restart-shell` after
  changing files here.
- The dir name is cosmetic — Omarchy keys plugins by `manifest.json` `id`, not
  the folder. The symlink is named for the id so enablement and keybinds don't
  care that the source moved.
