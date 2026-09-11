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
Figma Desktop isn't in Omarchy's own list, so `overrides/hypr/looknfeel-decoration.lua`
adds it: `.*[Ff]igma.*` against the class (the live class is lowercase
`figma-desktop`), untagged and pinned to `1 1`, same idiom as
`davinci-resolve.lua`.

**Backgrounds are filtered by extension.** Both `omarchy-theme-bg-next` and
`omarchy-menu-images` enumerate with
`-iname '*.jpg' -o '*.jpeg' -o '*.png' -o '*.gif' -o '*.bmp' -o '*.webp'`.
**`.heic` is invisible** — not listed, not selectable, not displayable. They use
`find -L`, so symlinked images *are* followed and matched on the target's type.

**A theme's default background is whichever file sorts first — there is no key
for it.** `choose_theme_background` (`omarchy-theme-set:72`) enumerates
`~/.config/omarchy/backgrounds/<theme>/` and the theme's own `backgrounds/`
into one `sort -z`'d list, then: if the *current* background is in that list it
takes the **next** one (wrapping), otherwise it takes `backgrounds[0]`. So
switching into a theme lands on the sort-first file, while re-running
`omarchy theme set` on the theme that is already active **advances the
wallpaper** — which is why `apply.sh` step 8 records the current background by
name and puts it back. `OMARCHY_THEME_SKIP_BACKGROUND=1` is the supported way
to re-publish a theme without touching the wallpaper at all (line 306/310), and
is what to use after editing a theme folder. Ours pin a default by filename:
`00-umeda_wallpaper_desktop*.png`, `00-` chosen because digits sort ahead of
letters in both C and the live `en_US.UTF-8` collation (checked, not assumed —
`sort` is locale-sensitive, and the existing `11-`/`12-`/`14-`/`15-` macOS
version prefixes would otherwise win). The user-level directory is the other
lever — `/home/…/.config/…` sorts before `/home/…/.local/state/…`, so anything
dropped in `~/.config/omarchy/backgrounds/<theme>/` outranks every file in the
theme — but a copy there shows up in the picker *alongside* the theme's own,
listing the same image twice. Renaming in the theme folder has no such
duplicate.

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

**Generated, never committed:** `btop.theme`, `hyprland.lua`,
`vscode-theme.json`, `neovim.lua` and the terminal colour files are produced from
`colors.toml` on every theme-set. Omarchy strips `.lua` from *git-cloned* themes,
which is why window decoration lives in `overrides/hypr/`, not in a theme folder.
Our themes are symlinked rather than cloned, so nothing is stripped.

**`chromium.theme` is committed, by exception.** Omarchy's template is
`{{ background_rgb }}`, so the generated seed for the light theme is
`255,255,255` — pure white. Fed to Chromium as the `BrowserThemeColor` managed
policy (`/etc/chromium/policies/managed/color.json`, written by
`omarchy-theme-set-browser` from `~/.local/state/omarchy/current/theme/chromium.theme`),
a zero-chroma seed leaves menu colour IDs unresolved and Chromium paints
separators with its placeholder cyan. Each theme folder therefore ships an
explicit `chromium.theme`: light `236,236,236` (`#ECECEC`, the AppKit
`NSColor.windowBackgroundColor` catalog value for aqua — BUILD.md §2 reads the
composited window as `#FFFFFF`, which is the degenerate case), dark `30,30,30`
(`#1E1E1E`, matches BUILD.md §1). `omarchy-theme-set-templates` skips generation
when the file already exists in the staged theme.

**The menu draws icons two different ways, and only one of them is flat.** Rows
that are not apps render `row.icon` as *text* in a Nerd Font, tinted
`foreground` (`Menu.qml:1240`) — that is the flat, theme-tracking look, and it
is what every bar widget, OSD and our own switcher HUD uses. App rows instead
render a plain `Image` of whatever the entry's `Icon=` resolves to
(`Menu.qml:1253`), with **no recolouring whatsoever**. Measured on this machine,
48 of 52 visible desktop entries land on a full-colour vendor logo. The tray is
a third case: `Tray.qml:789` applies `MultiEffect { colorization: 1.0 }`, but
only when `iconIsSymbolic()` is true — i.e. the name ends in `-symbolic`
(`Tray.qml:146`). App icons are never tested against that.

**`AppLibrary.iconSource()` consults its own index before the themed lookup, so
`icon-theme` barely matters for apps.** The order is absolute path → `iconIndex`
→ `Quickshell.iconPath()` → `application-x-executable`. That index is built by
shelling out to `find` across every XDG icon dir (`*/apps/*` and `*/devices/*`),
**svg pass then png, first hit per name**, and it is completely theme-blind — it
will happily return a 16×16 `HighContrast` bitmap if that is what `find` reaches
first (three Avahi entries and `firefox` do exactly that here; `uuctl` gets a
Yaru 16×16 upscaled to 21px). Two consequences worth remembering: setting
`gsettings icon-theme` does *not* reliably change what the menu shows, and
`$HOME/.icons` is the **first directory scanned in both passes**, so a file
dropped there outranks every installed theme. Because such a directory carries
no `index.theme`, GTK and Qt ignore it entirely — the override reaches the
Omarchy shell and nothing else. That is the whole mechanism behind `apply.sh`
step 7f and `overrides/icons/fallbacks/`. Nothing there is generated: each icon
is a hand-placed SVG named for a desktop entry's `Icon=` value, and an app
without one keeps its vendor icon. An earlier version generated the whole set
from Nerd Font outlines; it was removed in favour of sourcing marks by hand,
because automatic derivation cannot produce a usable mark for a logo defined by
colour boundaries rather than shape (measured: Chromium, OBS and Moonlight all
flatten to featureless discs, and no fill-ratio threshold separates those from
legitimately solid marks — a filled circle scores 0.785, the same range as real
ones).

**Two keyspaces, one rule.** `overrides/icons/fallbacks/` is named for a desktop
entry's `Icon=`; `omarchy-cllpse-switcher/Hud.qml`'s `glyphFor` is keyed on the
window class, because a switcher has nothing else. A single shared key does not
exist — measured here, 6 of the 23 entries declaring `StartupWMClass` use a
class that is not their icon name, and Chromium's is the literal unsubstituted
`@@startup_wm_class`. So the switcher probes `~/.icons/cllpse-flat/apps/<class>`
(`.svg` first, then `.png`) and falls back to its own glyph on anything that is
not `Image.Ready` — which covers a missing file, an empty `fallbacks/`, a
machine where step 7f never ran, and a name mismatch, with no stat() per tile.
A drop-in whose filename differs from the window class reaches the menu but not
the switcher; a second copy named for the class covers both.

