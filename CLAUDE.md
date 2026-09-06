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

**Helium** (Chromium fork, extracted AppImage at `~/Applications/helium/AppRun`)
is the counter-case where `environment.d` has nothing to offer. `apply.sh` step
7e wants it on the same `--force-device-scale-factor=1` + 110% zoom pairing as
system Chromium (7d), but: there is *no env var* for the device scale factor,
and Helium's `AppRun` is not the `chromium-flags.conf`-reading C stub that Arch's
`/usr/bin/chromium` is — it just `exec`s the binary. So the flag is injected
into the three `Exec=` lines of `~/.local/share/applications/helium.desktop` in
place, guarded by an `is the flag already there` grep; `revert.sh` strips exactly
that substring and keeps the file (it is Helium's, only edited). Re-extracting
the AppImage can rewrite that `.desktop` without the flag — a re-run of
`apply.sh` re-injects it. No ozone flag is needed: Helium picks up
`OZONE_PLATFORM=wayland` from the session env and already runs Wayland (verified
in its process list), which is the part Omarchy's stock `chromium-flags.conf`
does for system Chromium. The zoom half is the *same* profile preference
(`partition.default_zoom_level`), so `overrides/chromium/default-zoom.py` is
reused unchanged, pointed at Helium's profile tree / binary name through the
`CLLPSE_ZOOM_{CONFIG_DIR,BINARY,LABEL}` env vars.

**Brave Origin** (`brave-origin-bin`, AUR — another Chromium fork) is the easy
case by contrast: `/usr/bin/brave-origin` *is* a flags-file launcher (a bash
script — reads `~/.config/brave-origin-flags.conf` one flag per line, skips
`#`/blank, execs `/opt/brave-origin-bin/brave`), so step 7f fences
`--force-device-scale-factor=1` into that file exactly like 7d does for
`chromium-flags.conf`, no `.desktop` edit. Two things to know: (1) the flags
file must pre-exist — it also holds the `--ozone-platform=wayland` lines that
put Brave on Wayland here (Brave does *not* fall back to the env var the way
Helium does), so 7f fences into it but refuses to create it; (2) the zoom
script's `BINARY=brave` is-it-running check also matches a running stock **Brave
Browser** (`~/.config/BraveSoftware/Brave-Browser`), which at worst defers the
write with a "quit it" message. Profile tree is
`~/.config/BraveSoftware/Brave-Origin/` (siblings `Brave-Browser{,-Beta,-Nightly}`
are the regular channels — leave them alone).

**Chromium's context menu has no per-item removal mechanism, and a bare
Preferences edit doesn't reach it either** — only `/etc/chromium/policies/
managed/*.json` does. Spellcheck, translate, password-save prompt, address/card
autofill, DevTools/Inspect, Print, Cast, "Create QR Code" and "Add to reading
list" are all off via `overrides/chromium/policies-managed.json`, installed by
`apply.sh` step 7g with `sudo install`, the one sudo step in the whole script.
That step only writes if `/etc/chromium/policies/managed/` already exists,
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
the race on the next theme switch. The file is kept to stock-Cursor keys — no
setting in it depends on a marketplace extension (`iconTheme`, GitLens/Copilot
keys and the Biome / ESLint per-language formatters were all stripped), and it
sets no `editor.fontFamily` / `editor.fontWeight`: Cursor's default stack ends in
`monospace`, which fontconfig resolves to SF Mono (from `omarchy font set`), so
the editor inherits the system monospace without Omarchy writing a font key into
Cursor — it never does, `omarchy-theme-set-vscode` only touches `colorTheme`.
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
- **Omaland**, if installed, writes its own `hl.animation` block into the same
  `looknfeel.lua` and wins by file position. Accepted — our block exists to be
  self-sufficient on a machine without it.
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
