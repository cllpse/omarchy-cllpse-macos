# omarchy-cllpse-macos

Two Omarchy 4.0.4 themes (`quattro` branch) reproducing the macOS appearance, plus
machine-level overrides and two plugins: a window switcher and a launcher.
**`master` is stale at 3.8.5** and documents an incompatible theme format — do
not read it.

**Both plugins are submodules:** `omarchy-cllpse-plugin-switcher/` →
[cllpse/omarchy-cllpse-plugin-switcher](https://github.com/cllpse/omarchy-cllpse-plugin-switcher),
and `omarchy-cllpse-plugin-supermenu/` (SUPER+SPACE) →
[cllpse/omarchy-cllpse-plugin-supermenu](https://github.com/cllpse/omarchy-cllpse-plugin-supermenu).
Clone with `--recurse-submodules`. Edits to `Hud.qml` or `Supermenu.qml` require
commits in that repo plus a submodule pointer bump here — two commits, not one.

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

A window showing a playing video gets a `video-playing` tag at runtime (`1 1`),
set by a Lua checker in `looknfeel-decoration.lua` from Hyprland's
idle-inhibit flag; Hyprland has no event for that flag. Probe:
`hyprctl clients -j | jq '.[] | {class, inhibitingIdle, tags}'`.

### GTK 4.24 opts every GTK4 window out of blur

GTK 4.24 attaches an `ext-background-effect-v1` object to every surface and
sends an empty blur region unless a widget has `backdrop-filter: blur()`.
Hyprland 0.56 obeys that object ahead of `decoration:blur` and every window
rule, so an empty region means no blur. Changing the blur settings does
nothing. Chromium and Electron don't use the protocol. `hyprland-env.lua` sets
`GDK_WAYLAND_DISABLE=ext_background_effect_manager_v1` so GTK never binds it.
It is read when a process starts, so a running Ghostty keeps blur off until its
last window closes. Re-check Hyprland's `shouldBlur` on a bump: if it falls back
to the config on an empty region, the variable can go. Probe:
`tr '\0' '\n' < /proc/$(pgrep -xo ghostty)/environ | grep GDK_WAYLAND_DISABLE`

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

### Superset's Changes-tree icons are patched inside its `app.asar`

Its sprite builder strips each Material SVG's root tag, so seven icons whose
root is `fill="none"` (`readme`, `changelog`, `diff`, `log`, `lib`, `document`,
`settings`) inherit the row's status colour for a stray `<path d="M0 0h24v24H0z"/>`
and draw an opaque square. `apply.sh superset` swaps that path for a
same-length XML comment (14 places, no repack); `revert.sh` swaps it back. An
app update replaces the asar and the square returns: run the step again. Never
patch it in place, a running Superset reads the file by offset. Probe:
`npx @electron/asar extract-file ~/Applications/superset/resources/app.asar dist/renderer/file-icons/readme.svg`
See `overrides/superset/README.md`.

### SF ships unhinted; hinting reaches it only through the autohinter

Apple's SF Pro and SF Mono carry no hints at all, so for these CFF fonts
`hintslight` and `hintnone` render identically. `99-cllpse-macos-autohint.conf`
forces FreeType's autohinter for the three SF families. Qt Quick takes it only
because `QML_DISABLE_DISTANCEFIELD=1` (`hyprland-env.lua`) replaces its
distance-field text. Chromium and Electron above device scale 1 set hinting to
none themselves, unless started with `--disable-font-subpixel-positioning`:
`chromium-flags.conf`, `overrides/font-flags/` (Chrome, Electron apps) and
`figma.sh` (Figma's launcher) add it. Hinting a TTF build (`ttfautohint`) does nothing at slight:
FreeType autohints TrueType there regardless. Probe:
`fc-match -v 'SFProText Nerd Font Propo' | grep autohint`. See
`overrides/fontconfig/README.md`.

### `flea --default` takes Cmd+Shift+F

Flea (AUR `flea-bin`) is the file manager. Its own `flea --default` appends a
keys block to the **end** of `bindings.lua` that rebinds SUPER+SHIFT+F (our
Cmd+Shift+F → Ctrl+Shift+F forward) and SUPER+ALT+SHIFT+F (allowlist-pruned).
It lands after our fences, so it wins on file position and the allowlist cannot
prune it. Flea's Settings ▸ About switch runs the same command. `apply.sh flea`
does the rest of `--default` itself, removes that block and binds Flea to
SUPER+ALT+SPACE. Probe: `grep -n 'flea --default: begin' ~/.config/hypr/bindings.lua`.
See `overrides/flea/README.md`.

### Chromium's theme is a policy-forced extension, swapped on theme set

Not Omarchy's `BrowserThemeColor` seed: `zz-cllpse-macos-theme.json` masks it
(the policy file that sorts last wins a key) and installs a light and a dark
theme CRX from `/usr/local/share/cllpse-macos/chromium-theme/`, plus a forced
switcher extension that enables the one named in its `3rdparty` policy. The
theme-set hook rewrites that mode through a passwordless, root-owned writer
(`apply.sh chromium-theme`, step 9b). Never flip a theme's
`installation_mode` to switch: forced and optional are different install
locations, so Chromium reinstalls both, raises the "Installed theme" bar and
applies whichever installed last. A `colors.toml` change needs that step again (repack
plus sudo). Applying any extension theme deletes `browser.theme.user_color2` /
`is_grayscale2` / `color_variant2`, so the blue menu separators and omnibox
selection (`#D3E3FD`, Chromium's palette) cannot be fixed alongside it. Probe:
`jq -r .extensions.theme.id ~/.config/chromium/Default/Preferences`. See
`overrides/chromium-theme/README.md`.

### The TV's DSC bit rate is a debugfs override, set again at every boot

amdgpu sizes the 4K120 stream by the TV's HDMI DSC rules (12 bpp, 2:1), though
the VMM7100 adapter is what decodes it. `apply.sh dsc` installs
`cllpse-dsc.service`, which forces 20 bpp through amdgpu's
`dsc_disable_passthrough` + `dsc_bits_per_pixel` debugfs files. Those live in
RAM per connector, so only a reboot loses them. While it is set, 4K144/165
exceed the link and amdgpu rejects the modeset: `sudo cllpse-dsc-bpp off`
first. A *saved* 165 needs the unit disabled as well: the boot run sets 20 bpp
at the console's 4K60, before Hyprland picks its mode. That is the state since
2026-10-24 (165, amdgpu's 12 bpp, unit disabled). Never `echo` into `dsc_disable_passthrough`: its handler returns 0 bytes
written, so `echo` retries forever as a root process. Probe:
`sudo cllpse-dsc-bpp status`. See `overrides/dsc/README.md`.

### The two plugins cancel each other over Hyprland's event socket

Opening either one sends `hl.dsp.event("overlay-open>><plugin id>")`, which
reaches every client as `custom>>overlay-open>><id>`. Whichever is open closes
on an id that is not its own, so the last one opened wins. Neither plugin names
the other, and Omarchy's shell has no bus for this: a plugin can only summon or
hide itself. Change the event string in both repos or in neither. Probe:
`hyprctl dispatch 'hl.dsp.event("overlay-open>>x")'` closes whichever is open.

## Unreachable on 4.0.4 — don't re-litigate

These were checked against 4.0.4, not carried forward. The probes are named so
the next bump is a re-run.

- **Bar font family:** `Style.qml` hardcodes `fontFamily = "monospace"`. Cannot
  be done through config. Probe:
  `grep -n fontFamily /usr/share/omarchy/shell/Commons/Style.qml`

- **Bar-only text/icon sizing:** `[bar] icon-font` / `icon-slot` /
  `icon-canvas` / `status-slot` are read by `Style.bar` but never populated
  by `applyShellValues` — dead keys.

- **The whole `[launcher]` section** is a dead section. Omarchy's SUPER+SPACE is
  the **menu** plugin (`omarchy-menu`), so `shell.menu.toml` styles it — and
  here SUPER+SPACE is the supermenu, which binds the same `Color.menu` tokens. The
  `shell.launcher.toml` files are spliced into `shell.toml` and read by nobody.

- **A third-party `menu` plugin never gets the shell's app library.**
  `shell.qml`'s `manifestHasKind()` tests `Array.isArray(manifest.kinds)` on a
  manifest that has been through the panel loader's Instantiator, which turns
  the array into a V4Sequence (`indexOf` works, `Array.isArray` is false). The
  supermenu runs its own `AppLibrary` instead. Probe:
  `omarchy-shell shell call cllpse.supermenu stats "" | jq .sharedAppLibrary`

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

### XML comments cannot contain `--`

fontconfig then skips the whole drop-in and reports it only on stderr, which
`fontconfig.sh` silences. A flag name quoted in a comment is enough: it
turned the SF autohint off from 2026-10-23 to 24. `xmllint --noout` catches it.

### Rewriting an installed font in place crashes the apps that map it

`cp` over an existing file keeps its inode, and every running app that has the
face memory-mapped reads the new bytes under the old offsets: Ghostty died in
FreeType's autohinter the second the rebuilt SF Pro landed (2026-10-24).
`fonts.sh` uses `cp --remove-destination`, so the old file stays valid for
whoever has it open. Probe: `grep '(deleted)' /proc/$(pgrep -x quickshell)/maps`
lists faces a process still reads from a replaced file.

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

### Quickshell `PanelWindow` with no `screen` dies with a transient output

A modeset that drops the link (a scale change on the TV) leaves Hyprland with
only its `FALLBACK` output for a few seconds. Unbound layer surfaces get
recreated there and die with it. Bind them with a `Variants` over
`Quickshell.screens` and `screen: modelData`, as `Bar.qml` does. Probe:
`hyprctl layers | grep omarchy-window-switcher-corner`

### A layer surface that took the keyboard must let go by unmapping

Hyprland 0.56.2 keeps an `Exclusive` layer on its exclusive list until a
commit setting `None` is applied, and Quickshell sends that only with the
surface's next frame. While it is listed, closing another layer hands the
keyboard to it, invisibly. The supermenu's keystroke catcher unmaps instead.
Separately, keys typed in the ~5-30 ms a focus change takes are discarded by
fcitx5 when the window left had an input method active (upstream). Details
and probes: `omarchy-cllpse-plugin-supermenu/AGENTS.md`.

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
Set it to `drawn × Screen.devicePixelRatio`, not the output scale. It was 2
when measured, at output scale 1.25 (2026-10-12 to 16; 1.33333 on 2026-10-08
to 10 and 2026-10-11 to 12). The output is at scale 1 since 2026-10-16, where
it should be 1; not re-measured.

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
| Supermenu ranking, invariants, traps | `omarchy-cllpse-plugin-supermenu/AGENTS.md` |
| Task patterns for agents | `AGENTS.md` (this dir) |
| Per-app override details | `overrides/<app>/README.md` |
| How the SF fonts are built from Apple's DMGs | `overrides/fonts/README.md` |
| The TV's DSC bit rate: why 12 bpp, how 20 is forced | `overrides/dsc/README.md` |
| Chromium theme extension: design, mechanism, Chromium source findings | `overrides/chromium-theme/README.md` |
| Window switcher design log | `reference/window-switcher-notes.md` |
| Keybind parity audit | `KEYBINDS-PARITY.md` |