Since app icons are never recoloured, a file dropped there has a **fixed**
colour and would not survive a light/dark switch — which is why the rendering is
a `theme-set` hook (`hooks/theme-set.d/app-icons.sh`), not a one-off in
`apply.sh`. `omarchy theme set` restarts the shell, which is what drops Qt's
URL-keyed image cache and lets a re-rendered file actually appear; rewriting the
same path without that restart shows the stale image.

**The boot splash (Plymouth) and the real login screen (SDDM) are a separate
step from `omarchy theme set`**, and not run by `apply.sh`'s main flow:
`omarchy plymouth set by theme <name>` (needs sudo). (`apply.sh` does have one
sudo step of its own now — installing the Chromium managed-policy file, see
below — but it stays a single, narrowly-scoped `install`, not a reason to run
the whole script as root.) It reads
`background`/`foreground` straight from that theme's `colors.toml` and installs
the theme's `unlock.png` as the logo on *both* Plymouth and
`/usr/share/sddm/themes/omarchy`, auto-recolouring the shared
bullet/entry/lock/progress-bar glyphs to `foreground` via ImageMagick
`+level-colors` — only `unlock.png` itself needs authoring per theme.
`unlock.png` is the ~800×188 alpha-transparent "OMARCHY" wordmark every stock
theme ships. Stock themes tint the whole wordmark to one flat colour; ours is
instead a fixed multi-colour (one hue per letter) mark, hand-tuned per theme
rather than auto-generated from a single hex -- the two `unlock.png`s are
close but not pixel-identical (the light theme nudges a couple of letters for
contrast against a white background). `preview-unlock.png` (1920×1080) is a
rendered mockup of that boot/login screen, shown by `omarchy plymouth switcher`'s
picker — generate it with `omarchy plymouth preview <bg-hex> <text-hex>
<unlock.png> <output-path>`, no sudo needed. `preview.png` is unrelated: the
desktop-screenshot thumbnail for Omarchy's *main* theme picker.

**`unlock.svg` is a companion, not an input.** Omarchy's Plymouth/SDDM pipeline
only ever reads the PNG, so the SVG is purely a checked-in editable source.
Built with a small local script (not committed -- one-off) that reads
`magick unlock.png txt:-`, run-length-encodes each row into segments by exact
`(r,g,b,a)`, and merges vertically identical rows into one `<rect>` -- an exact
pixel trace (rsvg-convert round-trip back to PNG differs from the source by
~2 of 150,400 pixels, all sub-1% opacity rounding), not a smoothed
potrace-style vectorisation, which would round the deliberately blocky
pixel-art corners and collapse the per-letter colour boundaries. Regenerate it
whenever `unlock.png` changes -- it does not stay in sync on its own, same as
`colors.svg` below.

**`colors.svg` is likewise a generated companion, not an input** -- nothing in
Omarchy or this repo reads it. A one-off script parses `colors.toml`'s
`key = "value"` lines (grouping into Core / Backgrounds / Foregrounds / System
Hues (aqua + darkAqua rows) / Hyprland Borders by a hardcoded key list, so a
future new key silently has nowhere to land -- extend the list if one is
added), renders one swatch per key plus its hex, and special-cases the two
`hyprland_*_border` values: `rgba(RRGGBBAA)` decodes to hex + an alpha
percentage noted next to the swatch, and `hyprland_active_border`'s two-stop
`45deg` spec becomes an actual SVG `linearGradient`. It is a snapshot, not
live: re-run the script after hand-editing a `colors.toml` or it goes stale.

**Shell surfaces** read `shell.<section>.toml`, spliced in by
`omarchy-theme-set-templates`, which **replaces the whole section** — any key you
omit falls back to the `Color.qml` default, not the generated value. That is why
each file restates its full section. In those files `background` / `border` /
`scrim` accept role-name tokens (resolved via `composed()` → `flatColor()`), but
`text`, `active`, `selected-text` and `countdown` are read with a plain `pick()`
that never unwraps a role name — those **must be literal hex** or they render
black.

**Hooks are run with `bash "$hook"`, and Omarchy owns the directories they live
in.** `omarchy-hook <name>` runs `~/.config/omarchy/hooks/<name>` then every file
in `<name>.d/`, skipping `*.sample`, each as `bash "$hook"` — so a hook is
executed as a **bash script regardless of its shebang or execute bit**, and a
Python or other-language hook silently fails. Symlinks are fine (`-f` follows
them), which is what lets a hook's content live in this repo. A failing hook
prints `Hook failed:` and does not abort the theme-set.

The directories themselves are Omarchy's: it ships `config/omarchy/hooks/*.d/`
with `.sample` files, so `~/.config/omarchy/{hooks,themes,plugins}/` is
territory it manages and repopulates. Everything else this repo installs
(`~/.icons/`, `~/.local/`, `~/.config/hypr/`) is ours alone and nothing in
Omarchy touches it. That asymmetry is why `apply.sh` step 7f2 exists: a hook in
`post-update.d/` re-links the exposed symlinks once per update, since
`omarchy-update` calls `omarchy-hook post-update` at line 49. `omarchy-refresh-config`
is not a threat — it copies a single *named* file and backs the old one up, so
it cannot wipe a directory.

**A plugin in `~/.config/omarchy/plugins/` is installed, not enabled.** Omarchy
enables one from the `plugins[]` array in `~/.config/omarchy/shell.json`, keyed
by the `manifest.json` `id` — the folder name is cosmetic. Dropping a plugin
folder in place and getting nothing is the expected outcome, with no error to
say so; `apply.sh` step 7h writes the `cllpse.window-switcher` entry for exactly
this reason.

`plugins[]` is only half the story, and the two halves are keyed the other way
round. A **bar widget** has no entry there at all — it is enabled by appearing
in `bar.layout`, and disabled by being removed from it, which is why a
widget-kind plugin can run with `plugins[]` holding nothing but the switcher.
**First-party non-widget** plugins (clipboard, emojis, reminders, the
speedtests, wifiqr — panels and services) are the inverse again: they load by
default and are turned off by being *listed* in `disabledPlugins[]`
(`PluginRegistry.qml:148-165`, and the key is deleted rather than left empty at
length 0). A third-party plugin, of any kind, is enabled iff its id appears
somewhere in the file — so dropping its widget from `bar.layout` is the whole
uninstall as far as the shell is concerned, and only the directory is left.

