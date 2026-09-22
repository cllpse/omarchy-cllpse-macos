# Working on omarchy-cllpse-macos

Two Omarchy 4 themes reproducing the macOS appearance, plus the machine-level
overrides and the window-switcher plugin they need.

Start with [`README.md`](README.md) for layout, [`overrides/README.md`](overrides/README.md)
for what `apply.sh` touches, and [`reference/BUILD.md`](reference/BUILD.md) for the
spec. This file is only for what those don't say: how Omarchy itself behaves, and
the traps that have already cost time.

**`omarchy-cllpse-plugin-switcher/` is a submodule**, not a directory —
[cllpse/omarchy-cllpse-plugin-switcher](https://github.com/cllpse/omarchy-cllpse-plugin-switcher),
published to the Omarchy plugin marketplace on its own. Clone this repo with
`--recurse-submodules` or run `git submodule update --init --recursive`; a plain
clone leaves it empty and `apply.sh` step 1 stops rather than symlinking a
registered plugin id at nothing. Edits to `Hud.qml` are commits in **that**
repo and have to be pushed there and then have the submodule pointer bumped
here — two commits, not one. The plugin's design log stayed behind as
[`reference/window-switcher-notes.md`](reference/window-switcher-notes.md),
deliberately: the published repo carries a user-facing README, and its history
was started fresh so the log is not in it.

Target is **Omarchy 4.0.2** (`quattro`). The `master` branch is stale at 3.8.5 and
documents an incompatible theme format — don't read it.

---

## Omarchy mechanics worth knowing

### Themes and Hyprland config

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

### Backgrounds

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
`00-umeda_wallpaper_desktop*.webp`, `00-` chosen because digits sort ahead of
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
- *The whole `[launcher]` section* — a dead **section**, not just dead keys.
  `Color.qml` defines `bar`/`popups`/`tooltip`/`notifications`/`menu`/`polkit`/
  `lock`/`imagePicker` and no launcher surface; the lookups are string-keyed
  (`pick("menu.text")`) and nothing anywhere reads a `launcher.*` key. There is
  no launcher plugin and no `omarchy-launcher` layer namespace: SUPER+SPACE is
  the **menu** plugin (`plugins/menu/Menu.qml`, namespace `omarchy-menu`,
  binding `Color.menu.*`), so `shell.menu.toml` is what styles it and the blur
  layer rule covers it under `menu`. Each theme still ships a
  `shell.launcher.toml` mirroring `[menu]`, spliced into the generated
  `shell.toml` and read by nobody. What makes this worth *checking* rather than
  re-deriving: Omarchy's own `default/themed/shell.toml.tpl` ships the section
  and documents it as "applied to the launcher overlay", so the config reads
  live. Verified by enumeration — `grep -rn -i launcher /usr/share/omarchy/shell`
  returns no key lookup.
- Font *size* is machine-level only: `~/.config/omarchy/shell.toml` `[font]
  base-size` (**13** at the time of writing, via `omarchy display text size`;
  `display/display.conf` records it for `apply.sh` to restore — and the two have drifted
  apart before, when the live size was changed without re-running
  `display/save-display.sh`, leaving `apply.sh` primed to undo the change on its next
  run. Read the live value, don't trust this number or that file). That file is **watched live** —
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

### Generated files

**Generated, never committed:** `btop.theme`, `hyprland.lua`,
`vscode-theme.json`, `neovim.lua` and the terminal colour files are produced from
`colors.toml` on every theme-set. Omarchy strips `.lua` from *git-cloned* themes,
which is why window decoration lives in `overrides/hypr/`, not in a theme folder.
Our themes are symlinked rather than cloned, so nothing is stripped.

**`chromium.theme` is committed, by exception — but it does NOT fix the cyan,
and an earlier version of this entry said it did.** Omarchy's template is
`{{ background_rgb }}`, so the generated seed for the light theme is
`255,255,255` — pure white. Each theme folder therefore ships an explicit
`chromium.theme`: light `236,236,236` (`#ECECEC`, the AppKit
`NSColor.windowBackgroundColor` catalog value for aqua — BUILD.md §2 reads the
composited window as `#FFFFFF`, which is the degenerate case), dark `30,30,30`
(`#1E1E1E`, matches BUILD.md §1). `omarchy-theme-set-templates` skips generation
when the file already exists in the staged theme. That file is the seed
`omarchy-theme-set-browser` hands Chromium as the `BrowserThemeColor` managed
policy (`/etc/chromium/policies/managed/color.json`, written by the
passwordless-sudo helper `omarchy-theme-set-browser-policy <rrggbb>` — worth
knowing, since it makes seed-vs-seed testing a no-password loop).

What it cannot do is make the browser neutral. Chromium runs the seed through
Material's **tonal-spot** scheme, which forces chroma onto the generated
palette; a zero-chroma seed has no hue of its own to force, so it lands on the
scheme's default hue and the whole browser comes out faintly cyan. `#ECECEC`
and `#1E1E1E` are both pure greys, so both hit this exactly — the value that
was supposed to be the fix is an instance of the bug. Measured on Chromium 152
in a throwaway profile under the live policy: menu background
`rgb(248,253,254)`, separators `rgb(200,246,254)`. Pushing `#FF0000` through the
same policy turns the whole frame pink, which is what pins it on the seed.

**Two profile keys get it back to neutral, and neither is enough alone.** Both
are written by `overrides/chromium/neutral-theme.py` (apply.sh step 7d), and
both are profile state with no flag and no policy behind them:

| key | what it reaches |
|---|---|
| `extensions.theme.system_theme = 1` | the frame and the **menus** — measured menu `rgb(255,255,255)`, separators `rgb(242,242,242)` |
| `browser.theme.is_grayscale2 = true` | the **accent** the GTK theme leaves behind — with the system theme alone the omnibox focus ring is still a dark teal, and this puts it back to Chromium's own blue |

`is_grayscale2` is the half that survives the policy, which is the surprise:
`browser.theme.user_color2` does **not** (measured with a blue one — nothing
changed), so a profile cannot out-colour the policy but it can opt out of the
generated palette entirely. The system theme also follows `gsettings
color-scheme`, the same signal a theme's `mode` key already flips, so light/dark
still tracks `omarchy theme set` with no hook.

**Fixing it from the seed end makes it worse.** Pushing the theme's own accent
(`#007AFF`) through the policy paints the tab strip dark blue (active tab
`rgb(24,92,162)`): a seed with real chroma themes the frame as designed, which
is the whole point of the policy. The grey seed plus those two keys is the
combination that leaves the browser neutral.

Two things about measuring this, since it took several passes: the **omnibox
focus ring and an inactive tab's hover are the tells**, not the separators — the
system theme fixes the separators on its own, which reads as "done" while the
accent is still cyan. And a hover needs a real pointer, which
`hyprctl eval 'hl.dispatch(hl.dsp.cursor.move({ x = …, y = … }))'` provides
(`hl.dsp.cursor` holds exactly `move` and `move_to_corner`); save
`hyprctl cursorpos` first and put it back, or you have moved the user's mouse.

### App icons

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
step 7f and `overrides/icons/`. Nothing there is generated: each icon is a
hand-placed SVG named for a desktop entry's `Icon=` value, and an app without
one keeps its vendor icon.

**There are two drop-in sources, both in this repo, and the split is the whole
mechanism.** `icons/icons/` — 24 silhouettes — is **repainted** to the active
palette by `app-icons.sh` and lands in `~/.icons/cllpse-flat/apps/`.
`icons/verbatim/` — 75 full-colour marks — is copied unchanged, no ImageMagick
and no palette, into `~/.icons/cllpse-color/apps/` by the same script. The
repaint is keyed on the DIRECTORY, never on anything inside a file, so a
multi-hue logo in the first would come out flattened. Both land under `*/apps/*`
in the sweep, so both outrank every installed theme.

**The menu is the only consumer of the colour pass** — it draws a plain `Image`
out of `$HOME/.icons` and cannot recolour, so a verbatim mark reaches it no other
way, while the switcher reads its own `icons/` directly.

A missing source means one thing again, now that both live here: the marks were
deliberately deleted, so the sweep clears what they backed — which is what
"delete a drop-in to hand that app back" has to mean. While the verbatim set sat
in the submodule it meant two things, and the script had to test `manifest.json`
to tell "deleted" from "never checked out"; that guard went with the move.

The colour pass runs **first** and outside the flat pass's guards, on purpose:
it needs neither the palette nor a readable `colors.toml`, and coupling them
once meant emptying one set silently stopped syncing the other. An earlier version generated the whole set
from Nerd Font outlines; it was removed in favour of sourcing marks by hand,
because automatic derivation cannot produce a usable mark for a logo defined by
colour boundaries rather than shape (measured: Chromium, OBS and Moonlight all
flatten to featureless discs, and no fill-ratio threshold separates those from
legitimately solid marks — a filled circle scores 0.785, the same range as real
ones).

**Two keyspaces, one rule.** `overrides/icons/icons/` is named for a desktop
entry's `Icon=`; the switcher's `Hud.qml` `glyphFor` (in the submodule) is keyed on the
window class, because a switcher has nothing else. A single shared key does not
exist — measured here, 5 of the 24 entries declaring `StartupWMClass` use a
class that is not their icon name, and Chromium's is the literal unsubstituted
`@@startup_wm_class`. So the switcher looks the class up in an index it builds
once at launch, and falls back to its own glyph when nothing answers — which
covers a missing file, an empty `icons/`, a machine where step 7f never ran,
and a name mismatch alike. A drop-in whose filename differs from the window
class reaches the menu but not the switcher; a second copy named for the class
covers both.

**It is an index, not a probe, and that distinction is load-bearing.** It used
to test existence per tile with two `Image`s per mark, `.svg` then `.png`,
whichever reported `Image.Ready` winning. That made the delegate's *structure*
depend on `Image.status` — and `QQuickImageBase::itemChange` reloads an `Image`
on any device-pixel-ratio change, delivered by recursing the item tree, so
anything bound to `status` that owned child items tore them down mid-walk. It
aborted the shell four times. Do not reintroduce a per-tile existence test.

**The switcher reads four sources now, and only two are ours.** In order: the
plugin's own user directory (`~/.config/omarchy/cllpse.window-switcher/icons/`,
which nothing here creates or manages), then `~/.icons/cllpse-flat/apps/` —
ours, and read by the plugin as a documented *optional integration* rather than
a dependency — then everything the `*/apps/*` sweep finds including
`~/.icons/cllpse-color/apps/` — which `app-icons.sh` fills **from the plugin's
own `icons/`**, so that source and the last one are the same 75 files — and
finally those marks as the plugin reads them directly. Emptying
`overrides/icons/` therefore cannot leave the switcher short of anything.

**A fifth source now feeds the switcher and it is not an icon at all: a
browser tile's badge is the site's favicon, read out of the browser's own
profile.** The terminal trick does not transfer -- a terminal's title *is* the
command, because shell integration writes it, while a browser's is the page's
own. There is no URL anywhere on the toplevel, so the only join is title ->
the browser's history DB -> URL -> its favicon DB. **That means the plugin has
read access to a browsing-history database**, which is the thing to weigh
before anything else here; it is narrowed by the code (only the titles on
screen, read-only, nothing written into the profile at all) and by nothing
else. See the `ro()` entry below for what "read-only" has to mean in practice,
since one URI does not cover both browser families.

### The window switcher

**Nothing in Omarchy or Quickshell offers this.** Enumerated, not assumed:
Quickshell's whole `Io` module is `FileView`, `Process`, `Socket`,
`SocketServer`, `DataStream`, `IpcHandler`, `JsonAdapter`, `StdioCollector`,
`SplitParser` -- **no SQL type**, so a helper is the only route.
`QtQuick.LocalStorage` is a red herring: one method, `openDatabaseSync`, which
keys a DB by an **md5 of its identifier** under the engine's own path and opens
it **read-write**. No path form; don't re-try it. Omarchy's `fetch_site_icon`
(in `omarchy-webapp-install`) is URL-driven and network-based -- apple-touch-icon,
then `<origin>/apple-touch-icon.png`, then Google's `s2/favicons?...&sz=256`.
Worth knowing only because **that path yields 256px where Chromium's cache tops
out at 32**; it cannot tell you which site a window is on, which is the hard half.

Findings worth not re-deriving:

- **Reading a live profile takes TWO different URIs, and picking one is a
  bug.** `mode=ro&immutable=1` takes no lock, which is the only way to read a
  running **Chromium** -- it holds History and Favicons at
  `locking_mode = EXCLUSIVE`, so a plain `mode=ro` gets `database is locked`
  and nothing else (measured against the live profile: immutable 0.56ms, plain
  `mode=ro` fails in 0.04ms). But `immutable=1` ignores the `-wal` **by
  design**, so against **Firefox** -- whose `places.sqlite` is WAL -- it
  silently returns the database as of the last checkpoint. Measured against a
  live writer: **1 row of 399**. That was a real, shipped bug, and a
  reconstructed Firefox profile with no live writer is exactly what would not
  show it.
  `mode=ro&readonly_shm=1` reads the WAL and, unlike a bare `mode=ro`, leaves
  the `-shm` **byte-identical** (A/B'd on two fresh databases, each with its
  own live writer: `mode=ro` changed it, `readonly_shm=1` did not, both saw all
  399 rows). It is gated on a `-shm` already existing rather than simply
  preferred, because without one it cannot open the database at all and -- when
  there is no `-wal` either -- **creates a zero-byte `-wal` in the profile**
  before failing. That gate is the only thing between this plugin and a write.
  Cost of the WAL path scales with WAL size: 0.16ms at 177KB, 2.39ms at 3.6MB,
  against 0.04ms for immutable. Noise beside the 8ms interpreter floor.
  `readonly_shm` is a unix-VFS parameter, not one of the six documented URI
  ones, and an SQLite that does not know it **ignores it silently** and leaves
  a plain `mode=ro` that still reads but does write a read-mark. Honoured on
  3.53.4; re-run the A/B before trusting the no-write claim elsewhere.
  `nolock=1` and `vfs=unix-none` were both tried and cannot open a WAL at all.
- **`timeout=0` or a five-SECOND stall.** Python's `sqlite3.connect` defaults
  to a 5s busy timeout, and the locked-Chromium path above walks straight into
  it -- measured 5008ms against 0.17ms. The old code never hit this because
  `immutable=1` takes no lock; anything that stops being immutable must pass
  `timeout=0`.
- **A browser does not write a visit to its history when it happens.** Chromium
  commits **10.07s** later (measured: throwaway profile, navigation driven over
  DevTools, polling the DB as the helper opens it -- it is
  `kCommitIntervalSeconds`). The switcher's lookup runs ~464ms after a title
  settles, so the page in front of you is invisible to it by construction,
  every time. Combined with the plugin's own unchanged-key-set guard that made
  the miss **permanent**: the title does not change, so the key set does not
  change, so nothing ever asked again. 70% of navigations in this profile went
  to a URL with no prior visit, so most pages never got a badge at all. Fixed
  with a bounded retry -- 3 attempts, 12s apart, then give up -- and the guard
  now yields to that timer and to nothing else. Do not "simplify" it back into
  a plain early return.
- **QML's `Image` takes a `data:` URL** -- verified against a `file://` control,
  same `sourceSize`, both `Ready`. That is what keeps "writes no files" true.
- **Sniff the media type, never assume it.** Chromium re-encodes every favicon
  to PNG; Firefox stores what the site served, so ICO and SVG turn up. A `data:`
  URL that lies about its type is refused by Qt with nothing in the log.
- **The ambiguity figure is a trap.** 28% of recent titles resolve to a
  *different host* than their own page, which reads like a 28% error rate and is
  not one: of 200 pages, 145 gave the byte-identical favicon and all 55 misses
  were one CDN session sharing titles with its origin. Measure the **icon**, not
  the host.
- **`urls.title` has no index** (only `urls_url_index`), so every lookup is a
  full scan: 0.02ms at 730 rows, 5.2ms at 100k, 25.5ms at 500k, per title.
  Nothing fixable from outside, so the defence is not asking -- the refresh only
  queries titles it has **no answer for**, which is safe because the title *is*
  the key.
- **Page titles are arbitrary web content**, so an index keyed on one needs
  `typeof x === "string"`, not `!== undefined`: a page titled `constructor`
  returns the inherited `Object.prototype` member.

**Generality made it faster, which is the opposite of the usual trade.**
Identifying a profile by its two database files (rather than a path per
browser) covers every Chromium and Firefox fork, but the sweep must reach
`~/.mozilla`, `~/.librewolf`, `~/.zen` -- 10.5ms against 1.6ms for
`~/.config` alone, taking the run 25.6 -> 31.2ms. Hoisting the sweep out of the query
brought it to **17.2ms**: a third faster than the Chromium-only version, and
covering both families. It runs **once per session, on first sight of a browser
window** -- not in `Component.onCompleted` like the plugin's other three index
scans, so a session with no browser open never pays the 28ms and never has its
`$HOME` walked. For scale, `vendorScan` already spends **247ms** at every shell
start, which is why caching the result to disk across restarts is not worth the
staleness or the loss of "writes no files". Four titles cost the same, because the SQL is noise beside the spawn.
Two mechanics behind it: **one `scandir` per directory, reused for the marker
test and the descent** (10.5ms vs 23.4ms for the version that stats then lists
again), and **only hidden top-level dirs of `$HOME`, to depth 2** -- every native
install, while a flatpak profile at `~/.var/app/<id>/.mozilla/...` is deeper and
deliberately missed, since depth 4 costs 4x (27 -> 98ms).

**Where the 17.2ms goes, and why it stops there.** The SQL is 0.43ms; the rest
is Python: 7.9ms interpreter floor, ~6.5ms of stdlib imports, ~2ms compiling the
script (a `__main__` script is never cached, only imported modules are).
`-S` halved the startup and dropping `import glob` saved 7.5ms -- both are in.
What remains was measured and **rejected**: swapping every import for its C
module (`posix`, `binascii`, `_sqlite3`) saves 2.1ms but trades documented APIs
for private ones whose signatures move between releases. The `sqlite3` CLI
starts in 1ms and this build even has `base64()` (it wraps at 72 chars;
`replace(base64(x), char(10), '')` undoes that, and `ATTACH` joins both DBs in
one query) -- rejected on **safety, not speed**: it cannot bind a parameter, and
every value here is a window title a remote page chose, going into a shell that
has `writefile()`. A **persistent helper** answers in 0.40ms (0.70 for four),
roughly 46x, and costs **13.8MB resident for the life of the shell**; declined,
since the spawn is rare, debounced and off the critical path. Numbers are here
if that ever looks different.

**The plugin's own files can be two versions at runtime.** `omarchy plugin
update` replaces `favicons.py` on disk while `Hud.qml` stays in the running
shell. Seen for real: a 2-field parser reading 3-field output built
`data:image/png;base64,image/png<TAB>iVBOR...` and Qt logged one "Unsupported
image format" per frame. The parser now validates the media-type field against
`^[a-z]+/[a-z0-9.+-]+$` and drops the line, so skew is silent like every other
failure. Applies to any QML-plus-helper protocol here.

**A test that aborts early reports zero failures.** The QML harness lifts
functions verbatim out of `Hud.qml`; one called `faviconDebounce.restart()`,
which the harness does not define, so `Component.onCompleted` threw there and
every later assertion never ran -- with `fails` still 0, which reads exactly
like a pass. It now sets a `finished` flag as its last statement and the
watchdog exits non-zero if it is unset. Any harness lifting code out of a larger
component needs that tripwire, or its silence means nothing.

**Both repos carry all 99 marks, and nothing enforces that they match.** The
plugin holds them in one `icons/`; this repo splits them by treatment across
`icons/icons/` and `icons/verbatim/`. That duplication was removed once, making
the plugin the single source precisely so two copies could not diverge, and then
deliberately taken back when both repos were asked to be complete. It diverged
within minutes of being taken back: seven files differed because the plugin's
copies were fitted to the `viewBox` contract and this repo's were not, which had
the menu drawing those 24 smaller than the 75 beside them.
`overrides/icons/AGENTS.md` carries the one-liner that detects it; run it before
trusting either repo.

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

### Caches, restarts and boot art

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

### Hooks and plugins

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

### Layer rules and animation

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

### Quickshell and QML

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

### Figma Desktop

**The installed Figma is `IliyaBrook/figma-linux`, not `Figma-Linux/figma-linux`
— and NOT `nickvdp/figma-desktop-linux`, which does not exist.** This file has
now named the wrong project twice, so the distinction is worth stating by owner
rather than by repo name, because the two real projects share the name
`figma-linux`:

| | what it is |
|---|---|
| `IliyaBrook/figma-linux` | **ours.** Extracts the official Figma Desktop *Windows* installer, patches it for Linux and repacks it as an AppImage. The real Electron client — tray icon, `figma://` handler, `.fig` opening, MCP server |
| `Figma-Linux/figma-linux` | a community Electron wrapper around the **web app**, with its own settings schema and a `ThemeCreator`. Not installed here |

`nickvdp/figma-desktop-linux` was named here for a while on the strength of the
AppStream component id, which really is `io.github.nickvdp.figma-desktop-linux`
— but that string is a **hardcoded constant in IliyaBrook's own build script**
(`scripts/build-appimage.sh`, `component_id=`), inherited from an earlier
project. The id is real; the repo slug 404s and the GitHub user `nickvdp` has no
such repo. Don't re-derive the upstream from the app id.

Ours is `~/Applications/figma-desktop-<version>-amd64.AppImage`, extracted to
`~/Applications/figma-desktop/`. `overrides/figma/figma.sh` does the install
and the update — see the entry under *Conventions* below.

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
`integrate_desktop()` runs on *every launch* and rewrites the whole entry unless
the existing `Exec` already equals what it would write. Because this is an
extracted directory rather than a mounted `.AppImage`, that path carries no
version, so the template matches on every release and the rewrite never fires.
The full derivation is in
[`overrides/applications/README.md`](overrides/applications/README.md).
Updating Figma is: extract over the app directory, re-run `apply.sh`.

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

**`overrides/figma/figma.sh` is the install and the update, and they are the
same run.** It is the one script here that reaches the network and the only one
that installs an application at all — `apply.sh` still installs nothing. Five
things in it are load-bearing rather than convenience:

- *Version comes from the app's own bundled entry*, `$APP_DIR/io.github.nickvdp.figma-desktop-linux.desktop`'s
  `X-AppImage-Version`, not from a stamp file of ours. Upstream writes that
  file and every extraction restores it, so it cannot drift from what is on
  disk the way our own record could. (It is **not** the entry in
  `~/.local/share/applications/`, which is ours and carries no version.)
- *The release tag is not the version.* Upstream's tags are inconsistent —
  `126.5.6` for the latest, `figma-desktop-126.4.11` and
  `figma-desktop-126.3.12.1` for older ones. The **asset** name is regular
  (`figma-desktop-<version>-amd64.AppImage`), so both the latest and the
  `--version` path resolve through the asset and never parse a tag.
- *It refuses to extract over a running Figma*, by resolving `/proc/<pid>/exe`
  into the app directory — not `pgrep -f`, which would match this script's own
  command line (the trap already hit elsewhere in this repo).
- *Scratch lives in `~/Applications`, not `/tmp`.* `/tmp` is tmpfs here, so a
  ~500 MB extracted tree would sit in RAM, and the swap would be a cross-device
  copy rather than a rename.
- *The swap is gated and reversible.* The old directory is moved aside, not
  deleted, and the new tree only goes in after `AppRun` is confirmed to contain
  `integrate_desktop` — the same marker step 7e keys on. A failure leaves the
  previous install working.

It ends by running `apply.sh`, because step 7e owns the launcher entry and the
app writes its own wrong one. `--check` reports installed vs. latest and
changes nothing; `--appimage PATH` skips the download.

### keyd

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


### Hardware

**CPU power limits are the one hardware decision in this repo, and the trap is
that nothing persists them.** `ryzenadj` writes the SMU's STAPM/PPT limits at
runtime; they are lost on every reboot **and on every resume from suspend**, so
a machine tuned by hand is silently back at the firmware's 45W the next morning
with nothing on it to explain the lost performance — which is exactly what had
happened here between one session and the next. `apply.sh` step 10 installs
`ryzen-tdp.service`, whose `WantedBy` lists the sleep targets as well as
`multi-user.target`; a unit wanted only by the latter covers the reboot half and
silently misses the other.

The measured numbers, for the Ryzen 7 8745HS in the Geekom A8: 52W sustained /
58W burst gives 11379 bogo ops/s under a 90s all-core `stress-ng matrixprod`,
4474 MHz steady, 88.5 °C peak, with `PPT SLOW` drawing its full 52.00 — power-
limited, with ~3.5 °C of headroom. An earlier session measured the same chip
pinning at 92 °C and pulling *back* to 53W when asked for 54W, so the margin is
thin and ambient-dependent: the chassis is the constraint, not the silicon. No
`--tctl-temp` override is set, deliberately.

Two mechanics worth not re-deriving:

- **The live limits are world-readable, so verification needs no root.** With
  the `ryzen_smu` DKMS module loaded, `/sys/kernel/ryzen_smu_drv/pm_table` is
  `-r--r--r--` and begins with little-endian floats in the order STAPM limit,
  STAPM value, PPT fast limit, PPT fast value, PPT slow limit, PPT slow value.
  `ryzenadj --info` needs root and a live invocation; this can be read
  afterwards, by anything, which is what makes it the right check in a script.
  (It is also how a claim that "the tuning is applied" gets tested rather than
  believed.)
- **The step is gated on the machine, not just on the tool.** `/proc/cpuinfo`
  must read 8745HS and DMI must read `GEEKOM`/`A8` before anything is written.
  Everything else in this repo is cosmetic if it lands somewhere unexpected;
  pushing a 52W sustained limit onto different hardware is a thermal decision
  made by accident.

A oneshot unit that has already run reports `inactive (dead)`. That is success.
Read the SMU, not `systemctl is-active`.

**`/etc/fstab` says `compress=zstd`, not `compress=zstd:3` — and the two are the
same thing.** A bare `zstd` selects the kernel's default level, which is 3, so
`findmnt` reports `compress=zstd:3` for a line that contains no number at all.
Anything grepping for the level it sees mounted will not find it in the file.
apply.sh step 11 rewrites that to `compress=zstd:1`: level 3 costs roughly 2-3x
the CPU of level 1 at compression for ~5-10% better ratio, which is the wrong
trade here twice over -- the disk is 4% full, and the CPU is thermally capped,
so compressor watts come out of the cores. Reads are unaffected; zstd
decompression speed is essentially level-independent.

Three things about that step worth keeping:

- **A mount option is not a property of the data.** It decides what happens to
  incoming writes, so existing extents keep the level they were written at.
  `btrfs filesystem defragment -r -czstd` would rewrite them and is deliberately
  not run: on a filesystem with Snapper snapshots it unshares extents and can
  multiply disk usage.
- **Only lines whose FS-type field is `btrfs` are rewritten**, which was tested
  against the cases that would otherwise be silently wrong: a commented-out
  btrfs line, a `compress-force=zstd:5` (a different, deliberate setting), the
  same `compress=zstd` string on an ext4 line, and a line already at `:1`. All
  four come back untouched.
- **fstab is the one file in this repo whose corruption stops the machine
  booting**, so the step backs it up to `/etc/fstab.pre-cllpse`, verifies the
  result with `findmnt --verify --fstab`, and restores the backup if that fails.
  `revert.sh` reuses that backup when it is there and writes
  `/etc/fstab.pre-revert` when it is not -- two names on purpose, since a
  backup taken mid-revert is not the pre-cllpse fstab (see *A rollback has to
  read back the name the write path actually used*).
  It also bails out entirely when the machine mounts btrfs at mixed levels --
  that is a deliberate setup to leave alone, and a mixed reading is not
  something revert.sh could put back either.

## Conventions in this repo

### Conventions

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

### Chromium

**Chromium's context menu has no per-item removal mechanism, and a bare
Preferences edit doesn't reach it either** — only `/etc/chromium/policies/
managed/*.json` does. Spellcheck, translate, password-save prompt, address/card
autofill, Print, Cast, "Create QR Code" and "Add to reading
list" are all off via `overrides/chromium/policies-managed.json`, installed by
`apply.sh`'s last step (9) with `sudo install`, the one sudo step in the whole
script — deliberately last, so the single password prompt comes after every
other change has landed.
**The global-media-controls button has no pref, no policy and no feature flag
— the media session behind it is the only lever.** The music-note icon beside
the profile avatar (shown whenever any tab has an active media session) is
created unconditionally by `ToolbarView` on Linux — the one gate,
`IsWebUIMediaButtonEnabled()`, swaps in the WebUI implementation rather than
removing it — `MediaToolbarButtonView`'s visibility is only ever `Show()`/`Hide()`
from its controller, and `MediaToolbarButtonContextualMenu` offers exactly two
items ("show other sessions", "report cast issue"), neither of which hides it.
Nothing matching `GlobalMediaControls` survives as a feature name in the 152
binary either; that feature graduated and its flag was removed, so
`--disable-features=GlobalMediaControls` is inert, not a fix.

What works is `--disable-features=MediaSessionService` in
`overrides/chromium/chromium-flags.conf`: with no media session there are no
items for the controller and the button never appears. Measured in a throwaway
profile playing a looping tone, screenshotted on an empty workspace — icon
present without the flag, gone with it, rest of the toolbar identical. **It
takes MPRIS with it**, by construction: the instance drops off the bus (two
`org.mpris.MediaPlayer2.chromium` names with the service on, one with it off),
so media keys and any now-playing widget stop seeing Chromium. Page-level
playback controls are unaffected. That trade was offered and accepted; don't
re-propose the flag as a bug.

`--disable-features` is keyed by switch name exactly like `--enable-features`,
so the last-wins note above applies to it too — apply.sh step 7d now checks
both switches against Omarchy's stock file, which today carries no
`--disable-features` line at all.

**The profile avatar button, by contrast, cannot be removed at all — there is
no lever, not even a costly one.** `ToolbarView` creates `AvatarToolbarButton`
and sets its visibility from `AvatarToolbarButtonInterface::CanShowForProfile`,
which on non-ChromeOS is `IsIncognitoProfile() || IsGuestSession() ||
IsRegularProfile()` — i.e. true for every profile anyone browses in (read at
tag 152.0.7977.82, the version installed here, not just on main). No pref, no
policy and no feature flag enters that expression; the only gate above it,
`IsWebUIAvatarButtonEnabled()`, swaps in the WebUI toolbar's own avatar rather
than dropping it. The media button's trick does not transfer: that one was
*data*-driven (no media session, no button), while this one is structural.
`BrowserSignin`, `BrowserAddPersonEnabled` and the other profile policies change
what the button's menu offers, never whether it is drawn.

**DevTools is deliberately not in that list.** `DeveloperToolsAvailability: 2`
was, and it is the one key whose blast radius went past the menu — it blocks
Inspect *everywhere*, local dev servers included. It is absent now rather than
set, so Chromium's own default applies, on the principle that a managed policy
should assert only what we have an opinion about. Details in
[`overrides/chromium/README.md`](overrides/chromium/README.md).

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

### apply.sh and revert.sh

**`revert.sh` only undoes.** It never picks a font or theme. `apply.sh` records
the pre-existing font and theme once, into `~/.local/state/cllpse-macos/`,
refusing to record values that are already ours; revert restores those, or falls
back to deleting the generated `fonts.conf`.

### Cursor: settings

**Cursor `settings.json` is merged, not copied.** `apply.sh` step 7 deep-merges
`overrides/cursor/settings.json` into `~/.config/Cursor/User/settings.json` with
`jq '.[0] * .[1]'` — our keys win, every other key the user or Omarchy set stays.
It skips (never truncates) if the live file has JSONC comments `jq` rejects, and
`backup`/`restore` handle the `.pre-cllpse` round-trip. **Our file must not carry
`workbench.colorTheme`** — `omarchy-theme-set-vscode` rewrites that to `"Omarchy"`
on every `omarchy theme set` (it also installs the generated `omarchy-theme`
VS Code extension into `~/.cursor/extensions`), so a competing value just loses
the race on the next theme switch.

### Cursor: the Bearded theme

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

**Dark mode is the LIGHT scheme, derived — not a second Bearded variant.**
`workbench.preferredDarkColorTheme` still names Black & Gold Soft, but almost
nothing of it survives: `overrides/cursor/derive-dark-from-light.py` reads
Bearded Theme Light and emits two generated, committed artifacts —
`cursor/bearded-dark-colors.json` (318 workbench colours, merged by the theme
hook UNDERNEATH the chrome copy, so the frame stays Omarchy's) and
`cursor/bearded-dark-tokens.json` (55 textMate rules + 10 semantic, merged into
`settings.json` by apply.sh and scoped to the dark variant by name, so light
mode is untouched). Re-run it after a Bearded update; the scope name is read
from `cursor/settings.json`, so the variant is still named in one place.

The mapping is five rules, and each one exists because the simpler version
produced something visibly wrong:

| kind | rule |
|---|---|
| foreground | preserve the **WCAG contrast ratio** against the background, holding hue and **chroma** |
| background | mirror the **lightness delta** from the window colour |
| alpha surface | mirror the delta of what it **composites to**, then back-solve the base at the same alpha |
| alpha text | keep verbatim, unless the composite falls below 2:1 on dark |
| saturated surface | keep verbatim — an accent chip is not on the page |
| text on a chip | measured against **that chip**, not the window: verbatim if the chip didn't move, otherwise solved on the chip |
| transparent | keep verbatim, always |

**Which surface a foreground sits on decides its rule, and getting that from the
key's own lightness does not work.** The rule used to be "near-white text is on
a chip, keep it" — which misses `textPreformat.foreground`, near-*black* text on
a gold chip. Its background was held verbatim by the saturated-surface rule
while the text was lifted for contrast against the *window*, so light's
`#221b00` on `#DCC488` (10.04:1) became `#EEE7CC` on the same unchanged
`#DCC488` — 1.38:1, i.e. unreadable inline `code` in every markdown preview and
hover. `inlineEdit.gutterIndicator.*Foreground` was the same shape at 5.24:1 →
2.38:1. The derivation now resolves every background first and measures each
opaque foreground against its own sibling in a second pass.

Three things that had to be right for that not to break more than it fixed,
each caught by diffing the generated file:

- **A surface counts as a chip only past a measured distance from the window.**
  `SURFACE_MIN_RATIO = 2.0`, and it sits in an empty gap rather than on a
  judgement call: across every pair Bearded Light defines, the window's own
  shades (input, dropdown, terminal, suggest widget, peek view, inlay hints) all
  land at ≤ 1.36 against the dark window and the first real chip is a button at
  3.48, then 5.15, 5.79, 9.76. Below the threshold the page rule applies —
  which matters because only `adapt()` carries the `#DDDDDD` ceiling, so
  routing terminal, input and notification text through the chip solve put all
  of it on pure white.
- **The solve direction comes from the DARK surface, not from which side the
  light text sat on.** A near-white input field becomes a near-black one, so
  "stay on the side you were on" means dark text on a dark field — it sent
  `input.foreground` to `#000000`.
- **Only keys that really are foregrounds get a sibling.** `minimap.errorHighlight`
  joins `minimap.background` by coincidence of naming and is not drawn on it.
  `editorCursor.` and `terminalCursor.` are excluded outright: their
  `*.background` is the character drawn **on** the cursor, so the pair is
  inverted.

Five traps, all found by reading the output rather than the code:

- **An unconstrained contrast solve answers on the wrong side.** Contrast rises
  in both directions from a background, so the keyword gold came back as
  `#796100` — a correct 2.81:1, and invisible. The search has to start above the
  background's lightness.
- **Contrast preservation alone is not enough at the bottom**, because the ratio
  is not perceptually symmetric: dark-on-dark reads worse than dark-on-light at
  the same number. Hence a lightness floor of 0.42 — which is where Bearded's own
  dark variants put the same hues by hand (`#c7910c` is L 0.41), so it is not an
  invented figure.
- **HSL saturation is the wrong thing to preserve.** A near-black like the editor
  text `#091316` has saturation 0.42 while looking neutral, and carrying that up
  to a light value paints the editor pale cyan (`#CFE5EB`). Carry absolute
  chroma instead (`S * (1 - |2L - 1|)`, recomputed at each candidate lightness)
  and it stays the near-grey it looks like (`#D7E1E4`).
- **Text needs a ceiling too**, `#DDDDDD` — this repo's own dark `foreground`.
  21:1 is unreachable on `#1E1E1E`, so preserving contrast saturates near-black
  text to pure white, which is harsher than anything else on the desktop.
- **A wash is only polarity-free when its base is mid-lightness and chromatic.**
  "Alpha composites correctly on either background" holds for the teal selection
  and not for the scrollbar slider, which is `#09131626` -- a near-black at 15%,
  a grey slider on white at 1.38:1 and 1.02:1 on `#1E1E1E`, i.e. invisible. Alpha
  SURFACES therefore mirror the lightness delta of their composite and the base
  is back-solved at the same alpha, `base = (target - (1 - a) * bg) / a`, which
  put the slider at 1.60:1 (hover 1.91, active 2.73) and measured `#3F3F3F`
  against the `#1E1E1E` gutter on screen. Where the alpha is too low for the
  target to be reachable the base clamps to white and the shortfall is taken.
- **Transparent means OFF, and deriving it turns a feature on.** The light theme
  switches 19 things off with `#00000000` — `contrastBorder`,
  `editorError.border`, the diff text borders — and the first run turned 18 of
  them into opaque `#6B6B6B`. That is where outlines around every tab came from.
  The same run resurrected the scroll shadow under the tab bar, because a faint
  wash (`scrollbar.shadow` at 20%) failed a legibility test meant for text and
  was "fixed" into a solid grey bar. Shadows are now excluded from the
  derivation outright: `cursor/settings.json` zeroes six of them at the
  **unscoped** level and the hook assigns `widget.shadow` itself, and a scoped
  value beats an unscoped one, so anything emitted here would silently undo both.

**Bearded's window chrome is overridden back to Omarchy's, and since the
alignment pass that is now nearly the whole window.** Bearded steps the frame
through greys (light variant: titleBar `#d2d2d2`, activityBar/sideBar `#ebebeb`,
statusBar `#f4f4f4`) while every other window on this desktop sits on the
theme's flat window background, so the editor read as a foreign window.
`hooks/theme-set.d/cursor-chrome.sh` copies out of Omarchy's own generated
`~/.local/state/omarchy/current/theme/vscode-theme.json` (664 keys, rebuilt from
`colors.toml` on every theme-set) into `workbench.colorCustomizations`, which
sits **above** the active theme and is the only lever that reaches this short of
forking Bearded. Taking the values from Omarchy's generated file rather than
re-deriving them from `colors.toml` means there is no second derivation to
drift, and because that file is rendered from `{{ token }}` placeholders, every
value below is correct in **both** modes by construction — light was verified by
rendering the light `colors.toml` through the same template and running the
hook's jq against it, which needs no theme switch.

**The boundary is inverted from what it used to be: everything is taken except
`$KEEP`.** The old rule was a list of chrome prefixes with everything else left
to Bearded, and it left the two palettes meeting *inside* single widgets. Three
seams, all found by measuring rather than by reading the code:

- the active sidebar-toggle chip was opaque `muted` (`toolbar.activeBackground`
  is a bare `{{ muted }}`) while the active editor tab beside it was a 25% wash
  of that same colour;
- every text field was Bearded's `#202027` — a blue-tinted panel against the
  flat neutral `#1E1E1E` window — as were `dropdown`, `editorWidget`,
  `inputValidation` and the inline-chat input;
- Bearded's cyan/teal/gold turned up in accent roles on a desktop whose accent
  is `#007AFF`: `badge` `#22a5c9`, `button` `#54D7FB80`, `progressBar`
  `#bb9600`, `focusBorder` `#535C65`, `list.activeSelection` `#81AAB533`,
  `textLink` `#189BBF`, and a second, differently-coloured badge in
  `profileBadge`.

So `$KEEP` now names the editor **canvas** and nothing else — `editor.`, the
bracket/indent/whitespace/ruler/line-number/ghost-text/inlay-hint/code-lens
family, the cursor pair, `symbolIcon.` and `debugTokenExpression.` (both read as
syntax), and `editorOverviewRuler.` + `minimap*`, which have to agree with the
canvas rather than the frame. Everything else — inputs, dropdowns, checkboxes,
buttons, badges, progress bars, lists and trees, scrollbars, notifications, peek
view, settings, the welcome page, git decorations, diff and merge, **and the
integrated terminal's ANSI set** — is Omarchy's. Adding a prefix to `$KEEP` hands
a surface back to Bearded; removing one takes it over. The terminal is the entry
most likely to be re-litigated: its ANSI colours now match Ghostty and btop and
differ from the editor's own syntax palette on purpose. `$EXACT` is the escape
hatch in the other direction — `editor.background`, `editorGutter.background`
and `minimap.background` are taken *despite* `$KEEP`, because those three are
surfaces the editor sits on rather than marks drawn on it.

**One wash for every hover and active state.** Omarchy paints its own state
backgrounds at three weights and two of them are wrong next to the tab
treatment: `{{ background }}`, which is the window colour and therefore no
feedback at all (`toolbar.hoverBackground`, `list.hoverBackground`,
`button.secondaryHoverBackground`, `settings.rowHoverBackground`), and opaque
`{{ muted }}`, far heavier than anything else marking a selection
(`toolbar.activeBackground`, `commandCenter.activeBackground`,
`inputOption.hoverBackground`, `statusBarItem.activeBackground` and its compact
hover). `statusBarItem.hoverBackground` is a third weight again at 38%. The hook
rewrites all of them to the tab wash, by a mechanical test rather than a key
list: a state background is wrong if it is the window colour, or if it is
`muted` at an alpha **above** the wash's. That catches the opaque case, the 38%
case and anything Omarchy adds later.

**Five prefixes are excluded from that rule, and two of them were false
positives caught in verification.** `tab.` and `titleBar.` are surfaces (the tab
pair is derived separately, and `tab.inactiveBackground` is *supposed* to be the
window colour). The other three own a solid surface of their own, so their hover
is a relationship to **that**, not to the window: the scrollbar slider rests at
`muted` 25% and hovers at 50%, so washing the hover made hover and rest
identical and the feedback disappeared; the extension button rests at opaque
`muted` and hovers at 50%, so the wash made a hovered button *lighter* than an
idle one. `button.` is excluded for the same reason, and its one genuine bug —
`button.secondaryHoverBackground` being the window colour, i.e. a secondary
button that vanishes under the pointer — is fixed on its own terms, at the
surface's own colour plus `80`, which is Omarchy's own vocabulary for the hover
of a solid fill (`statusBarItem.prominentHoverBackground`, `.errorHoverBackground`
and `.remoteHoverBackground` are all exactly that).

**Three families Cursor registers that Omarchy has never heard of are
re-tinted, not pinned.** `inlineEdit.` (tab-completion diffs), `scmGraph.` (git
graph strands and ref chips) and `errorLens.` (the extension) have no key in the
generated theme, so nothing the copy does reaches them and they kept Bearded's
mint `#98FFAE` insertions, pink-red `#EA4D4D` deletions and five graph strands
in its own hues. Each now takes the **hue** of the matching `charts.*` colour —
the palette's own row of distinguishable hues, already copied — while keeping
**the alpha the theme gave it**, so a 15% wash stays a 15% wash and only the hue
moves. That alpha has to come from the active Bearded variant itself, which the
hook resolves through the extension's `package.json` (`label` → `path`, keyed on
the same `preferredLight/DarkColorTheme` names everything else here is keyed on);
with the extension absent the re-tint is skipped and those families keep their
own colours, exactly as before. A handful of other unclaimed ids are structural
rather than semantic and are simply assigned — `profileBadge` (a teal dot in a
window where every other badge is the accent), `multiDiffEditor`,
`diffEditor.border`, `peekViewEditorStickyScroll.background`, `button.separator`.

After the pass **no** workbench colour is off-palette: 624 keys in each scope,
487 of them straight from Omarchy, the rest either derived from those (the tab
pair, the washes, the re-tints) or assigned from `muted`. The check that says
so is worth re-running after a Cursor update, since a new release registers new
ids and an id neither palette names keeps whatever the theme gave it: list every
key outside `$KEEP` whose value is not in `colors.toml`. `button.separator` was
the last one to surface that way, at the derivation's neutral `#6B6B6B`.

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
unfocused twin, and `tab.border` are set to `#00000000`. The three bottom-edge
keys are not in `$FORCE` — they are derived from the tab background, below.
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
0 1px` ring is CSS geometry, not a colour, and out of reach of any setting.

### Cursor: tabs and edges

**With every tab edge gone, the active tab is marked by its BACKGROUND, set to
exactly what an inactive tab shows under the pointer.** Omarchy paints
`tab.activeBackground` the window colour and `tab.hoverBackground` a 25% wash of
`muted` (`#BDBDBD40` light, `#56565640` dark), so zeroing the underline on its
own would have left the selected tab indistinguishable from the strip it sits
in. The hook assigns `tab.activeBackground` from `tab.hoverBackground` (and the
unfocused pair from its own counterpart) — derived, not pinned, so it tracks the
theme's `muted`. The wash composites over `editorGroupHeader.tabsBackground`,
which is the window colour, so a selected tab renders byte-identical to a
hovered one. Transparent rather than *deleted* for the borders —
`colorCustomizations` only overrides what it names, so dropping a key hands that
slot back to Bearded instead of clearing it. VS Code reads 8-digit `#RRGGBBAA`,
which Omarchy's own generated file already relies on for its `#007AFF20` washes.

**A tab's bottom edge is painted the tab's own colour — COMPOSITED, not the
wash.** `tab.activeBorder` / `tab.unfocusedActiveBorder` / `tab.hoverBorder` are
derived in the hook as `tab.hoverBackground` flattened over
`editorGroupHeader.tabsBackground` (`#EEEEEE` light, `#2C2C2C` dark), which is
why the jq program carries hex parse/format helpers. Assigning the wash itself
would do the opposite of what it looks like: that edge is not a CSS border on
the tab but a separate `.tab-border-bottom-container` div at `z-index: 10`
drawn *over* it, so `#BDBDBD40` would composite a second time and land on
`#E2E2E2` — a visible 12/255 line. `tab.unfocusedHoverBorder` still needs no
entry; Cursor derives it as an alpha of `tab.hoverBorder`.

`#00000000` would be equally invisible and was what shipped first. Measured with
`grim` on a column straight down the active tab: rows 49-93 `#EEEDED`, with
`#F6F5F5` on row 48 *and* row 94 — the same value both sides, i.e. the
compositor's 1.25 downscale, not an edge. The derived value is what the repo
carries because it says "this edge is the tab" rather than "this edge is off",
and it survives anything later giving the element a colour of its own.

**`tab.border` is the one tab edge that is a REAL CSS border, and it is the 1px
notch on a hovered tab.** Cursor sets it inline on every tab —
`borderRight = 1px solid ${tab.lastPinnedBorder || tab.border ||
contrastBorder}` — and Omarchy paints it the window colour, which is invisible
against a white inactive tab and a white notch against one carrying the hover
wash. It is `#00000000` in `$FORCE`, not the tab colour: `.tabs-container > .tab`
sets no `background-clip`, so the default `border-box` paints the tab's own
background under its border, and `box-sizing: border-box` means the 1px is
already inside the tab's width — zero alpha shows whatever that tab happens to
be, in every state, with no reflow. Zero alpha rather than *deleting* it,
because an undefined colour falls through to `contrastBorder`; a transparent one
is still defined. `tab.lastPinnedBorder` is left alone — it marks where the
pinned tabs end, which is information.

**There is no lever for the edge's HEIGHT, and nothing to gain from one.**
`.tab-border-bottom-container` is `position: absolute; pointer-events: none;
height: 1px` — out of flow, so the tab is not 1px taller for it and nothing
shifts when it is invisible. No `*BorderWidth` or `*BorderSize` key exists in
the registry.

**Rounded tab corners are unreachable.** No `border-radius` rule touches an
editor tab in either `workbench.desktop.main.css` or `workbench.glass.main.css`
(the only `tab`-named matches are the terminal's attention dot and the
`.tab-key` chip), and the config registry has no radius or corner setting. CSS
injection is the only route, and `product.json` checksums
`vs/workbench/workbench.desktop.main.css`, so editing it raises Cursor's
corrupt-installation banner unless the checksum is rewritten too — on a
root-owned file that every `cursor-bin` upgrade replaces.

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

*Shadow token* — `widget.shadow`, and **the one value in the whole hook that
cannot be shared between light and dark**, because it is a literal rather than a
palette entry. Light is black at 14% (`#00000024`, Material's own penumbra
alpha); dark is black at 35% (`#00000059`). It is therefore not in `$FORCE` with
the others but picked in the jq from the generated theme's own `type` key —
which is the same field Omarchy writes from the theme's `mode`, so it is the
identical signal that chooses which Bearded variant is active. No second source
of truth. `cursor/settings.json`
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
takes its colour from there too. Two consequences. **A dark shadow can never
carry the light one's weight, and no alpha fixes it** — against the `#1E1E1E`
window, 14% lands at `#1A1A1A` (a 4/255 step, invisible), 35% at `#141414`
(10/255, what ships), and even pure black only reaches 30/255, against the light
theme's 36/255 at 14% over `#FFFFFF`. There are 30 levels of headroom where
light has 255. That is exactly why Material uses surface overlays on dark rather
than shadows, and why Omarchy's own generated dark value (`#1E1E1E80`, the
background at half alpha) is invisible by construction. For reference, Bearded's
own dark variants sit lower still at `#11100f30` / `#00000033`, and VS Code's
Dark Modern uses `#0000005c` — which is what the 35% here matches.
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

### Cursor: fonts and input

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

**Test files are nested, not hidden.** `files.exclude` is the obvious lever and
the wrong one: it is not explorer-scoped, so it also drops the files from quick
open, global search and the file watcher — there is no explorer-only exclude key
in the registry. `explorer.fileNesting` collapses a test under the file it tests
and leaves it fully searchable and openable, so that is what
`cursor/settings.json` sets (`enabled`, `expand = false`, and patterns for
`*.ts`/`*.tsx`). Two things about the patterns object: its values are validated
against the registry's own regex (`^([^,*]*\*?[^,*]*)(, ?[^,*]*\*?[^,*]*)*$`),
so at most one `*` per comma-separated segment; and the **registered defaults**
for the keys we name (`*.ts` → `${capture}.js`, `*.tsx` → `${capture}.ts`) are
restated in our values, which makes the result identical whether VS Code replaces
an object setting wholesale or merges it per key — so it does not matter which it
does. A test whose source has no sibling of a named extension simply stays
unnested; nesting hides nothing that has no parent (measured in `~/Sites/web`:
494 test files, a handful of them orphans of this kind, e.g. reactors that test a
behaviour rather than a file). `__snapshots__/*.snap` cannot be nested at all —
nesting is within one directory.

**Wheel speed is set in three places in Cursor, and NONE of them is set here
-- deliberately.** `editor.mouseWheelScrollSensitivity`,
`workbench.list.mouseWheelScrollSensitivity` and
`terminal.integrated.mouseWheelScrollSensitivity` are separate settings, all
registered with a default of `1`, so setting only the editor one leaves the
file tree and the terminal at the old speed -- which reads as an inconsistent
fix rather than as two settings still at their default. The editor one is
registered as `new Xoe(76, "mouseWheelScrollSensitivity", 1, e => e === 0 ? 1 : e)`,
so **zero is coerced back to 1** and cannot be used to stop wheel scrolling.
`editor.fastScrollSensitivity` / `workbench.list.fastScrollSensitivity` are a
fourth and fifth, but only while Alt is held.

All three were carried at `0.7`, then `0.67`, to cancel `input-tuning.lua`'s
`scroll_factor` (1/1.45, then 1/1.5). **They have been removed**: Cursor should
take whatever delta the compositor hands it and apply no gain of its own, so
one knob -- `input.scroll_factor` -- governs wheel speed everywhere on this
desktop, and raising it no longer means editing a second file to keep Cursor in
step. A machine that was applied before this needs the three keys deleted from
its live `settings.json` by hand: the `jq` merge only adds keys, so dropping
them from `cursor/settings.json` does not remove an already-installed copy.

Don't re-add them to compensate for the compositor. The model that would
justify it -- that `scroll_factor` reaches Electron and Cursor's sensitivity
then multiplies the already-scaled delta -- was never verified, because
`hl.dsp` has no pointer-axis dispatcher (see the keyd entry) and a scroll event
cannot be synthesized to measure against. If Cursor's wheel ever needs to
differ from the desktop's, measure the delta a client actually receives first
(a `wl_pointer.axis` logger, a fixed notch count, `scroll_factor` at two
values), because the alternative model -- Chromium reading the unscaled v120
high-resolution value and ignoring `scroll_factor` outright -- predicts the
opposite sign of correction.

**Merge into a running Cursor doesn't reliably stick.** Cursor rewrites the whole
`settings.json` from its in-memory model whenever a setting changes through the
UI, so a `jq` merge run while Cursor is open survives only until the next
in-app toggle, which reverts any key that differed from what Cursor had loaded
(`window.menuBarVisibility` was lost exactly this way). Run `apply.sh` with Cursor
closed for the merge to hold — same failure shape as the Chromium `Preferences`
trap. Panel/UI state that has no settings key (sidebar/panel open-closed, the
`cursor/unifiedAppLayout` IDE-vs-agent mode) lives in
`~/.config/Cursor/User/globalStorage/state.vscdb` and can't go in
`cursor/settings.json` at all; only the settings-backed toggles
(`workbench.statusBar.visible`, `workbench.layoutControl.enabled`,
`workbench.agentsWindowButton.enabled`, `workbench.activityBar.location`, …) can.

### Cursor: window-layout state

**Two things in `state.vscdb` are corrected by `apply.sh` anyway, because Cursor
updates flip them, and BOTH present as "the tabs have disappeared"** — with
`workbench.editor.showTabs` unset (so still `multiple`, the registered default,
checked in the bundle) and every `tab.*` colour correct, which sends you to the
chrome hook for an hour. Neither is a settings key, so `cursor/settings.json`
cannot carry either.

The two keys, what each does, and the exact Cursor code behind the -35px inset
are in [`overrides/cursor/README.md`](overrides/cursor/README.md). What
generalises: each is written **only** over the one wrong value: an absent key is
already Cursor's default and is left absent, any other value is somebody's
deliberate choice and is left alone, and the `forceUnified` latch is not cleared
— it reads as "this migration already ran", and clearing it invites the
migration to run again. `record_prior` records both so `revert.sh` can put them
back.

Both halves are gated on Cursor being closed, for the same reason the merge is:
Cursor holds that DB open and writes it from memory. **Neither `pgrep` form tests
for it** — the process *name* is `electron` (`/usr/lib/electron42/electron`), so
`pgrep -x cursor` finds nothing, and `pgrep -f` is the whole-command-line trap
below. Both scripts resolve `/proc/<pid>/exe` to an Electron binary and then match
`/share/cursor/` in that pid's `cmdline`.

**Diagnose this one by screenshotting the window, not by reading the config.**
Every config surface here reads correct in both failure modes. `grim -g "$(hyprctl
clients -j | jq -r '.[]|select(.class=="cursor")|"\(.at[0]),\(.at[1]) \(.size[0])x220"')"`
settles in one shot what an hour of grepping `settings.json` cannot — and note
`grim` can only capture the **visible** workspace, so a window on an inactive one
comes back as whatever is actually on screen, with no error.

### ytm-player

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

### Window frames and BUILD.md

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

### Shell and tooling

- **`awk -v close=...` is fatal** — `close` is a gawk builtin. It failed silently
  mid-pipeline and truncated the target file to zero bytes. Test any script that
  rewrites a real config against a harness first.
- **`Style.qml`'s trailing size comments are base-12 annotations, not sizes.**
  `heading: fontToken("heading", fontPx(1.333)) // 16` reads as "16px", but
  `fontPx(mult) = round(fontBaseSize * mult)`, so the number depends entirely
  on the live base. Worked through at `base-size = 14`: heading 19, body 14,
  `iconLarge` 21, `display` 28 — and at 13 those become 17, 13, 20, 26, which is
  the point. Compute against the live base, never quote the comment and never
  quote this example either. Check it with `omarchy display text size`.
- **Size from a token, not a multiple of one.** Every `Style.font.*` value is
  already rounded, so scaling one rounds twice and lands on numbers that drift
  off the scale as base-size moves (`iconLarge * 1.4` → 25/29/34/38 px at base
  12/14/16/18, versus `display` → 24/28/32/36). `Style.space(px)` is the same
  deal for geometry — it scales by `spacingScale * fontScale`, so pass the
  base-12 pixel value and let it scale.
### Hyprland

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
- **Blur costs area, not passes — and the parameters are not a lever.** Measured
on Hyprland's own `drm-engine-gfx` (10s samples, medians of three interleaved
runs, animating scene): `size 28 / passes 2` costs 16.61% against `size 7 /
passes 4`'s 16.60%, and `xray` changes nothing either. `new_optimizations`
caches the static background, so what is paid for is the damaged **area** being
blurred. The only lever is therefore what is translucent: `blur.ignore_opacity`
is true, so the focused window at `0.99` has a full blur pass rendered under it
— the largest, most-damaged surface on screen — to show 1% of the wallpaper.
Making it opaque takes the compositor from 15.1% to 13.0% against a 10.8%
blur-off floor, i.e. ~60% of the blur bill, for a difference two full-screen
captures put at 1.3% of pixels (nearly all of it text that scrolled between the
shots).

  **That was measured, offered and turned down: the `0.99` stays.** The frosted
  material is meant to be what a window *is* here, not a state it enters when it
  loses focus, and this machine has the headroom to pay for it. Don't re-propose
  it as an optimisation, and don't go looking for a cheaper blur kernel either —
  there isn't one. The same goes for the per-app rules the opacity work touched
  on the way past (Figma's `1 1`, the browser re-match): those are deliberate and
  are not tuning surface.

Two things that make this measurable at all: Hyprland's `/proc/<pid>/fdinfo/*`
carries `drm-engine-gfx` in nanoseconds, which isolates the compositor from
whatever the apps are rendering (`gpu_busy_percent` is global and useless here);
and the scene has to be genuinely constant, so interleave the configurations and
take medians — a first pass over a playing video produced a 0% read and a 48%
outlier before the scene settled.

**Blur only shows through what a surface leaves translucent.** At
  `background-alpha` 0.92 barely 8% of the backdrop shows, so widening the blur
  radius there is close to invisible; `background-alpha` is the stronger lever.
  Taken to its conclusion: every `shell.*.toml` here now ships
  `background-alpha = 1.0`, so the `hl.layer_rule { blur = true }` in
  `overrides/hypr/looknfeel-decoration.lua` is **entirely inert** — the only
  thing `decoration.blur` still reaches is the unfocused window at 0.875. The
  rule is kept because it is the whole cost of re-enabling glass later; the
  number to watch when doing that is its `ignore_alpha = 0.6`, which splits
  cards (above) from scrims (below, currently 0.25).
- **`macos-*` Ghostty keys are no-ops on Linux.** `macos-titlebar-style`,
  `macos-window-buttons`, `macos-icon` and friends are read only on macOS. A
  config full of them looks configured and does nothing.
### App configs

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
### Chromium

- **A repeated `--enable-features` is last-wins, not merged, and the loser
  vanishes silently.** `base::CommandLine` keys switches by name, so a second
  `--enable-features=` line in `~/.config/chromium-flags.conf` replaces the
  first outright rather than adding to it. Our fenced block is appended, which
  makes it always the last one, so it has to restate whatever Omarchy's stock
  line asks for (`TouchpadOverscrollHistoryNavigation` today). Measured both
  ways round against `OverlayScrollbar`: ours last, the scrollbar overlays;
  Omarchy's last, it comes back. Nothing keeps the two in step, so apply.sh
  step 7d diffs the stock line against ours and says so if Omarchy ever adds a
  feature the block is missing — for `--disable-features` as well, since it is
  the same switch machinery and our block carries one of those too
  (`MediaSessionService`). Omarchy ships no `--disable-features` line today, so
  that half of the check is a tripwire rather than a live comparison.
- **A browser setting that lives only in the profile is not a setting this repo
  has, and its loss leaves nothing behind to explain itself.** Two of them went
  missing here at once — the overlay-scrollbar `chrome://flags` toggle (which is
  `browser.enabled_labs_experiments` in `~/.config/chromium/Local State`, and
  came back as absent, with the running process carrying no `--flag-switches-begin`)
  and the browser theme. Both had been set by hand, neither was reachable from
  `apply.sh`, and the symptom was "the fix we made is gone" with no mechanism in
  sight. Anything set through a browser's own UI belongs in the flags file or in
  a `Preferences` writer before it counts as fixed.
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
### Language gotchas

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
### Images, icons and glyphs

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
- **An icon drawn from a file matches a glyph beside it only when the two agree
  where the ink stops — and the fix belongs in the FILE, not in a ratio at draw
  time.** A text glyph at `pixelSize` N fills close to N. While drop-ins were
  rasters, `app-icons.sh` trimmed each mark into 200 of 256 px, so it filled 78%
  of whatever box it was given, and the switcher compensated with an
  `iconSize * 256/200` box (measured: 27px of ink against a glyph's 33, 35
  after). That factor was right for a PNG and wrong for an SVG — the vector
  branch only recoloured, so a simple-icons source arrived edge-to-edge and the
  same compensation drew it 28% oversized, overflowing and clipping. Both halves
  are gone: `icons/` is SVG-only, every drop-in is edge-to-edge in a **square
  `viewBox`**, and `Hud.qml` draws the Image at `iconDrawn` — `iconSize * 0.9`, a
  flat optical trim with no ratio in it. Don't re-add a compensation factor;
  square the file's viewBox instead.
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
### Processes, packages and permissions

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
- **"Not in Omarchy's `.packages` lists" does not mean AUR, and guessing cost a
  wrong install command in the README.** Those two files
  (`/usr/share/omarchy/install/omarchy-{base,other}.packages`) list what Omarchy
  itself installs — they are not a census of Arch. A package absent from them
  can still be in `extra` (`msedit`, `keyd`, `ghostty`, `yazi`, `lsd`,
  `python-secretstorage`, the whole `qmk`/`avr-*` toolchain) or in the
  **`omarchy` binary repo**, which is a configured pacman repo on this machine
  alongside core/extra/multilib and is where `cursor-bin` comes from. Only
  `bibata-cursor-theme-bin` and `ytm-player` are genuinely foreign here. The
  checks are `pacman -Si <pkg>` for the `Repository:` line and `pacman -Qqm`
  for the actual AUR set; absence from a list is not one.

  The audit those lists *are* good for is the other direction — what this
  machine has that Omarchy did not put there:

  ```bash
  comm -23 <(pacman -Qqe | sort -u) \
           <(cat /usr/share/omarchy/install/*.packages | sed 's/#.*//' \
             | tr -s ' \t' '\n' | sed '/^$/d' | sort -u)
  ```

  README.md's *Everything else installed here* is that output, grouped, and is
  meant to reconcile to zero against it.
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

- **Three lists have to agree about the theme-set hooks, and nothing made
  them.** Each `overrides/<app>/<app>.sh` symlinks its own hook into
  `~/.config/omarchy/hooks/theme-set.d/`, `revert.sh` removes it, and
  `hooks/post-update.d/cllpse-macos-repair.sh` re-links it after an
  `omarchy update` repopulates that directory (Omarchy's territory -- see
  *Hooks and plugins*). That is one set enumerated in three places, each
  written next to a different concern, and two of them had silently fallen
  behind: `revert.sh` removed six of seven (no `gh-dash-colors.sh`) and the
  repair hook re-linked five (no `gh-dash-colors.sh`, no `ytm-player.sh`, and
  not ytm's `themed/ytm-player.toml.tpl` either). Both failures invert the
  script's own purpose rather than merely omitting something: a hook left
  behind by revert still points into this repo, which revert does not delete,
  so the next `omarchy theme set` -- any theme, not just ours -- repaints the
  config revert just restored; and an update quietly stops two apps tracking
  the theme while the other five self-heal. Same shape as the entry above, so
  keep the check rather than the conclusion:

  ```bash
  cd overrides
  inst=$(grep -rhoP 'ln -sfn "\$HERE/hooks/theme-set\.d/\K[a-z-]+\.sh' */*.sh | sort -u)
  rep=$(grep -oP 'theme-set\.d/\K[a-z-]+\.sh' hooks/post-update.d/cllpse-macos-repair.sh | sort -u)
  rev=$(grep -oP 'rm -f ~/\.config/omarchy/hooks/theme-set\.d/\K[a-z-]+\.sh' revert.sh | sort -u)
  [[ $inst == "$rep" && $inst == "$rev" ]] && echo agree || printf '%s\n---\n%s\n---\n%s\n' "$inst" "$rep" "$rev"
  ```

  The template symlinks are **not** in that check and have to be eyeballed:
  ytm is the only app whose hook needs a second link outside `theme-set.d/`
  (`~/.config/omarchy/themed/ytm-player.toml.tpl`), which is exactly why it
  was the one the repair hook missed.

- **A rollback has to read back the name the write path actually used.**
  `revert.sh`'s btrfs step backs `/etc/fstab` up only when `apply.sh`'s
  `/etc/fstab.pre-cllpse` is absent -- and wrote that fresh backup as
  `/etc/fstab.pre-revert`, while the `findmnt --verify` failure branch below
  it restored from `.pre-cllpse`. So in the one branch where the backup was
  taken, the rollback looked for a file that by construction did not exist,
  guarded by `[[ -e ... ]] &&` so it failed silently and left the rejected
  fstab in place -- the precise corruption the surrounding comments say the
  step exists to prevent. The two names are still both right (a backup taken
  mid-revert is not the pre-cllpse fstab and must not claim to be); what was
  wrong was hardcoding one of them twice. It records the chosen path in a
  variable now. Grep a recovery path for the literal it restores and check the
  write path can actually produce it.

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

## Extracting a sub-repo

The window switcher moved to `omarchy-cllpse-plugin-switcher/` — a submodule here, a
public repository of its own — and was prepared for release. Most of what
follows was not *introduced* by that split; the split is what made it visible.

- **Only enumeration finds the couplings.** From inside this repo the plugin
  looked self-contained, and reading its docs said so. Listing every absolute
  path in its code found the one that mattered: `~/.icons/cllpse-flat/apps/`,
  read by its icon index and documented in no file anywhere. It degrades
  correctly when absent, so nothing ever failed loudly enough to notice. The
  same shape turned up three more times — `apply.sh` gating the whole app-icons
  hook on `icons/icons/`, `app-icons.sh` justifying its own design on
  switcher behaviour that had been deleted, and 75 icons duplicated across both
  repos. Grep for the mechanism (paths, commands, imports), not for the concept.
- **A hidden dependency is fixed by naming it, not always by removing it.**
  `cllpse-flat` stayed — it is optional and harmless — but it became documented,
  and the property stopped being called `legacyIconDir`, which described neither
  what it is nor why. A personal name leaking into a public plugin is tolerable;
  a silent one is not.
- **Comments outlive the mechanism they describe, and they are read at the worst
  possible moment.** Eleven blocks in `Hud.qml` still described an `icons/flat/`
  vs `icons/color/` split, a draw-time recolour and a `c`/`t` tagging scheme,
  all removed. A stale README misleads a reader; a stale comment misleads the
  person about to edit that function, and every one of those was an argument for
  reintroducing colorization. When you delete a mechanism, its comments are part
  of it.
- **"Missing" gains a second meaning the moment the source is a submodule.** An
  absent `COLOR_IN` used to mean "these marks were deleted, clear the output".
  It now also means "`git submodule update --init` has not run", and the
  existing code would have wiped 75 working icons over it. That needs a
  *discriminator* — `manifest.json` — not a better guess.
- **Skipping is not exiting.** The first version of that guard was `exit 0`,
  which would have taken down the flat pass as well: a different icon set, from
  a different directory, with no relation to the submodule. That is exactly the
  coupling the surrounding comments exist to prevent. Re-reading *why* the code
  was shaped that way is what caught it.
- **Prove standalone by running it, not by reading it.** Clone from the **remote**
  rather than locally — that is what catches files that exist only on your disk —
  then delete the dependency outright (`~/.icons/cllpse-*` moved aside) and boot
  it. Shell loaded clean, three global shortcuts registered, HUD layer mapped,
  and every live window still resolved an icon from the plugin's own set.
- **Run a control before reporting a regression.** Driving the switcher with
  `hyprctl dispatch global` opens and immediately closes it. That looked like a
  standalone failure until the same dispatch did the same thing with the
  original setup restored. It is the artificial input path — the real one holds
  `SUPER` and polls. Without the comparison the report would have been wrong.
- **Verify the mechanism, not the intention.** `magick -trim` trims by *corner
  colour*, so on a mark with a background it reports the inner shape — which is
  how `hunk` lost its cream box; alpha extent is the real measurement.
  `git checkout` on an untracked file silently does nothing, so a "revert" left
  broken JSON in place. A blanket rename turned `badge-aliases.json` into
  `processIcon-aliases.json` in four places including a runtime path. The
  counter-practice: assert the doc against reality — Ghostty measured at the
  99% x 100% its `AGENTS.md` claims, all 75 icons checked against the documented
  scaling contract, the alias table cross-checked 15/15 in a script.
- **A `.json` file with comments is not JSON.** `icon-aliases.json` documented
  itself in a 25-line `//` header that worked only because the parser stripped
  those lines first — a private dialect wearing a `.json` extension, which any
  formatter or `jq` run would reject. Moving the prose to the README forced a
  second rule, because a mapping can no longer explain itself in place: adding
  one now requires documenting it in that table.
- **Inherited files do not inherit their terms.** The submodule took 75
  third-party marks along with a blanket MIT statement. Whether to carve that
  out is a decision to *make*, not to skip — here the notices were deliberately
  removed.
- **Measure before a bulk pass.** The `hunk` damage came from one run without
  measuring. The WebP conversion is the corrected instinct: pilot three files
  (PNG -35%, JPG -31%, HEIC **+22%**), check the 16383px limit, check basename
  collisions, confirm `omarchy-theme-set` already enumerates `*.webp` — then
  convert, verify all 60 at zero differing pixels, and only then delete an
  original.
- **`git add -A` is unsafe in a tree holding someone else's uncommitted work.**
  Used here while 76 wallpaper changes sat unstaged. It happened to be clean —
  verified after the fact that no commit touched them — but that was luck.
  Stage by explicit path in a repo you share.

### Extracting the themes taught different things

- **A standard-installed theme cannot carry compositor config, and that decided
  the design.** `omarchy theme install` git-clones into
  `~/.config/omarchy/themes/`, and `omarchy-theme-set:204` calls a theme
  repo-installed when `[[ ! -L $source && -d $source/.git ]]` — staging no
  `.lua` from one, because it runs in the compositor. The decoration was moved
  into both themes, worked live on theme switch, and had to be reverted: it only
  applied while the theme was SYMLINKED, which is not how anyone installs a
  theme. What a theme can reach Hyprland-side is `default/themed/
  hyprland.lua.tpl` — four lines of border colour, rendered from `colors.toml`.
- **Verify the install path, not just the mechanism.** "A theme can carry
  `hyprland.lua`" was true and useless. The question worth testing first was
  "does it survive the way people install it", and the answer was no.
- **A repo name is not the installed name.** Omarchy strips a leading
  `omarchy-`, so `omarchy-cllpse-theme-dark` installs as `cllpse-theme-dark`.
  Documented in each theme, because a theme arriving under a different name than
  the one you typed reads as a bug.
- **Renaming a submodule is four places, not one.** `git mv` moves the path and
  fixes `core.worktree`; the `.gitmodules` section name, the `.git/config`
  section, and `.git/modules/<name>` with the submodule's own `.git` file
  pointing into it all stay behind. Legal, but it leaves the next reader
  guessing which name is authoritative.
- **Rename by anchor, never by substring.** `omarchy-window-switcher-hud` is a
  Wayland namespace matched in seven places across two repos and reads exactly
  like the repo name that was being renamed. Anchoring every replacement on
  `cllpse/` is what kept it out; it was counted before and after.

## Reproducing this on another machine

`apply.sh` is deterministic and idempotent for what it controls, but it is not a
full machine build — it installs no packages, no third-party plugins,
`display/display.conf` carries values tuned for one specific display, and step 10's CPU
power limits are measured for one CPU in one chassis (gated on both, so they are
inert elsewhere rather than wrong elsewhere). Several
settings only take effect after a relogin. `overrides/README.md` has the full
list under *What apply.sh does and does not guarantee*; read it before assuming a
clean install ended up identical.

## Still open

- `revert.sh`'s restore paths have unit-tested helpers but have never been run
  end-to-end; that needs a spare machine or VM, not this one.
- Whether Hyprland's `input.scroll_factor` reaches an Electron client at all is
  still unverified — it decides whether a Chromium-based app needs a
  counter-gain or none. Nothing depends on the answer today (Cursor now sets no
  sensitivity of its own), but it is the measurement to take before anyone
  re-adds one: log `wl_pointer.axis` deltas for a fixed notch count at two
  values of `scroll_factor`. `hl.dsp` has no pointer-axis dispatcher, so the
  scroll has to be a real one.
