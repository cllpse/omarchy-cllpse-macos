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
  base-size` (currently **13**, via `omarchy display text size`; `display.conf`
  records it for `apply.sh` to restore). That file is **watched live** —
  `Color.qml:242-251` holds a `FileView` on the user copy with
  `watchChanges: true` and `onFileChanged: reload()`, so a size change reaches
  the running shell with no restart and no theme-set. The *theme's* copy at
  `currentThemePath + "/shell.toml"` is `watchChanges: false`, so those still
  need a theme-set to publish. The theme must not
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

The switcher's *label* closed that gap rather than widening it. `nameFor` used
to be a curated class→name chain ending in a title-cased class, which is a
second list to keep in step with the launcher by hand — and it drifted: the
launcher read `Name=Figma Desktop` off the desktop entry while the chain
answered `Figma`. It now falls through to that same `Name=` (through the
existing `classIndex`, which already carried it for `iconFor`) before the
title-case fallback, so the two surfaces agree by construction. The curated
chain stays **ahead** of the lookup and is now only for names we deliberately
disagree with the entry about — measured across every class in it, that is
exactly three on this machine: Figma (fixed by deleting its line), `mpv`, whose
entry says "Media Player", and `qv4l2`, whose entry says "Qt V4L2 test
Utility". Everything else either agrees already or joins to no entry at all.
The lookup is only as good as the entry's `StartupWMClass`, which is why the
correction above is load-bearing rather than cosmetic.

Since app icons are never recoloured, a file dropped there has a **fixed**
colour and would not survive a light/dark switch — which is why the rendering is
a `theme-set` hook (`hooks/theme-set.d/app-icons.sh`), not a one-off in
`apply.sh`.

**`omarchy theme set` does NOT restart the shell** — an earlier version of this
file said it did, and four comments in the repo were written on that basis.
Measured: the `quickshell` pid is unchanged across a theme set. What it actually
does is push the new palette into the running process over IPC
(`omarchy-theme-set:112/308`, `shell_ipc shell applyTheme`) and restart the
terminal, hyprctl, btop, opencode and helix (319-323) — never the shell.

That matters for the icons and almost nothing else, because two caches survive a
palette push: the Omarchy menu draws an app icon as a plain `Image`
(`Menu.qml:1253`) with no recolouring and no `cache:` key, so Qt's **URL-keyed**
pixmap cache can keep serving the previous theme's colour from an unchanged
path; and the switcher builds its drop-in index from a single `ls` at launch, so
a newly added drop-in is not in it at all — the file is right on disk and the
tile still shows a glyph. `app-icons.sh` therefore restarts the shell itself,
from an `EXIT` trap, and only when a synced file actually changed (a re-publish
of the same theme writes identical bytes and must stay silent, or every no-op
theme-set would take the bar down).

`shell.json` is the counter-example worth knowing, so it isn't "fixed" twice:
`shell.qml:134-142` holds a `FileView` on it with `watchChanges: true` and
`onFileChanged: reload()`, so `apply.sh`'s key writes land live with no restart
involved.

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

**The installed Figma is `nickvdp/figma-desktop-linux`, not `figma-linux`.**
Two unrelated projects, and this file named the wrong one for a while.
Ours is an AppImage repack of Figma's *own* Electron build
(`~/Applications/figma-desktop-126.5.6-amd64.AppImage`, extracted to
`~/Applications/figma-desktop/`, app id
`io.github.nickvdp.figma-desktop-linux`); `figma-linux` is a community Electron
wrapper around the web app, with its own settings schema and a `ThemeCreator`.
Three names are in play and all three are load-bearing somewhere: the AppStream
`<name>` and the local `.desktop` `Name=` are **Figma Desktop** (what the
launcher shows), the bundled `.desktop` `Name=` is `Figma`, and the live
Hyprland class is `figma-desktop`. Config lives in `~/.config/Figma/` — verified
from the running process, whose crashpad db is
`~/.config/Figma/DesktopProfile/v41/Crashpad` and whose annotations read
`_productName=Figma`. `~/.config/figma-linux/` exists on this machine but is a
**leftover from the other project** (written 09:20, before this app dir was
extracted at 09:46, and carrying `figma-linux`'s schema); nothing reads it.

**Upstream's `.desktop` declares `StartupWMClass=Figma`, which matches no live
window.** The class Hyprland reports is `figma-desktop`, so every entry→window
join keyed on that declaration misses — taskbar grouping, startup notification,
and our own switcher's `classIndex`. `apply.sh` step 7e owns the entry
(`overrides/applications/figma-desktop-appimage.desktop.tpl`, `{{ home }}`
expanded at install) and corrects both that and `Name=`.

**The `Exec=` line is what keeps that file ours, and it has to be byte-exact.**
`integrate_desktop()` runs on *every launch* and rewrites the whole entry —
`Name=Figma`, `StartupWMClass=Figma` — unless the existing `Exec` already equals
`Exec="${appimage_path}" %u`. That path is `$APPIMAGE` when set, and otherwise
`readlink -f "$0"`; since this is an **extracted directory** rather than a
mounted `.AppImage`, `APPIMAGE` is unset and the path is simply
`~/Applications/figma-desktop/AppRun`. It carries no version, so the template's
Exec matches what the app would write on every release and the rewrite never
fires. Updating Figma is: extract over the app directory, re-run `apply.sh`.

**Which is why nothing wraps `AppRun` any more.** This machine ran a local
wrapper that renamed the launcher to `AppRun.real` and exported
`APPIMAGE="$here/AppRun"`. Both halves were self-inflicted: displacing the
launcher is what broke the computed path, and the export existed only to repair
it. Its other job, `FIGMA_USE_WAYLAND=1`, is step 7c's `environment.d` drop-in
— measured live in `systemctl --user show-environment`, so it reaches every
launch, and no update can touch it. A wrapper is a file **inside** the app
directory, which the next extraction deletes; going without one means nothing in
there is ours and an update has nothing to undo. `apply.sh` step 7e removes a
wrapper if it finds one, keyed on `integrate_desktop` being present in
`AppRun.real` and absent from `AppRun`, and clears a stale `AppRun.real` that a
fresh extraction left orphaned.

**keyd is the one package this repo depends on, and the only reason is Figma.**
`apply.sh` does not install it — step 8b configures it if present and says so if
not — but that still makes it the first external dependency and the second sudo
step, so the "no packages" line above is narrower than it used to be.

Why it exists: Figma tests `ctrlKey` for deep-select (Cmd+click), canvas zoom
(Cmd+scroll) and its shortcuts, and ignores `metaKey` off macOS. The forwarder
in `macos-shortcuts.lua` handles the *keys* by synthesizing Ctrl, but **`hl.dsp`
has no pointer-button or scroll-axis dispatcher** — only `cursor.move` and
`cursor.move_to_corner` — so click and scroll cannot be translated at the
compositor at all. Measured before concluding that: `SUPER + scroll` reaches a
Wayland client as `META(Super)` on **14 of 14** events, so Hyprland forwards the
modifier correctly and Figma discards it. Remapping the key *below* the
compositor is the only mechanism left.

The remap is **runtime-only and scoped by focus**. `/etc/keyd/default.conf`
remaps nothing on its own: `[main]` is empty, and the `[figma:C]` layer it
defines is inert until `~/.local/bin/cllpse-figma-keyd` issues `keyd bind
'leftmeta = layer(figma)'` when Figma takes focus, dropped again by `keyd bind
reset` when it loses it. Nothing is written to disk, and a keyd restart or a
reboot clears it. The layer has to be *defined* on disk because **`keyd bind`
can only bind to a layer, never create one** — which is also the shape of the
worst failure here, below.

**keyd re-reads that file at start or on `keyd reload`, and at no other time.**
`keyd reload` is the daemon's own command and goes over the same group-owned
socket as `keyd bind`, so it needs **no root** and does not interrupt the grab
(verified as this user: rc=0). What does not exist is `systemctl reload keyd` —
the unit is a bare `ExecStart=/usr/bin/keyd` with no `ExecReload`, so
`systemctl show keyd -p CanReload` says `no` and that request only ever fails;
`apply.sh` step 8b asks `keyd reload` first and falls back to
`sudo systemctl restart keyd` for a session that does not yet hold the group.
Either way something has to ask: editing `overrides/keyd/default.conf` reaches
the daemon at step 8b's `sudo install` + reload and nowhere else — the same
publish-step relationship `omarchy theme set` has to a theme folder. Live
example, cost half an hour: the `[figma:C]` layer was added to the repo file
while `/etc` kept the previous revision, so the focus handler's bind answered
`figma is not a valid layer` and exited 255 into `hl.dsp.exec_raw`, which
discards stderr. Nothing said so until Cmd+scroll was tried in Figma. Step 8b
now ends with a smoke test (`cllpse-figma-keyd on` then `off`) that proves
config-parsed + layer-present + socket-reachable in one call.

**`keyd check <file>` validates a config without root**, which is worth using
before anything reaches `/etc`: keyd *exits* on a parse error, and it exits
holding no device, so a bad file presents as a keyboard that has quietly stopped
being remapped rather than as an error. Step 8b gates the install on it. The
other two subcommands worth knowing are `keyd listen` (layer state changes of
the running daemon) and `keyd monitor` (live key events) — `keyd -h` lists them;
there is still no way to query the runtime binds themselves.

**No daemon.** `hl.on("window.active", …)` fires on every focus change and
`hl.get_active_window().class` identifies the app, so a state guard means a
process spawns only when the Figma boundary is actually crossed. The event's own
callback argument is **userdata, not a table** — reading `.class` off it gets
nothing, which is why the handler calls `get_active_window()` instead.

Three things that are easy to get wrong here, all handled in
`macos-shortcuts.lua`: the state must be **seeded from the current focus** at
load, because a reload builds a fresh Lua state while keyd keeps its runtime
bind and the two would silently disagree (and the converse is why `apply.sh`
reloads Hyprland *after* restarting keyd — the restart drops every runtime
bind, so a reload ahead of it left the handler believing the remap was on
against a daemon that had just reset it, until the Figma focus boundary was
crossed twice); `hyprland.shutdown` must drop the
remap, because a runtime bind outlives the compositor and would hand the next
session a meta key that types Ctrl; and `[ids]` must be pinned to
`k:03a8:a649`, because the `*` wildcard matches anything the kernel calls a
keyboard and the **Pulsar 8K dongle presents three such interfaces** — a
wildcard would route a gaming mouse's dongle through keyd for nothing.

The `vendor:product` half of that pin is doing all of the work; **the `k:`
prefix is inert here**, so don't credit it with the exclusion. keyd(1) says it
"may be used to exclusively match keyboards", but measured from
`journalctl -u keyd` — which prints one `DEVICE: match`/`ignoring` line per
device at startup and is the only place this is visible — all **five** Preonic
interfaces are grabbed, `Drop Preonic Mouse` among them. Harmless, and the
reason is worth recording so it isn't re-derived: that interface's key bitmap
is `KEY=ff0000 0 0 0 0` in `/proc/bus/input/devices`, bits 272-279, which is
exactly `BTN_LEFT` through `BTN_TASK` and not one typing key — there is no
`leftmeta` on that stream for the runtime bind to land on.

**`Command+Q` is macOS-only in Electron, so Figma registers no Quit
accelerator on Linux at all.** Read out of `app.asar`'s own menu table —
`"CommandOrControl+T":"NewTab"`, `"CommandOrControl+W":"CloseTab"`,
`"CommandOrControl+Shift+W":"Close"`, but `"Command+Q":"Quit"` — which means the
Ctrl+Q the `[figma:C]` layer used to hand it landed on nothing whatsoever. Not a
chord Figma chose to ignore: one it never had. So `q = M-q` joins `tab = M-tab`
as a carve-out and SUPER+Q reaches Hyprland, whose bind closes every window
sharing the focused class — what quitting Figma means to this compositor.

**Cmd+W is deliberately *not* carved out**, and the same file says why:
`CommandOrControl+W` → `closeActiveTab` is registered, through a menu that is
genuinely installed (`setApplicationMenu` appears nine times in the bundle), so
the plain `:C` fallthrough already delivers the exact chord Hyprland's own
SUPER+W would have synthesized. A carve-out would add a compositor round-trip
to arrive at the same Ctrl+W. Note the asymmetry this leaves: SUPER+W closes the
Figma **tab**, not the window — `closeActiveTab` on the last tab does not close
the window, and `CmdOrCtrl+Shift+W` is the entry that does.

The accepted cost: while Figma is focused Hyprland never sees SUPER, so
`SUPER + SPACE` and any other uncarved chord do nothing there. `WM_MOD` is untouched (it is
Ctrl+Alt, and only the meta key is remapped), so workspaces and window
management still work and are the way out. Corollary worth knowing: in Figma,
`SUPER + ALT` emits Ctrl+Alt and therefore fires the WM_MOD binds.


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
on the next switch. The variants (`Bearded Theme Light`,
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
`editor.background` (checked). Lists, inputs, the terminal and all syntax stay
Bearded; widening further is a matter of adding prefixes to `$CHROME` or names to
`$EXACT`, since the whole `colors` object is there.

**Anything that floats over the window is chrome too.** `quickInput`,
`pickerGroup.`, `editorHoverWidget.` and `keybindingLabel.` are in `$CHROME`
alongside the frame: the quick input (SUPER+P and SUPER+SHIFT+P are one widget),
the separator and group label inside it, both hover widgets — `.monaco-hover` in
the editor and `.workbench-hover` over tabs and the sidebar read the same
`editorHoverWidget.*` vars, so one prefix covers editor tooltips and workbench
tooltips alike — and the keybinding chips those surfaces draw. Bearded paints a
tooltip `#c9ced2` against a `#FFFFFF` window, with teal chips; Omarchy's values
are the window's own. Three neighbours are deliberately out: `list.` would
repaint every tree in the workbench for the sake of the picker's rows, and
Omarchy's `list.hoverBackground` is the window background, so taking it would
cost the hover feedback Bearded has; `input.` reaches the find widget, settings
search and SCM box for a `#f9f9fa`-vs-`#FFFFFF` difference inside one field;
`editorSuggestWidget.` is completion, which is syntax-adjacent and belongs with
what Bearded was chosen for. The two scopes
are read from `preferredLight/DarkColorTheme` rather than hardcoded, so the
variant names live in one place. Both scopes get the current palette, which is
always correct: only one is ever active, and it matches the mode that selected
it. A `$FORCE` map is applied on top of the copy for keys where Omarchy's own value
isn't wanted: `tab.activeBorderTop` (the accent line above the active tab), its
unfocused twin, and `tab.hoverBorder` (the line under a tab while the pointer is
over it) are set to `#00000000`. `tab.unfocusedHoverBorder` needs no entry — VS
Code derives it from `tab.hoverBorder`, and neither theme sets it explicitly.
`editor.lineHighlightBorder` is zeroed there too — Bearded draws a coloured
hairline box around the caret line (`#22a5c926` teal light, `#c7910c26` gold
dark), the one border in the editor that is on screen at all times; with it gone
the current line is still marked, by `editor.lineHighlightBackground`'s wash
alone (on the gutter as well, via `editor.renderLineHighlight: "all"`). Omarchy's
own template pins that key to `{{ background }}00`, so the force agrees with it
rather than overriding it — it is a literal instead of an `$EXACT` copy so the
intent reads as "no border".