The file is still machine-level, so touch it with targeted `jq` key writes,
never a whole-file copy or a deep merge (`plugins[]` is an array, and a merge
replaces arrays rather than appending). `apply.sh` step 7h now owns five keys —
`plugins[]`, `bar.transparent`, `bar.layout`, `bar.centerAnchor`,
`disabledPlugins` — and still leaves `idle`, `version` and other plugins' widget
config alone. The tray's `pinned`/`hidden` arrays are the one thing inside
`bar.layout` that stays the machine's: they name tray items that exist on this
box, so the write carries the live ones over onto our tray entry instead of
replacing them. `bar.centerAnchor` names the one center widget pinned to the
true screen centre; when it names a widget the layout doesn't contain,
`Bar.qml`'s `hasAnchor` is false and the center section simply centres as a
block (`Bar.qml:1538`) — inert, not broken.

**Omarchy opts its shell surfaces out of the layer fade by name, and a later
rule can opt them back in.** Hyprland animates a layer surface on map —
`layersIn` is `style=fade` (~130ms at our 3x speeds) — and
`default/hypr/apps/omarchy-shell.lua` turns that off with `no_anim = true,
animation = "none"`: line 5 for `omarchy-bar`, line 10 for a literal
`^(omarchy-menu|omarchy-image-selector|omarchy-emojis|omarchy-clipboard|omarchy-keyboard-panel)$`.
A third-party namespace cannot join that alternation, so **any new shell surface
fades unless it ships its own rule** — which cuts both ways, and left the panels
snapping while notifications/OSD/polkit/reminders (never opted out) faded.

**Layer rules accumulate and the last match wins**, and user hypr files load
after the defaults, so `no_anim = false, animation = "fade"` in
`overrides/hypr/looknfeel-decoration.lua` re-enables it without touching
Omarchy's file. Verified by burst-screenshotting the menu's scrim as it opens:
one hard step before, a ~130ms ramp after. Two limits worth knowing: the
compositor **cannot fade a scrim separately from its card** (they are one layer
surface — fade-or-not is the whole per-surface control), and **duration is
`layersIn`'s speed**, shared by every animated layer, with no per-rule override.
Anything finer has to be a QML `opacity` animation inside the surface itself --
which is what the switcher does (scrim `Rectangle`, 120ms `Easing.OutCubic`,
with `no_anim` kept on its namespace so the two do not stack). Omarchy's own
panels cannot: their scrim is in `Menu.qml`, and that is a `/usr/share/omarchy`
patch the next update overwrites.

**The layer fade's duration did not respond to any animation leaf tried.**
`layersIn` at 1.33 vs 4.0 (through the file, with a real `hyprctl reload`, not
just a runtime dispatch) both measured ~90-110ms, as did `fade` at 1.01 vs 3.0.
The rule toggles the fade on and off cleanly -- with it, a smooth ramp
`321 -> 278 -> 225 -> 184 -> 152 -> 143`; with `no_anim`, `321 -> 143` in one
step -- but the ~100ms duration behaved as fixed. Don't promise a tuned layer
fade duration without re-measuring.

**Measure a fade against a STATIC patch of screen.** Several trajectories here
were first taken over a playing video, which produced convincing "ramps" that
were the video, not the animation -- and a patch whose backdrop happens to match
the scrim colour shows no signal at all. Verify the region is static (two
identical samples seconds apart) and far from the surface's own colour before
trusting any number from it.

Blur and animation are separate rules: matching the namespace for blur says
nothing about the fade.

**`Quickshell.Hyprland`'s toplevel list is half live, half snapshot, and the
seams are silent.** `Hyprland.toplevels` is what a window switcher wants instead
of spawning `hyprctl clients -j`, but four of its properties behave differently
and none of them error when misused:

- `Hyprland.rawEvent` and `toplevel.activated` are **live** — events arrive as
  they happen, and `activated` tracks focus with no refresh.
- `toplevel.lastIpcObject` is a **snapshot**. It carries the whole `hyprctl
  clients` object, but only as of the last `refreshToplevels()` — measured, its
  `focusHistoryID` stayed `2/1/0` across two focus changes. Use `activated` for
  "what is focused", never `focusHistoryID`.
- `refreshToplevels()` rewrites each `lastIpcObject` **in place**, leaving the
  values array untouched, so **`valuesChanged` never fires for a refresh**. Any
  rebuild that depends on refreshed fields has to be scheduled by hand.
- The list is populated **lazily**: empty in a bare `qs` instance until
  something refreshes it, yet already populated by the time a plugin's
  `Component.onCompleted` runs inside the Omarchy shell (Omarchy itself only
  uses `ToplevelManager` from `Quickshell.Wayland`, never this). Prime with a
  refresh *and* a direct rebuild — waiting on `valuesChanged` alone deadlocks
  the already-populated case, and the list stays empty forever with no error.

Nor does it offer a usable **focus history**: `activated` says only what is
focused now, and `focusHistoryID` is part of the stale snapshot. A switcher that
wants Alt+Tab's back-and-forth has to keep its own previous-focus address, fed
from `Hyprland.activeToplevel` and shifted only when the address actually
changes — otherwise committing to the window you are already on erases the one
you meant to return to.

Addresses also differ by source: `lastIpcObject.address` carries an `0x` prefix,
the toplevel handle's `address` does not. Compared raw they never match.

**Assigning a QML `ListView` model that is equal to the one it already has is
not free.** It resets the view and churns delegates, and a rebuilt delegate's
`Image` starts at `Loading` — so anything that falls back while an image loads
(our switcher falls back to a Nerd Font glyph) flashes on every open. Diff before
assigning. That is necessary but **not sufficient**: a cell sitting a fraction of
a pixel outside the viewport is culled and rebuilt independently of the model, so
a short list also wants `cacheBuffer` covering its whole content. Both were live
here, and each hid the other.

**A Hyprland mouse bind beats a layer surface's input region.** Hyprland
resolves `mouse:272`/`mouse:273` binds before delivering the button to whatever
surface is under the cursor, so a Quickshell overlay cannot receive a click that
carries a bound modifier no matter how it is masked -- measured: `SUPER +
left-click` on the window switcher's card started a window drag (Omarchy binds
it to "Move window", `default/hypr/bindings/tiling.lua:70`) and the plugin's
`MouseArea` never fired. `mask: Region { item: ... }` is still the right way to
make a full-screen overlay clickable at all (an empty `Region {}` is
click-through by design, an absent one eats the whole desktop), but for a
modifier-bearing click the *bind* has to be taught about the surface -- ours
dispatches `commit` while the strip is up and the stock drag otherwise.

**`qs ipc` costs a Quickshell startup, so it is not a keypress-rate channel.**
`omarchy-shell shell summon ...` is bash -> `timeout` -> `qs ipc`, and `qs ipc`
launches a whole Quickshell binary to deliver one message: measured 31-35ms per
call here, spiking to 130-166ms. The bash wrapper is free; `qs` is the cost.
Anything bound to a key that fires repeatedly should not go through it.

The spawn-free channel is **Hyprland's global-shortcuts protocol**. A Quickshell
plugin registers `GlobalShortcut { appid; name }` (Quickshell.Hyprland), and the
config binds it with `hl.dsp.global("<appid>:<name>")` -- Hyprland parses that
single string, so keep the appid free of dots and colons. `hyprctl
globalshortcuts` lists what is registered. Measured on the window switcher,
summon-to-mapped went 39-40ms -> 9-10ms (and ~half of what remains is `hyprctl`
in the harness, which a real keypress never pays). Crucially `hl.dsp.global` is
an ordinary *dispatcher*, so Lua config code can fire it too -- which is how the
switcher's key-release poll commits without shelling out.

`hl.dsp` is worth enumerating rather than guessing at; it holds `global`,
`send_shortcut`, `send_key_state`, `cursor`, `submap`, `exec_raw` and more.
Nothing on disk documents it, but a Lua expression dispatched through `hyprctl`
can write the list to a file (the dispatch then errors, harmlessly, after the
side effect has run).

**A click-through layer surface gets no Qt pointer events, so hover has to be
faked -- and faking it is expensive.** With `mask: Region {}` the switcher polled
`hyprctl cursorpos -j` every 40ms: 25 process spawns a second while the strip was
up, measured at 1.0% shell CPU against 0.0% once it was gone. Masking to the card
(`mask: Region { item: card }`) gives a real input region, and `hoverEnabled`
then costs nothing. `onPositionChanged` also fires only on real movement, which
is a better version of a "has the pointer moved far enough yet" threshold.

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

`~/.config/hypr/looknfeel.lua` carries only our one fenced block. The inactive
border's **colour is not set there** — it comes from each theme's `colors.toml`
`hyprland_inactive_border`, baked into the generated `hyprland.lua` (both
`general.col.inactive_border` and `group.col.border_inactive`). A hand-written
Lua block re-deriving it from `muted` at a different alpha lived in this file for
a while and was deleted as redundant; the alpha it existed for now sits in
`colors.toml` directly, where `muted` already is. Don't re-add it — but do
re-sync the two by hand if `muted` changes, since nothing links them.

**Per-app environment belongs in `environment.d`, not a wrapper.** The session is
started by uwsm through systemd, which imports `~/.config/environment.d/*.conf`
(verified: `FREETYPE_PROPERTIES` and `SSH_AUTH_SOCK` from existing drop-ins are
live in `systemctl --user show-environment`). A wrapper placed inside an
application directory — an AppImage's `AppRun`, say — is silently deleted by the
app's next self-update, and the behaviour reverts with no visible cause. A
drop-in is out of reach of that. Applies from the next login.

Figma Desktop is the live example: its bundled launcher defaults to X11 and
passes `--ozone-platform=x11` explicitly, overriding Omarchy's global
`ELECTRON_OZONE_PLATFORM_HINT=wayland`, and under XWayland with
`force_zero_scaling` it renders at 1/monitor-scale (80% at 1.25).
`FIGMA_USE_WAYLAND=1` is the launcher's own opt-in.