**A tooltip's edge cannot come from a shadow**, which is why
`editorHoverWidget.border` stays at the copied `{{ muted }}` and is not in
`$FORCE`. The editor hover has no `box-shadow` declaration at all —
`.monaco-editor .monaco-hover` is background, border, radius, colour and nothing
else — so there is no shadow on it to recolour; the workbench hover does have
one, but it is a soft `0 2px 8px var(--vscode-widget-shadow)`, and that key is
global, so lighting it would bring back every widget shadow in the app
(`widget.shadow` also feeds Cursor's whole `--cursor-shadow-*` palette). A `0 0
0 1px` ring is CSS geometry, not a colour, and out of reach of any setting. The bottom border is
deliberately **shared** between the selected and hovered states: Omarchy gives
them different values (`tab.activeBorder` the full accent, `tab.hoverBorder` a
25%-alpha wash of it), so a tab's bottom edge changed weight depending on which
state it was in. The hook assigns one from the other — derived, not pinned, so it
tracks the theme's accent — and `tab.unfocusedHoverBorder` follows for free, since
Cursor's registry defines it as an alpha of `tab.hoverBorder`. Transparent rather than *deleted* —
`colorCustomizations` only overrides what it names, so dropping a key hands that
slot back to Bearded instead of clearing it. VS Code reads 8-digit `#RRGGBBAA`,
which Omarchy's own generated file already relies on for its `#007AFF20` washes.

**Edges and shadows are two tokens, because two is all the product exposes.**
Material 2's elevation scale was the target and is out of reach: a 2dp or 6dp
shadow is three stacked layers with their own offsets, blurs and spreads, and
box-shadow geometry is CSS — every surface's is hardcoded in
`workbench.desktop.main.css`. Border *width* is the same story: there is no
`*BorderWidth` or `*BorderSize` key anywhere in the registry (grepped), and
every edge in the product is 1px. Colour is what is themable, so the system is
one colour for every edge and one for every shadow, with each surface keeping
the shadow **shape** Cursor gave it.

*Border token* — `muted`, read off `textSeparator.foreground` (a bare
`{{ muted }}` in Omarchy's template) so it tracks the theme: `#BDBDBD` light,
`#565656` dark, the same colour as the Hyprland window border. Most managed
edges already resolved to it, since Omarchy's own `*.border` ids are muted and
`$CHROME` copies them. The one that did not is **`widget.border`**, which both
themes leave unset (registered default `null`), so Cursor's composites were
falling back to their own `--cursor-stroke-tertiary`. It is the `0 0 0 1px` ring
inside all four `--cursor-box-shadow-{sm,base,lg,xl}` composites — the edge on
the **quick input** — plus the find widget's side borders, `simple-find-part`,
the marketplace menus, the announcement modal and the feedback pane. Assigning
it is what makes the command palette and the tooltips share one edge.

*Shadow token* — `widget.shadow`, black at 14% (`#00000024`, Material's own
penumbra alpha). A literal, so it sits in `$FORCE`. `cursor/settings.json`
zeroes the other six shadow ids this build registers — `scrollbar.shadow`,
`editorStickyScroll.shadow`, `sideBarStickyScroll.shadow`,
`panelStickyScroll.shadow`, `listFilterWidget.shadow`,
`diffEditor.unchangedRegionShadow` (the three sticky ones are moot anyway, since
`editor.stickyScroll.enabled` and `workbench.tree.enableStickyScroll` are both
false). Those go in the **unscoped** top level of
`workbench.colorCustomizations`, not the hook's per-theme scopes:
`setCustomColors` applies the general block first and overwrites it with the
`[theme]` block, none of the six appear in the chrome copy, and the hook's `+`
preserves top-level keys, so the two coexist. `inlineChat.shadow` is not an
eighth — it is in Omarchy's generated file, but Cursor no longer registers it,
so those rules are already inert.

`widget.shadow` reaches further than its name suggests: Cursor derives
`--cursor-shadow-primary` from it and `--cursor-shadow-secondary/tertiary/workbench`
from `color-mix`es at 60/30/40%, so every `--cursor-box-shadow-*` composite
takes its colour from there too. Two consequences. Material's black is
near-invisible on a dark background — Material's own behaviour, it uses surface
overlays instead — and swapping the literal for `$muted` in the hook's
derivation is the one-line alternative if the dark theme wants a visible shadow.
And **the editor hover takes nothing from it**: `.monaco-editor .monaco-hover`
has no `box-shadow` declaration at all (background, border, radius, colour,
nothing else), so on that surface the border token is the only edge there is.

Two more limits worth not re-deriving. The ~50 hardcoded `rgba(0,0,0,…)`
box-shadows in Cursor's own React UI — modals, dropdown menus, the blame hover,
the code-block copy button — answer to no colour id. And **the two hovers cannot
be told apart**: the registry has five `editorHoverWidget.*` ids and no workbench
equivalent, so `:is(.monaco-workbench,…) .workbench-hover` and `.monaco-editor
.monaco-hover` share one `border` var — both or neither, whatever is done to it.

The one real loss from the zeroed six is `scrollbar.shadow`: it was the only cue
that an editor, list or terminal has content scrolled above the fold.

One wart — changing a preferred theme leaves the previous scope orphaned in
`colorCustomizations`; it is inert unless that theme is picked again, and the
hook does not prune it because it cannot tell its own scopes from a user's.

This is the one place the override **does** depend on marketplace extensions
(`beardedbear.beardedtheme`, `beardedbear.beardedicons`). `workbench.iconTheme`
had been deliberately stripped once before to keep that from being true; it is
back by choice. A machine without the extensions falls back to Cursor's default
theme and icons — no error, just not what the repo describes.

The file is otherwise kept to stock-Cursor keys — GitLens/Copilot keys and the
Biome / ESLint per-language formatters were all stripped — and `editor.fontWeight` is **600**, which is
load-bearing rather than cosmetic.

`editor.fontFamily` is `'ComicCode Nerd Font', monospace`, copied from
`~/Sites/dotfiles/.config/ghostty/config` (that repo has no Cursor settings of
its own; the font lives in its Ghostty config).

**Comic Code ships no Regular face, and Chromium abandons a family whose weight
it cannot match rather than falling back to a heavier face in it.** The two
`.otf`s are SemiBold (fontconfig weight 180) and Bold (200) — nothing at 400. At
the default weight Cursor therefore rendered the *fallback*, indistinguishable
from naming a font that does not exist. Measured in headless Chromium, canvas
text width at 40px:

| request | width | |
|---|---|---|
| `'NoSuchFontXYZ'` | 366.7 | the fallback |
| `'ComicCode Nerd Font'` at 400 | 366.7 | same as nonexistent — not used |
| `'ComicCode Nerd Font'` at 600 | 383.8 | SemiBold |
| `'ComicCode Nerd Font'` at 700 | 393.7 | Bold |

Hence `fontWeight: "600"`. The *base* family is named rather than
`ComicCode Nerd Font SemiBold`, because only the base carries both faces — the
SemiBold-specific family has one face and bold tokens would fall out of it.
Ghostty needs none of this: it resolves through fontconfig and takes the named
face, which is why copying its `font-family = ComicCode Nerd Font SemiBold`
across verbatim silently did nothing.

Ghostty's `font-thicken` / `font-thicken-strength` have **no** Cursor
counterpart, and neither did the `environment.d` stem darkening while it
existed: Cursor is Electron, so it inherits Chromium's ignoring of
`FREETYPE_PROPERTIES` (see the Chromium entry under *traps*). That drop-in has
since been dropped from the repo — and `apply.sh` step 7c now deletes an
already-installed copy by name, since both it and `revert.sh` otherwise only
walk the repo directory and a file removed from the repo would live on
forever. Comic Code renders thinner in Cursor than in Ghostty regardless, and
no setting closes the gap.

Ghostty's `font-size = 14` is a terminal size and was not copied.
`editor.fontSize` is **derived**, not pinned: `apply.sh` reads `omarchy display
text size` (the one knob that already drives the shell base size in px, the GTK
factor and the terminal point size at `px * 9/12`) and writes it into the merge,
since VS Code's `editor.fontSize` is in px like the first of those. The number in
`cursor/settings.json` is only the fallback for when that reading fails. It stays: it is a user preference with no Omarchy equivalent.
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

**ytm-player is split two ways: colours are themed, preferences are not.**
`themed/ytm-player.toml.tpl` renders per theme and `hooks/theme-set.d/ytm-player.sh`
copies it to `theme.toml` and rewrites `[ui] theme` (Textual's `dark` flag is
not settable from `theme.toml`, and it drives every derived contrast token).
Everything that does *not* change with the theme — the startup page, the
playhead style, the clutter toggles — is written once by `apply.sh` through
`ytm/config-prefs.py`, insert-or-replace per key so `[ui] theme` and anything
the user set stay put.

Four ytm mechanics behind that, all measured against 2.1.0:
`Settings.save()` emits **every** field of every section, so `config.toml`
always carries all 58 keys and can never carry a comment — but saving is
reached by only two user actions (set-theme-as-default, Browse's region
picker), not on exit, so this is not the Chromium/Cursor trap and a write
while ytm is open survives (it just lands at the next launch, settings being
read once at start). `Settings.load()` is per-key and type-checked, so a
partial file is valid — `config-prefs.py` can create one before ytm has ever
run. `startup_page` is validated against `PAGE_NAMES` (`app/_navigation.py:23`:
library, search, context, browse, queue, help, **liked_songs**,
recently_played) and a name off that list **silently** falls back to
`library`, which looks exactly like the key having no effect. And
`playback_bar_position` is a **dead key** — defined in `config/settings.py`
and read nowhere; the bar is bottom because `PlaybackBar`'s own CSS says
`dock: bottom`. It is set anyway, since ytm re-emits it on every save
regardless and it is the only place the intent can be written down.

The playhead itself is `[ui] progress_style`: `"block"` (chosen) fills the
elapsed part with solid blocks against light-shade ones, `"line"` draws a thin
rule with a round head at the current position. Both live on the playback
bar's bottom row and both seek on click.

**`[ui] show_selection_info = false` hides the playback bar and the footer,
not just the selection line.** `#bottom-stack` (`app/_app.py:173`) is
`height: auto` and holds three children, of which `PlaybackBar` and
`FooterBar` are both `dock: bottom` — docked children contribute nothing to an
auto height, so the selection-info bar is the only thing giving that container
any height at all. `bar.display = False` (`app/_app.py:838`) therefore
collapses the stack to zero and clips the two widgets that were wanted.
Measured in a headless Textual app with the same structure: with the toggle
on, the last rows carry the info line, the bar and the footer; with it off,
they are blank. So the line stays on — ytm loads no user stylesheet
(no `CSS_PATH`, no `.tcss` read from its config dir), so there is no lever
that drops the one line and keeps the bar.

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
- **Figma Desktop** (Electron, forced to native Wayland by the
  `FIGMA_USE_WAYLAND=1` `environment.d` drop-in) —
  its launcher sets `ELECTRON_USE_SYSTEM_TITLE_BAR=1` and
  `--disable-features=CustomTitlebar`
  (`usr/lib/figma-desktop/launcher-common.sh`), so it asks the compositor for a
  titlebar and Hyprland gives it none: no frame, no panel, nothing to script.
  An earlier version of this line said it drew its own top panel sized by
  `panelHeight` in `~/.config/figma-linux/settings.json`. That was the *other*
  project — see the provenance note below; that directory is a leftover and the
  running app never reads it.

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
  Taken to its conclusion: every `shell.*.toml` here now ships
  `background-alpha = 1.0`, so the `hl.layer_rule { blur = true }` in
  `overrides/hypr/looknfeel-decoration.lua` is **entirely inert** — the only
  thing `decoration.blur` still reaches is the unfocused window at 0.875. The
  rule is kept because it is the whole cost of re-enabling glass later; the
  number to watch when doing that is its `ignore_alpha = 0.6`, which splits
  cards (above) from scrims (below, currently 0.25).
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
- **Chromium ignores `FREETYPE_PROPERTIES`.** The stem darkening this repo used
  to ship as `overrides/environment.d/10-cllpse-macos-font-rendering.conf`
  reached every app on the desktop *except* Chromium, so page text there
  rendered at the thin weight the SF faces are drawn at. The drop-in is gone
  now, but the finding is why it never helped there in the first place. Measured: identical output with darkening
  off, on and strong, while the same value through system FreeType (ImageMagick,
  same `.otf`) adds 24% ink. Fontconfig `embolden` is ignored too; hinting is
  the only render param Chromium honours, and it is already at `hintnone`. No
  flag fixes this — `--text-contrast` and `--text-gamma` exist in the binary but
  are inert, and `--font-render-hinting` is Electron's, not Chromium's. The only
  working lever is CSS (`-webkit-text-stroke: .2px` ≈ +21% ink, against
  FreeType's +24%), which needs a content-script extension since Chromium
  dropped user stylesheets.
- **jq's `//` treats `false` as absent, which silently drops exactly the value
  worth recording.** `.bar.transparent // empty` emits nothing for `false`, not
  just for `null` — so `apply.sh`'s `record_prior` for `bar.transparent` got an
  empty string on every stock machine (Omarchy ships `false`), refused it, and
  left `revert.sh` with nothing to put back and no way to know the bar had ever
  been opaque. The reading is `.key | if . == null then empty else tostring
  end`. Applies to any boolean or numeric-zero default behind `//` in this repo.
- **A Lua table key assigned `nil` is not stored, so `{ class = x }` with a nil
  `x` is `{}` — an EMPTY filter, which matches everything.** `hl.get_windows({
  class = active.class })` in `macos-shortcuts.lua` is the live example: with a
  classless focused window that is `hl.get_windows({})`, and the SUPER+Q loop
  that follows would have closed every window on every workspace. Guard the
  value before it reaches the table, not the table afterwards. This is the
  mirror image of the exact-match note below it — the filter being strict is
  what makes a *populated* table safe, and says nothing about an empty one.
- **Python's `re.sub` expands backslash escapes in its REPLACEMENT string.**
  `re.sub(pat, block, text)` where `block` is generated content turns any `\p`,
  `\1` or `\g<…>` in it into a regex escape — `re.error: bad escape` at best,
  a silently altered file at worst. `yazi/generate-icons.py` splices a
  725-rule table this way and happens to contain no backslash today, which is
  what would have made the next yazi upgrade's failure hard to place. Pass a
  lambda (`lambda _m: block`) so the text goes through literally.
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
- **A grep pattern that starts with `-` is parsed as an OPTION, and `-F` does
  not save you.** `sync_fenced`'s markers are `-- >>> … >>>` on a `.lua` target,
  and `grep -qxF "$open" file` fails with `invalid option -- >>> …` rather than
  simply not matching — so the "is this block already here?" test answered *no*
  every time and a duplicate block was appended on every run, on `.lua` files
  only. Pass the pattern with `-e`: `grep -qxF -e "$open"`. The bug this
  replaced hid behind the same asymmetry from the other side: the original test
  matched `$mark` as a **substring**, and because `cllpse-macos overrides` is a
  prefix of `cllpse-macos overrides: keybinds`, a file carrying only a
  *suffixed* block reported the plain one as present, after which the `awk`
  rewrite found no matching open-marker line, passed the file through unchanged,
  and — the output being non-empty — reported success. The empty-write guard
  cannot catch that: the file is not truncated, it is simply never written.
  `bindings.lua` is the only file here with four blocks, so it is the one this
  reaches.
- **Hyprland logs NOTHING when it reloads its config, so an old log with no
  reload lines in it is not evidence that no reload happened.** Several
  `hyprctl reload`s in a row left zero matching lines in a 15,000-line, actively
  written `hyprland.log`. That absence was read here as proof that `apply.sh`'s
  edit to `bindings.lua` had never reached the compositor — and a whole trap
  entry, plus a step in `apply.sh`, got written on it before the claim was
  tested directly. It was wrong.
  **Autoreload does pick up a `require`d module**, not just the config Hyprland
  was started with: appending one bind to `~/.config/hypr/bindings.lua` took
  `hyprctl binds` from 150 to 151 within three seconds, with nothing
  dispatched. `apply.sh`'s `sync_fenced` edits land on their own; step 8c's
  `hyprctl reload` is determinism and a guard against
  `misc:disable_autoreload`, not a fix.
  The lesson that generalises: this compositor is quiet about a lot, so
  "nothing in the log" is never the measurement. Test the state itself — count
  the binds, read the value back — and keep the probe in the notes.
  One genuine finding survived from that pass, and it is worth keeping because
  it is not obvious: **a reload rebuilds the Lua state entirely.** Lua caches
  modules in `package.loaded`, so a reload that merely re-ran the top-level file
  would keep a stale `bindings.lua`. It does not — a global set through
  `hyprctl eval` before a reload reads back `nil` after it, and
  `package.loaded` comes back freshly populated.
- **Two output directories, one cleanup.** `app-icons.sh` writes both
  `~/.icons/cllpse-flat/` and `~/.icons/cllpse-color/`, but `revert.sh` removed
  only the first for as long as the colour pass existed — the pass was added in
  `89ff73a` and the removal block was last touched in the older `3ee160d`, so
  the two simply never met. The leftover is the worst shape one can take here:
  `$HOME/.icons` is the **first** directory in the sweeps both `AppLibrary` and
  the switcher run, so those drop-ins keep overriding vendor icons forever, and
  with the repo reverted nothing on the machine explains why. It also silently
  defeated the `rmdir ~/.icons` below it, which cannot remove a non-empty
  directory. When a script grows a second output path, grep `revert.sh` for the
  first one before assuming it is covered.

- **A group granted by `usermod -aG` does not reach the session that granted
  it, a RELOGIN does not fix that, and `hl.dsp.exec_raw` hides the resulting
  failure completely.** Three things were live at once, which is what made this
  take two debugging sessions. `keyd bind` talks to `/run/keyd.socket`,
  `srw-rw---- root keyd`, so `apply.sh` step 8b adds the user to the `keyd`
  group — but supplementary groups are fixed when a process tree is created,
  so the running Hyprland session and everything it spawns keep the old set.
  The tell is `getent group keyd` listing the user while `id` does not.

  The part that cost the second session: **"fixed at login" is wrong, and the
  obvious fix does not work.** uwsm starts Hyprland as a unit of the systemd
  **user manager** (`user@1000.service`), so Hyprland's parent is that manager
  — not the SDDM helper that ran PAM — and with logind's stock
  `KillUserProcesses=no` the manager outlives a logout. Measured here: the
  manager started 12:31:20, `usermod -aG` wrote `/etc/group` at 12:32:37, and a
  fresh graphical login at 12:54:51 produced a Hyprland whose
  `/proc/<pid>/status` still read `Groups: 998 1000`. Two logouts changed
  nothing. Only a reboot (or `systemctl restart user@1000`, which takes the
  desktop with it) reseeds it. Check the ancestry, not the session: walk `PPid`
  from the process that actually fails up to PID 1 and compare each
  `/proc/<pid>/status` `Groups:` line against `getent group`.

  So the group is no longer waited on. **`newgrp` is setuid-root and reads
  `/etc/group` directly**, so piping a command to it runs that command under a
  correct group set with no relogin and no sudo — `printf '%s\n' "$cmd" |
  newgrp keyd`, since `newgrp` takes no `-c` and Arch ships no `sg`. Verified:
  it propagates the inner shell's exit status, its stderr comes back clean with
  no login-shell noise, and it costs ~3ms. `cllpse-figma-keyd` tries a plain
  `keyd bind` first (the fast path from the next boot on) and falls back to
  `newgrp` only when `/etc/group` lists the user and the session does not — so
  it can never sit at a group-password prompt.

  The third half was the missing error channel: `macos-shortcuts.lua` fires the
  helper through `hl.dsp.exec_raw`, which discards stdout **and** stderr, so a
  helper exiting 255 on every focus change looked exactly like one that worked,
  and the *symptom* is at the far end — Figma's Cmd+scroll simply keeps not
  working. The helper therefore diagnoses itself and raises one `notify-send`
  per session, stamped in `XDG_RUNTIME_DIR` so a focus toggle cannot spam it.
  The general lesson: anything reached only through `exec_raw` has no error
  channel at all, so it has to carry its own.

  **The `journalctl -u keyd` audit channel died with the `leftcontrol` form,
  and nothing replaced it.** While the bind was `leftmeta = leftcontrol`, keyd
  logged `WARNING: You should use layer(control) instead of assigning to
  leftcontrol directly` on every accepted call, and counting that line across an
  action proved the chain end to end (`hyprctl reload` with Figma focused took
  it 5 → 6 — focus handler, helper and keyd all confirmed at once). The bind is
  `layer(figma)` now, which is precisely what that warning asked for, so it
  logs **nothing at all** — measured: three binds this boot, zero matching
  lines. There is still no query command for runtime binds, so the only way to
  check one landed is to issue it and read the exit status, which is what
  `apply.sh`'s smoke test does. A `reset` was always silent.

## Reproducing this on another machine

`apply.sh` is deterministic and idempotent for what it controls, but it is not a
full machine build — it installs no packages, no third-party plugins,
and `display.conf` carries values tuned for one specific display. Several
settings only take effect after a relogin. `overrides/README.md` has the full
list under *What apply.sh does and does not guarantee*; read it before assuming a
clean install ended up identical.

## Still open

- `revert.sh`'s restore paths have unit-tested helpers but have never been run
  end-to-end; that needs a spare machine or VM, not this one.