**Chromium's context menu has no per-item removal mechanism, and a bare
Preferences edit doesn't reach it either** — only `/etc/chromium/policies/
managed/*.json` does. Spellcheck, translate, password-save prompt, address/card
autofill, Print, Cast, "Create QR Code" and "Add to reading
list" are all off via `overrides/chromium/policies-managed.json`, installed by
`apply.sh`'s last step (9) with `sudo install`, the one sudo step in the whole
script — deliberately last, so the single password prompt comes after every
other change has landed.
**DevTools is deliberately not in that list.** `DeveloperToolsAvailability: 2`
was, originally, and it is the one key whose blast radius went past the menu —
it blocks Inspect *everywhere*, local dev servers included. It is now absent
rather than set to `1`, so Chromium's own default applies (`0`: available except
on force-installed extensions), on the principle that a managed policy should
only assert what we have an opinion about. "Inspect" is back in the context menu
as a consequence; no lever separates the entry from the feature.

Step 9 only writes if `/etc/chromium/policies/managed/` already exists,
matching `omarchy-theme-set-browser-policy`'s own guard verbatim (never hand a
browser a managed-policy root it doesn't otherwise have), and leaves the file
root:root — required, since a one-time Omarchy migration purges anything in
that directory *not* owned by root. No relaunch needed: on every `omarchy theme
set`, `omarchy-theme-set-browser` calls `chromium --refresh-platform-policy
--no-startup-window` whenever Chromium is running — the same live reload it
uses to push its own `color.json` (`BrowserThemeColor`) — which reloads the
whole managed directory, ours included.

An earlier version put the first five (spellcheck/translate/password/autofill)
in `Preferences` instead, alongside `default-zoom.py`'s zoom key, on the theory
that they were plain Settings-page toggles. Two problems killed that: a bare
pref only changes the *default* a user starts from, so Settings still showed
each toggle as editable — the enterprise policy is what actually greys it out
— and, for translate specifically, Chrome's own docs say the manual
"Translate to…" context-menu entry is suppressed by the `TranslateEnabled`
*policy*, not by the `translate.enabled` *pref* (which only stops the
automatic offer). Confirmed live: the pref round-tripped correctly and the
menu item was still there. See the **traps already hit** entry below for the
second, independent bug that version also had.

Neither mechanism can touch Back/Forward/Reload or any other item baked into
Chromium's C++ menu-building code — those have no config surface at all, flag
or policy, short of patching and building Chromium yourself. Chromium also has
no `chrome://flags` equivalent for the nine items above: flags exist for
features still being rolled out, and all nine graduated to stable years ago, so
any flag that once gated them was removed on graduation.

**`revert.sh` only undoes.** It never picks a font or theme. `apply.sh` records
the pre-existing font and theme once, into `~/.local/state/cllpse-macos/`,
refusing to record values that are already ours; revert restores those, or falls
back to deleting the generated `fonts.conf`.

**Cursor `settings.json` is merged, not copied.** `apply.sh` step 7 deep-merges
`overrides/cursor/settings.json` into `~/.config/Cursor/User/settings.json` with
`jq '.[0] * .[1]'` — our keys win, every other key the user or Omarchy set stays.
It skips (never truncates) if the live file has JSONC comments `jq` rejects, and
`backup`/`restore` handle the `.pre-cllpse` round-trip. **Our file must not carry
`workbench.colorTheme`** — `omarchy-theme-set-vscode` rewrites that to `"Omarchy"`
on every `omarchy theme set` (it also installs the generated `omarchy-theme`
VS Code extension into `~/.cursor/extensions`), so a competing value just loses
the race on the next theme switch.

**The Bearded theme sidesteps that race rather than fighting it.** With
`window.autoDetectColorScheme = true`, Cursor ignores `workbench.colorTheme`
entirely and reads `workbench.preferredLightColorTheme` /
`preferredDarkColorTheme`, choosing between them from the OS colour scheme —
which is `gsettings color-scheme`, which the theme's `mode` key already drives.
So the Cursor theme follows `omarchy theme set` through the same signal that
flips GTK and `prefers-color-scheme`, with no hook and no key for Omarchy to
overwrite. `autoDetectColorScheme` is the load-bearing part: drop it and the two
`preferred*` keys go inert and `colorTheme` takes over again, losing to Omarchy
on the next switch. The variants (`Bearded Theme Vivid Light`,
`Bearded Theme Black & Gold Soft`) were picked by measuring against the themes'
own backgrounds — Black & Gold Soft's `#221F1D` is ΔE 2.2 from `#1E1E1E` and the
only near-neutral dark in the set (chroma 2.1 against the palette's 0), the rest
carrying a visible blue cast.

**Bearded's window chrome is overridden back to Omarchy's.** Bearded steps the
frame through greys (light variant: titleBar `#d2d2d2`, activityBar/sideBar
`#ebebeb`, statusBar `#f4f4f4`) while every other window on this desktop sits on
the theme's flat window background, so the editor reads as a foreign window.
`hooks/theme-set.d/cursor-chrome.sh` copies the 115 chrome keys out of Omarchy's
own generated `~/.local/state/omarchy/current/theme/vscode-theme.json` (664 keys,
rebuilt from `colors.toml` on every theme-set) into
`workbench.colorCustomizations`, which sits **above** the active theme and is the
only lever that reaches this short of forking Bearded. Taking the values from
Omarchy's generated file rather than re-deriving them from `colors.toml` means
there is no second derivation to drift. Chrome, plus two whole keys in `$EXACT`:
`editor.background` and `editorGutter.background`, so the editor pane *is* the
window colour instead of a `#f4f4f4` panel sitting inside a `#FFFFFF` window.
The gutter must come along — Bearded sets it explicitly to the same grey — while
`editorPane`, `editorGroup.emptyBackground` and `editorStickyScroll` need no
entry, since Bearded leaves them unset and VS Code derives them from
`editor.background` (checked). Widgets, lists, terminal and all syntax stay
Bearded; widening further is a matter of adding prefixes to `$CHROME` or names to
`$EXACT`, since the whole `colors` object is there. The two scopes
are read from `preferredLight/DarkColorTheme` rather than hardcoded, so the
variant names live in one place. Both scopes get the current palette, which is
always correct: only one is ever active, and it matches the mode that selected
it. A `$FORCE` map is applied on top of the copy for keys where Omarchy's own value
isn't wanted: `tab.activeBorderTop` (the accent line above the active tab), its
unfocused twin, and `tab.hoverBorder` (the line under a tab while the pointer is
over it) are set to `#00000000`. `tab.unfocusedHoverBorder` needs no entry — VS
Code derives it from `tab.hoverBorder`, and neither theme sets it explicitly. The bottom border is
deliberately **shared** between the selected and hovered states: Omarchy gives
them different values (`tab.activeBorder` the full accent, `tab.hoverBorder` a
25%-alpha wash of it), so a tab's bottom edge changed weight depending on which
state it was in. The hook assigns one from the other — derived, not pinned, so it
tracks the theme's accent — and `tab.unfocusedHoverBorder` follows for free, since
Cursor's registry defines it as an alpha of `tab.hoverBorder`. Transparent rather than *deleted* —
`colorCustomizations` only overrides what it names, so dropping a key hands that
slot back to Bearded instead of clearing it. VS Code reads 8-digit `#RRGGBBAA`,
which Omarchy's own generated file already relies on for its `#007AFF20` washes.

One wart — changing a preferred theme leaves the previous scope orphaned in
`colorCustomizations`; it is inert unless that theme is picked again, and the
hook does not prune it because it cannot tell its own scopes from a user's.

This is the one place the override **does** depend on marketplace extensions
(`beardedbear.beardedtheme`, `beardedbear.beardedicons`). `workbench.iconTheme`
had been deliberately stripped once before to keep that from being true; it is
back by choice. A machine without the extensions falls back to Cursor's default
theme and icons — no error, just not what the repo describes.

The file is otherwise kept to stock-Cursor keys — GitLens/Copilot keys and the
Biome / ESLint per-language formatters were all stripped — and `editor.fontWeight` is unset —
naming the SemiBold *face* in `editor.fontFamily` is how the weight is selected,
the same way `~/Sites/dotfiles/.config/ghostty/config` does it, so a separate
weight key would double up.

`editor.fontFamily` **is** set, to
`'ComicCode Nerd Font SemiBold', 'ComicCode Nerd Font', monospace`, copied from
that Ghostty config. Two things about it. The trailing generic is load-bearing:
Cursor's own default stack ends in `monospace`, which fontconfig resolves to SF
Mono (from `omarchy font set`), so a machine **without** Comic Code lands exactly
where it did before this key existed rather than on some arbitrary fallback —
which is the state of this machine, where `fc-list` finds no Comic Code at all.
The two `.otf`s **are** vendored, in `overrides/fonts/comic-code/`, and
installed by `apply.sh` to `~/.local/share/fonts/ComicCode/` - a subdirectory
because the SF step globs `fonts/*.otf` into `~/.local/share/fonts/SF/` and
these are not SF. Comic Code is commercial and this repo has a public remote, so
it is listed in THIRD-PARTY.md alongside the Apple faces.
Omarchy never writes a font key into Cursor — `omarchy-theme-set-vscode` only
touches `colorTheme` — so nothing competes for it.

**`fc-match` is not a usable probe on this machine - it reports SF for
everything.** Checked: `fc-match "JetBrainsMono Nerd Font"` returns *SF Mono*,
for a font that is installed and working. The strong-binding prepends in
`99-cllpse-macos-ui-font.conf` and Omarchy's `50-omarchy.conf` put an SF face in
front of every pattern, so first place is SF whatever you ask for. Use
`fc-list :family="..."` to answer "is it installed", or `fc-match -s` and look
at rank 2, which is where the family you actually asked for shows up.

Ghostty's `font-thicken` / `font-thicken-strength` have **no** Cursor
counterpart, and neither does the `environment.d` stem darkening: Cursor is
Electron, so it inherits Chromium's ignoring of `FREETYPE_PROPERTIES` (see the
Chromium entry under *traps*). Comic Code will render thinner in Cursor than in
Ghostty for exactly that reason, and no setting closes the gap.
`editor.fontSize` (15) stays: it is a user preference with no Omarchy equivalent.
Only Cursor is handled; VS Code / VSCodium would each need their own merge.

**Merge into a running Cursor doesn't reliably stick.** Cursor rewrites the whole
`settings.json` from its in-memory model whenever a setting changes through the
UI, so a `jq` merge run while Cursor is open survives only until the next
in-app toggle, which reverts any key that differed from what Cursor had loaded
(`window.menuBarVisibility` was lost exactly this way). Run `apply.sh` with Cursor
closed for the merge to hold — same failure shape as the Chromium `Preferences`
trap. Panel/UI state that has no settings key (sidebar/panel open-closed, the
`cursor/unifiedAppLayout` IDE-vs-agent mode) lives in
`~/.config/Cursor/User/globalStorage/state.vscdb` and can't go in the override at
all; only the settings-backed toggles (`workbench.statusBar.visible`,
`workbench.layoutControl.enabled`, `workbench.agentsWindowButton.enabled`,
`workbench.activityBar.location`, …) can.

**Window frames are all client-side — Hyprland draws none.** No window on
Hyprland gets a compositor titlebar, only the 2px `decoration:border_size`; every
min/max/close is the app's own CSD, so each toolkit is a separate lever:
- **GTK / libadwaita** (Nautilus, the GNOME apps) — `gsettings
  org.gnome.desktop.wm.preferences button-layout`. `apply.sh` step 5b sets `':'`
  (nothing); Omarchy's default is `'appmenu:close'`. Global to every GTK app.
- **Cursor** (Electron) — `window.titleBarStyle: "custom"` +
  `window.menuBarVisibility: "hidden"` + `window.controlsStyle: "hidden"` in the
  override leave a bare drag strip. `controlsStyle` is Linux/Windows-only
  (`included:!isMacintosh`); this build has no key to remove the strip itself.
- **Figma Desktop** (`figma-linux` AppImage, Electron, forced to native Wayland
  by `~/Applications/figma-desktop/AppRun` + the `FIGMA_USE_WAYLAND=1` drop-in) —
  draws its own top panel (`panelHeight` in `~/.config/figma-linux/settings.json`)
  and exposes no frame or menu toggle. Nothing to script.

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
- **`hyprctl keyword` and `hyprctl dispatch` are both Lua-only now, and the
  failure looks like the setting simply didn't take.** `keyword` prints
  `keyword can't work with non-legacy parsers. Use eval.` on stderr and changes
  nothing, so a script that sets a value and reads it back gets the *old* one
  and reads as "this option has no effect". `dispatch` takes Lua too —
  `hyprctl dispatch focuswindow address:0x…` is a syntax error, not a
  dispatch. Live equivalents are `hyprctl eval 'hl.config({ input = {
  follow_mouse = 2 } })'` and `hyprctl eval 'hl.dispatch(hl.dsp…)'`, which
  return `ok`. Cost one wrong conclusion here: a follow_mouse test "passed"
  while the option was still at its old value. `eval` also **does not echo a
  return value** — it always prints `ok` — so a probe has to write its findings
  to a file with `io.open`.
- **`hl.dsp.window.close()` takes its target as the `window` KEY, and every
  other shape fails silently.** `close({ window = w })` (or `{ window =
  "address:0x…" }`) closes that window; `close(w)`, `close(w.address)` and
  `close("address:0x…")` all build a perfectly valid `HL.Dispatcher` and then
  close **nothing**, with no error anywhere — measured against a live unfocused
  window. A positional form appears to work if you test it on the *focused*
  window, because a bare `close()` closes that one anyway; the bug only shows
  up on a window that isn't focused. An unresolvable selector is inert rather
  than falling back to the active window (checked with `address:0xdeadbeef`
  against a focused canary), which is what makes the SUPER+Q sweep in
  `overrides/hypr/macos-shortcuts.lua` safe to run as a loop. Its companion
  `hl.get_windows({ class = … })` matches the class **exactly**, not as a
  regex — `"ghost"`, `".*ghostty.*"` and `"^chromium$"` all return 0 against
  live windows — the opposite of Hyprland's window *rules*, and the safe
  direction for a bulk close.
- **A settings plugin that writes its own `looknfeel.lua`/`input.lua` block wins
  by file position** if it lands after ours. Omaland did exactly that (an
  `hl.animation` block plus global `active_opacity`/`inactive_opacity`) and left
  its block behind after being uninstalled — it was still overriding the theme
  months later. If a value here doesn't land, look for a later block before
  suspecting the value.
- **OmaSettings is the same trap one level up: a whole file, `require`d last.**
  It does not write into `looknfeel.lua`/`input.lua` at all. It generates
  `~/.config/hypr/omasettings.lua` (headed `omasettings:managed`) and appends
  `require("hypr.omasettings")` to the **end** of `~/.config/hypr/hyprland.lua`
  — after `default.hypr.omarchy` has already pulled in every user file — so it
  outranks all of our fenced blocks on every key it sets, and grepping the
  fenced files for the value finds nothing. It keeps the pre-change values in
  `~/.config/omarchy/omasettings.json` under `hyprOriginal`, and backs up what
  it edits as `*.omasettings.bak`, which is the cheapest way to see what it
  actually changed (`diff -u shell.json.omasettings.bak shell.json`). Its own
  header says a line deleted from the generated file hands that setting back —
  so folding one of its values into this repo is two moves, not one: add it to
  the override *and* delete the line there, or the repo's copy is decorative.
- **Blur only shows through what a surface leaves translucent.** At
  `background-alpha` 0.92 barely 8% of the backdrop shows, so widening the blur
  radius there is close to invisible; `background-alpha` is the stronger lever.
- The repo carries ~229 MB of Apple fonts and wallpapers it does not own, on a
  public remote. See [`THIRD-PARTY.md`](THIRD-PARTY.md) before adding more.
- **`macos-*` Ghostty keys are no-ops on Linux.** `macos-titlebar-style`,
  `macos-window-buttons`, `macos-icon` and friends are read only on macOS. A
  config full of them looks configured and does nothing.
- **Hand-edited app configs replace the packaged defaults rather than extending
  them.** `~/.config/ghostty/config` had been edited in place and had quietly
  lost Omarchy's own keybinds (shift+insert, control+insert, the CSI sequences,
  the resize_split set), `gtk-toolbar-style`, `async-backend` and `ssh-env`.
  When something looks missing, diff against `/usr/share/omarchy/config/` before
  assuming it was never there. That directory is the stock copy of every user
  config Omarchy ships, and is the right base to reset to.
- **Check a setting against the program's own defaults before shipping it.**
  `ghostty +show-config --default` showed five settings in that config were
  restating defaults verbatim. Most tools have an equivalent.
- **Ghostty has no inline comments.** `#` only opens a comment at the start of a
  line, so `copy-on-select = false  # default: true` parses the entire trailing
  string as the value and Ghostty rejects the line at startup — seven keys in
  `overrides/ghostty/ghostty.conf` were silently inert this way. Put the note on
  its own line above the key, and check the result with `ghostty
  +validate-config` (exit 1 and one message per bad line; silent on success).
- **Omarchy turns off close confirmation in every terminal that has one, and it
  looks like a keybind regression.** `config/ghostty/config:13`
  `confirm-close-surface=false`, `config/kitty/kitty.conf:11`
  `confirm_os_window_close 0`, `config/herdr/config.toml:81` `confirm_close =
  false` — all stock, all inherited verbatim by the live user configs (the
  ghostty diff against stock is only `font-family`/`font-size`). So a terminal
  with a job still running closes silently no matter how the close is triggered,
  and remapping SUPER+Q to `hl.dsp.window.close()` gets blamed for it — wrongly:
  that is the *same* dispatcher Omarchy binds SUPER+W to (`tiling.lua:1`), the
  graceful xdg request an app needs in order to prompt at all. Before suspecting
  a bind, check whether the app was ever going to ask. Ghostty's is restored in
  our fenced block; a repeated key is **last-wins** (verified against a
  throwaway `XDG_CONFIG_HOME`), and the block is spliced in below line 13, so
  re-stating it there beats the stock line without editing stock. Note that
  `+show-config` prints only non-defaults, so a key restored *to* its default
  disappears from that output — absence is the success signal, not a failure.
- **A Starship `custom` module with empty output is still rendered.** Neither an
  empty string nor a non-zero exit hides it — both were measured, and both leave
  the format's literal text behind, which for a `format = "[$output]($style) "`
  is a stray space in front of the prompt character in every directory that
  isn't a repo. Starship also strips trailing whitespace from command output, so
  the space cannot be moved into the command to dodge this. The fix is the
  conditional group: `format = "([$output]($style) )"` renders only when the
  variables inside are non-empty. `overrides/starship/starship.toml.tpl`'s
  `custom.git_branch` (middle-truncation, which the built-in can't do — it
  truncates from the head) depends on this to match the built-in's own
  disappear-outside-a-repo behaviour.
- **Chromium ignores `FREETYPE_PROPERTIES`.** The stem darkening in
  `overrides/environment.d/10-cllpse-macos-font-rendering.conf` reaches every
  app on the desktop *except* Chromium, so page text there renders at the thin
  weight the SF faces are drawn at. Measured: identical output with darkening
  off, on and strong, while the same value through system FreeType (ImageMagick,
  same `.otf`) adds 24% ink. Fontconfig `embolden` is ignored too; hinting is
  the only render param Chromium honours, and it is already at `hintnone`. No
  flag fixes this — `--text-contrast` and `--text-gamma` exist in the binary but
  are inert, and `--font-render-hinting` is Electron's, not Chromium's. The only
  working lever is CSS (`-webkit-text-stroke: .2px` ≈ +21% ink, against
  FreeType's +24%), which needs a content-script extension since Chromium
  dropped user stylesheets.
- **Chromium's `Preferences` JSON nests dotted pref names — a flat key with a
  literal dot in it is never read.** `translate.enabled` is stored on disk as
  `{"translate": {"enabled": ...}}`, not as a top-level key literally named
  `"translate.enabled"`. A script that does `data["translate.enabled"] = False`
  and `json.dump`s the result writes a real key, just one Chromium's
  `JsonPrefStore` never looks at — the actual nested value is untouched and
  stays at whatever it already was. Caught by reading a live profile's
  `Preferences` and finding both the bogus flat key and the real nested dict
  sitting side by side. Any dotted Chromium pref name being hand-written into a
  JSON file needs the nested form, or needs Chromium itself (via Settings) to
  do the write.
- **`sourceSize` means two different things, by format.** On a raster `Image`
  it picks the *decode* resolution, so leaving it unset just uses the file's own
  and costs nothing. On a **vector** it picks the *rasterisation* resolution,
  and leaving it unset makes Qt rasterise at the SVG's intrinsic size — 24x24
  for simple-icons, 16x16 for freedesktop symbolic — which is then scaled up to
  the drawn size and looks exactly as bad as it sounds. Omarchy's own
  `Menu.qml` sets it; our switcher did not, which is why the menu looked right
  while the same files were soft under SUPER+TAB. A conclusion measured on a
  PNG does not carry over to an SVG.
- **Recolouring arbitrary SVGs with regex has three failure modes, all found in
  practice.** `app-icons.sh` repaints drop-ins to the theme colour, and every
  one of these produced a silently wrong or corrupt file before it was fixed:
  - *Single-quoted attributes.* Inkscape writes `fill='#808080'` throughout.
    A rule written only for double quotes leaves the file untouched and it
    renders in its original colour, which on a matching theme looks like the
    icon simply vanished. Three of the fifteen symbolic icons on this machine
    are single-quoted.
  - *Character classes that do not stop at `}` or `<`.* A CSS block reads
    `.st0{fill:#0acf83}.st1{fill:#a259ff}`, and `fill:[^;"']*` runs from the
    first `fill:` through every rule after it and on into the next tag,
    producing `fill:#DDDDDD"path0_fill"` and an unparseable document. Exclude
    `}` and `<` as well as the quotes.
  - *Files with no paint at all.* simple-icons ships a bare `<path d="…"/>`;
    there is nothing to rewrite and SVG's default fill is black, so the icon is
    invisible on a dark theme. The root needs a fill injected — but only when it
    has none, or the duplicate attribute breaks the XML.
- **`Screen.devicePixelRatio` (2) is NOT the same number as the output scale
  (1.25), and the 2 is the one an `Image` decode wants.** An earlier version of
  this entry said the opposite — that the screen's ratio over-decodes and a
  decode should be sized from the window's real ratio instead. Measured from
  inside a live Quickshell `PanelWindow`, that is wrong:

  | | value |
  |---|---|
  | `hyprctl monitors` scale (DP-2) | 1.25 |
  | `Screen.devicePixelRatio` | 2 |
  | `Window.window.devicePixelRatio` | 2 |

  The two Qt numbers agree, so there is no "window ratio" that exposes the
  1.25. What happens is that Qt takes the next **integer** buffer scale (2),
  renders the whole surface at 2×, and the **compositor** scales that finished
  buffer down to 1.25×. So 2 is the resolution Qt genuinely rasterises into,
  and `sourceSize = drawn × Screen.devicePixelRatio` is right — which is also
  what Omarchy's own `Menu.qml`, `Tray.qml` and `NotificationCard.qml` do.
  Sizing a decode from 1.25 would hand Qt a 45px image for a region it draws at
  72px, i.e. upscaling. The compositor's final downscale is whole-surface and
  applies to text and every other primitive equally; no per-`Image` `sourceSize`
  can pre-compensate for it, and trying is a pessimisation.

  `Window.window.devicePixelRatio` does exist and is worth knowing about — Qt
  **6.11+** only (`qquickwindow.h` `REVISION(6, 11)`; 4.0.2 ships 6.11.2), reads
  `effectiveDevicePixelRatio`, carries a NOTIFY so bindings track a monitor
  change, and needs no import beyond `QtQuick`. It simply reports the same 2
  here. Re-measure with a `PanelWindow` probe before trusting either number on
  different hardware; don't re-derive this one from the output scale.

  **`grabToImage` cannot be used to observe the 1.25.** An earlier note cited it
  as proof of the "true window ratio". It renders at the window's
  `devicePixelRatio`, full stop — measured by grabbing a 40×40 item under a
  forced `QT_SCALE_FACTOR`:

  | dpr | grabbed PNG |
  |---|---|
  | 1 | 40×40 |
  | 2 | 80×80 |
  | 3 | 120×120 |

  So on this machine a grab comes back at 2×, the same number `Screen` reports.
  The compositor's downscale to 1.25 happens *after* the buffer leaves Qt, so
  nothing inside the process — `grabToImage` included — can see it. To measure
  what actually lands on the glass, screenshot the compositor's output
  (`grim`), not the item.

  Note also that `Window` is an attached property of an **Item**: reading
  `Window.window` from a `Timer` or other non-Item throws, and in a
  `console.log` argument that means the whole line silently prints nothing.
- **An icon drawn from a file will not match a glyph beside it at the same
  nominal size.** A text glyph at `pixelSize` N fills close to N; a PNG whose
  mark sits in 200 of 256 px fills 78% of whatever box it is given. Matching the
  *canvas* leaves the image looking small and softer than its neighbours —
  match the **ink** instead (scale the box by the padding ratio). Measured in
  the switcher: 27px of ink versus a glyph's 33, fixed by an `iconSize * 256/200`
  box.
- **`String.fromCharCode` is 16-bit and silently truncates.** The switcher's
  `glyphFor` builds its glyph from a hex codepoint, which was fine while every
  entry sat in the Font Awesome PUA (≤ U+FFFF), but the Material Design range
  breaks it: `fromCharCode(0xf0219)` yields U+219 and `fromCharCode(0xf082e)`
  yields U+82E — real characters, so they render as unrelated glyphs with no
  error anywhere. Use `String.fromCodePoint`.
- **Verify Nerd Font codepoints against the face that will actually render
  them.** The shell's menu surfaces use `Style.font.menuFamily`
  (`OMARCHY_MENU_FONT`, `SFProText Nerd Font Propo` here), not the monospace
  face. `fc-list ":charset=<hex>" family` is the check; a glyph present in SF
  Mono is not necessarily present in SF Pro Text.
- **ImageMagick's `-extent` pads with the *background* colour, which defaults to
  white.** A pipeline that correctly produces a transparent-background icon and
  then centres it on a fixed canvas silently gains an opaque white box unless
  `-background none` is repeated before `-extent` — setting it once at the head
  of the command is not enough, because `-trim`/`-resize` reset nothing but the
  geometry. Cost an hour of chasing a "broken" alpha channel that was fine.
- **Bash `printf` parses `\u` out of the *format string* before `%x`
  substitution.** `printf "\\u%04x" 0xf268` is not "render codepoint F268", it is
  the error `missing unicode digit for \u`. Build the escape as data and expand
  it with `%b`: `printf '%b' "\\u$hex"`. The failure is quiet in a loop — every
  glyph renders as an empty label, so you get 42 blank PNGs and no error unless
  stderr is being read.
- **ImageMagick stamps PNG `date:create`/`date:modify` chunks**, so two runs of
  an otherwise deterministic pipeline produce different bytes for pixel-identical
  output (`compare -metric AE` reports 0). `-strip` before the output filename is
  what makes a generator idempotent.
- **`pgrep -f` matches whole command lines, including the caller's.** A guard
  written as `pgrep -f /usr/lib/chromium/chromium` matched the shell running the
  script that contained the string, so `default-zoom.py` refused every write
  while Chromium was closed — and failed quietly, printing a plausible "quit it
  and re-run" and returning success. Resolve `/proc/<pid>/exe` to test for a
  running binary. Suspect any guard in this repo that greps for a path.

## Reproducing this on another machine

`apply.sh` is deterministic and idempotent for what it controls, but it is not a
full machine build — it installs no packages (no sudo), no third-party plugins,
and `display.conf` carries values tuned for one specific display. Several
settings only take effect after a relogin. `overrides/README.md` has the full
list under *What apply.sh does and does not guarantee*; read it before assuming a
clean install ended up identical.

## Still open

- `revert.sh`'s restore paths have unit-tested helpers but have never been run
  end-to-end; that needs a spare machine or VM, not this one.
