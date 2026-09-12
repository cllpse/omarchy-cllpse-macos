# omarchy-cllpse-macos

[Omarchy](https://omarchy.org) themes reproducing the macOS system appearance,
built against [`reference/BUILD.md`](reference/BUILD.md). Seeded from the stock
**Last Horizon** theme.

Two themes — Omarchy has no runtime light/dark toggle, each theme is one mode.
Both live under `omarchy-cllpse-theme/`:

| Folder | Omarchy name | `mode` | Palette |
|---|---|---|---|
| `omarchy-cllpse-theme/omarchy-cllpse-theme-dark/`  | **omarchy-cllpse-theme-dark**  | `dark`  | BUILD.md §1 (macOS 27 `NSColor` → sRGB) |
| `omarchy-cllpse-theme/omarchy-cllpse-theme-light/` | **omarchy-cllpse-theme-light** | `light` | BUILD.md §2 |

## Before you run this

Built against **Omarchy 4.0.2** (`quattro`). The `master` branch is stale at
3.8.5 and uses an incompatible theme format — this will not work there.

`apply.sh` is idempotent and installs no packages, and it makes no decisions
about your hardware. One step needs sudo — the last one, the Chromium managed policy —
and everything else is user-level. Six things to settle first; everything after
them can be handed to an agent.

**1. Clone it where it will live.** `apply.sh` symlinks the two theme folders
into `~/.config/omarchy/themes/` and the window-switcher plugin into
`~/.config/omarchy/plugins/`, all pointing at this checkout. Moving or deleting
the clone later breaks the themes and the switcher.

**2. Install what `apply.sh` can't.** It installs nothing at all — no packages,
no `gh` extensions, no `mise` tools. These are the ones a stock Omarchy box does
*not* already have:

```bash
sudo pacman -S lsd ghostty yazi keyd python-secretstorage msedit
sudo pacman -S cursor-bin                        # the `omarchy` repo, not `extra`
yay -S bibata-cursor-theme-bin ytm-player        # AUR — pacman -S will NOT find these two
mise use -g hunk gh
gh extension install dlvhdr/gh-dash
```

Plus two Cursor marketplace extensions, `beardedbear.beardedtheme` and
`beardedbear.beardedicons`. The table at the top of
[`overrides/README.md`](overrides/README.md) is the authoritative list and says
what each one is for and **how it fails if you skip it** — worth reading, because
only some are guarded and the failures do not look alike.

`bibata-cursor-theme-bin` is the one that matters most: the cursor theme is set
in `gsettings` and `hl.env` **whether or not the package is present**, so without
it you get a fallback cursor and only a warning in the output. `lsd` degrades
quietly — missing, it just skips the `ls` alias and its theme files.

What genuinely *is* already there on an Omarchy box: `bat`, `lazygit`, `fzf`,
`starship`, `lazydocker`, `jq` and `imagemagick` are in `omarchy-base.packages`;
`lua` (the keybind scan, step 6b) and `python3` (the Chromium zoom, step 7d)
arrive as dependencies of `hyprland` and of much of the rest of the system.
`lua` is the only one called unguarded — without it `apply.sh` aborts mid-run
rather than skipping the step. Note that **`ghostty` and `yazi` are not** on that
list, despite Omarchy shipping config files for both: its package lists ship
`foot` as the terminal, and nothing on this machine depends on either, so both
are here because they were installed by hand.

**3. Set the display values for *your* hardware.** `overrides/display.conf` ships
values tuned for one ~110 PPI 3840x1600 display and applies them confidently:

```bash
./overrides/save-display.sh   # capture this machine's current values instead
```

Or edit the file. `gdk-scale` is the one to get right — `1` for standard DPI,
`2` for a HiDPI panel (Omarchy's own default). A wrong value here is actively
wrong, not merely unfamiliar.

**4. The keyboard layout is replaced — edit it out if it isn't yours.** Step 5c
installs `overrides/xkb/symbols/us-danish-letters` into `~/.config/xkb/symbols/`,
and `overrides/hypr/hyprland-env.lua` pins `kb_layout` to it: a plain US layout
plus ae/oe/aa on six otherwise-unused function keys, for one specific keyboard's
firmware. No second group, no toggle, no `kb_variant`. That block is appended at
the *end* of `~/.config/hypr/hyprland.lua`, after it has required
`hypr/input.lua`, so it also wins over a layout set there — setting your own in
the user files is not enough. Change the `kb_layout` line in `hyprland-env.lua`
before you apply.

**5. Check `~/.config/ghostty/config` exists** and contains Omarchy's
`config-file = ?"…/current/theme/ghostty.conf"` line. If the file is absent,
`apply.sh` creates one holding only its own block, and the terminal loses theme
colours with no error.

**6. Decide about third-party plugins.** `apply.sh` installs none — it has no
source URLs to fetch them from. Worth knowing before you add one: a settings
plugin that writes its own region into `looknfeel.lua` or `input.lua` (Omaland
did) beats this repo's blocks whenever its region lands later in the file, and a
layout plugin (`nomarkoo.keyboard-layout`) takes over the keyboard layout from
step 5c. A plugin's block also outlives the plugin — uninstalling leaves it
behind, still overriding. See *Also on the author's machine* below.

## Install

```bash
./overrides/apply.sh      # symlink both themes, install fonts + all system overrides, apply the theme
./overrides/revert.sh     # undo it
```

**Then log out and back in.** The `environment.d` drop-ins (Figma → native
Wayland, FreeType stem darkening) and `OMARCHY_MENU_FONT` are read at session
start, so the desktop is not in its final state until you do.

`overrides/README.md` has the full list of what is and isn't guaranteed under
*What `apply.sh` does and does not guarantee* — worth reading before assuming a
fresh machine came out identical to this one.

Switch themes with `omarchy theme set omarchy-cllpse-theme-dark` / `… -light`.
`mode` drives `gsettings` on apply: light → `color-scheme prefer-light` +
`gtk-theme Adwaita`; dark → `prefer-dark` + `Adwaita-dark` (flips GTK / libadwaita
apps and `prefers-color-scheme` in Chromium/Electron).

## Per-theme contents

Each `omarchy-cllpse-theme/omarchy-cllpse-theme-{dark,light}/` folder is a
self-contained Omarchy theme:

| File | Role |
|---|---|
| `colors.toml` | The palette + `mode`. Drives every generated config, including the shell bar/menus/notifications. |
| `shell.{bar,menu,launcher,notifications}.toml` | Per-section overrides spliced into the generated `shell.toml` — surface `background-alpha` (BUILD.md §6) for the blur set up in `overrides/`. |
| `icons.theme` | dark → `Yaru-dark`, light → `Yaru-blue`. Fed to `gsettings icon-theme` by `omarchy-theme-set-gnome`. |
| `backgrounds/` | Wallpapers — macOS stock (Big Sur → Sequoia) plus macOS-styled community art; 17 dark / 15 light. The `00-` prefix on `00-umeda_wallpaper_desktop*.png` is what makes it each theme's default: Omarchy has no default-background key and simply takes the sort-first file when switching into a theme. Not redistributable, see [`THIRD-PARTY.md`](THIRD-PARTY.md). |
| `unlock.png`, `preview-unlock.png` | Boot-splash (Plymouth) / SDDM login-screen logo, and its `omarchy plymouth switcher` picker thumbnail — a fixed multi-colour "OMARCHY" wordmark, hand-tuned per theme (close but not pixel-identical between dark/light). Applied separately from `omarchy theme set`: `omarchy plymouth set by theme <name>` (needs sudo). |
| `unlock.svg` | Vector source for `unlock.png` — not read by Omarchy itself (Plymouth/SDDM only take the PNG), kept for editing/rescaling. Exact rect-per-pixel trace, not a smoothed vectorisation — see below. Regenerate after editing `unlock.png`; it does not stay in sync on its own. |
| `preview.png` | Desktop-screenshot thumbnail for Omarchy's *main* theme picker — now distinct per theme. |
| `colors.svg` | Not read by Omarchy or anything else — a generated reference sheet of every named colour in that theme's `colors.toml` (swatch + key + hex, grouped Core/Backgrounds/Foregrounds/System Hues/Hyprland Borders), for visually checking or comparing the two palettes. Regenerate after editing `colors.toml`; it does not stay in sync on its own. |

`btop.theme`, `hyprland.lua`, `vscode-theme.json`, `neovim.lua`
and the terminal color files are **generated** from `colors.toml` by Omarchy on
`theme set` — intentionally not committed (BUILD.md: "don't hand-author").

`chromium.theme` **is** committed, by exception: Omarchy's template is just
`{{ background_rgb }}`, and pure white (`255,255,255`, the light `background`)
is a degenerate `BrowserThemeColor` seed that makes Chromium paint context-menu
separators in placeholder cyan. Each theme folder ships an explicit value —
light `236,236,236` (`#ECECEC`, macOS `windowBackgroundColor`), dark `30,30,30`
(`#1E1E1E`). Omarchy uses the shipped file and skips generation.

## Layout

```
omarchy-cllpse-theme/     the two themes (above), as omarchy-cllpse-theme-{dark,light}/
overrides/                everything that lives outside a theme folder + apply.sh / revert.sh
omarchy-cllpse-switcher/  macOS-style window-switcher HUD plugin (id cllpse.window-switcher);
                          apply.sh symlinks it into ~/.config/omarchy/plugins/
reference/                BUILD.md (the spec) + fonts.conf (BUILD's original, superseded)
THIRD-PARTY.md            what this repo redistributes and does not own
CLAUDE.md                 Omarchy's own mechanics and the traps already hit — written for
                          an agent working in here, but it is the densest reference in the
                          repo and worth reading before changing anything
```

`apply.sh` symlinks each theme folder into `~/.config/omarchy/themes/` under the
same name (`omarchy-cllpse-theme-dark` / `-light`).

## Notes / limitations found on Omarchy 4.0.2

- **Fonts are machine-level, never in a theme.** `overrides/` handles: SF fonts →
  `~/.local/share/fonts/SF/`; `monospace` → SF Mono via `omarchy font set`;
  `sans-serif`/`system-ui` → SF Pro via `~/.config/fontconfig/conf.d/99-cllpse-macos-ui-font.conf`
  (also remaps the *resolved* `Liberation Sans`, since `50-omarchy.conf` claims
  the generics before user config loads); GTK apps via `gsettings font-name`;
  shell popups via `OMARCHY_MENU_FONT` in `hyprland.lua`.
- **The bar font can't be changed.** `Style.qml` hardcodes `fontFamily =
  "monospace"` and exposes only sizes — so the bar stays SF Mono, and BUILD.md
  §4's "bar in SF Pro Text" is unreachable without patching the shell package.
- **`ui-monospace`** resolves to SF Pro Text (Omarchy alias ordering) — negligible.
- **Shell font size** is not set by the theme — it's governed by
  `~/.config/omarchy/shell.toml` (`omarchy display text size`), a machine
  setting. Bar text and icons both scale from `base-size`; there is no bar-only
  size knob. (An earlier `shell.font.toml` pinning the BUILD.md §4 scale was
  removed — pinning text while icons scaled with `base-size` made the bar icons
  look oversized.)
- **Window rounding/gaps/borders/blur** (BUILD.md §5) belong in `~/.config/hypr/`,
  not a theme (v4 strips `.lua` from git-cloned themes; `rounding` has no
  `colors.toml` key). `overrides/apply.sh` syncs a fenced block into
  `~/.config/hypr/looknfeel.lua` (`overrides/hypr/looknfeel-decoration.lua`)
  setting `decoration.rounding = 18` — above the BUILD.md §5 fallback of 12
  (26 is faithful but dramatic on tiled windows); this radius drives the shell
  surface corners too. `decoration.rounding_power = 2.2` (barely off a circular
  arc — a stronger squircle pinches the border at the corner) with
  `decoration.border_part_of_window = true` (border drawn inside each window's
  tile), enables `decoration.blur` (size 7,
  passes 4, vibrancy 0.30, vibrancy_darkness 0.30, noise 0.02, brightness/contrast
  1.0), keeps `general.border_size = 2` (Omarchy's default) with `gaps_in = 12` / `gaps_out = 24` (§5's Apple 8pt grid, `md`/`xxl` steps),
  overrides window opacity to `0.99 0.875` (re-matched onto browsers directly too,
  since Omarchy pins those to their own `1.0 0.985` otherwise), and divides every `hl.animation` leaf's
  stock speed by 3 for 3× faster animations, floored at 1 so the fastest leaves
  don't read as a hard cut. It sets no border *colour*: both borders come from
  the active theme's `colors.toml` via the generated `hyprland.lua`.
  `looknfeel-decoration.lua` also carries an `hl.layer_rule` opting the Omarchy
  shell surfaces (`omarchy-bar|menu|notifications|osd|polkit|clipboard|emojis|`
  `reminders|image-selector|network-qr|keyboard-panel|lock-preview`) plus our own
  `omarchy-window-switcher-hud` into that blur — `blur_popups` on,
  `ignore_alpha = 0.6`, which sits between the scrims (0.25) and the cards
  (all 1.0) so the dimmed backdrop stays sharp — the windows being switched
  between remain readable. With every card opaque the blur is currently inert;
  the rule is kept so it returns if an alpha is lowered again. Additive to Omarchy's own `no_anim` layer rules.
- **Chromium scale is two settings that multiply, not one.**
  `overrides/chromium/chromium-flags.conf` is fenced into
  `~/.config/chromium-flags.conf` (the launcher skips `#` lines, so the markers
  are inert) and pins `--force-device-scale-factor=1` against DP-2's 1.25
  monitor scale, putting the browser UI 20% under the rest of the desktop.
  `overrides/chromium/default-zoom.py` then sets page zoom to 110%, so page
  layout lands at 0.8 × 1.1 = 0.88 of native; 125% would cancel the flag
  outright. There is no command-line flag for default zoom — it is the profile
  preference `partition.default_zoom_level`, stored as `ln(factor)/ln(1.2)` —
  and Chromium must be closed when it is written, since it rewrites
  `Preferences` from memory on exit.
- **App icons in the menu come from `overrides/icons/fallbacks/` (step 7f).** The
  menu already renders every non-app row as a Nerd Font glyph tinted
  `foreground`; app rows are the exception, drawn as a plain image of the
  vendor's logo with no recolouring, so 48 of the 52 visible entries here were
  full colour. Drop an SVG named for the desktop entry's `Icon=` value into
  `overrides/icons/fallbacks/` and a `theme-set` hook syncs it into
  `~/.icons/cllpse-flat/apps/`, repainted in the active theme's `foreground` —
  `$HOME/.icons` is the first directory Omarchy's icon index scans, and carries
  no `index.theme`, so the override reaches the shell without touching GTK or
  Qt. Nothing is generated: an app with no file there keeps its vendor icon.
- **Shell-surface translucency lives in the theme, per section.** A theme-shipped
  `shell.<section>.toml` is spliced into the generated `shell.toml` by
  `omarchy-theme-set-templates`, *replacing that whole `[section]`*. Each theme
  folder ships `shell.bar.toml`, `shell.menu.toml`, `shell.notifications.toml`,
  `shell.tooltip.toml`, `shell.lock.toml` and `shell.launcher.toml` (**inert on
  4.0.2**, see below). **Every card is α 1.0 — opaque.** The scrims are the
  exception and stay translucent at 0.25, kept low and unblurred so the window
  switcher stays usable. The switcher binds `Color.menu.scrim` rather than
  composing its own, so its dim is the menu's dim in both light and dark.
  Nothing reads `launcher.*`: `Color.qml` has no launcher surface, there is no
  launcher plugin, and what Omarchy calls the launcher is the menu plugin drawing
  on `Color.menu.*`. The `[launcher]` section is spliced into the generated
  `shell.toml` and then ignored — edit `[menu]` to change it.
  — BUILD.md §6 values. Colours are role-name tokens (`"background"`,
  `"foreground"`, `"accent"`) that `Color.qml` resolves against the live palette,
  so nothing hardcodes hex, except where `Color.qml` reads a key with a plain
  `pick()` (`text`, `active`, `selected-text`, `countdown`, `text-error`), which
  never unwraps a role name and so must be literal hex or it renders black.
  `tooltip` and `lock` are shipped only to take Omarchy's generated 0.97 and 0.8
  to 1.0. Whole-section replace means any key omitted falls back to the
  `Color.qml` default, not the generated value — that's why each file restates
  its full section, and it matters most for `lock`, whose `background-alpha`
  default (0.8) is exactly what we are overriding.
  Because every card is opaque, the layer blur rule is currently inert for all of
  them; it is kept so the effect returns if any alpha is lowered again. The dark/light copies are currently identical
  (same α over each mode's own `background` colour); tune light up if it reads
  washed out.
- **Focused windows at 0.99, unfocused at 0.875, so the blur renders through both.**
  Omarchy's `windows.lua` tags every window `+default-opacity`, lets the per-app
  files strip that tag, then applies `0.985 0.96` to whatever still carries it.
  `looknfeel-decoration.lua` repeats that *same tag match* later in load order and
  sets `0.99 0.875` — focused isn't fully opaque either, so it reads as the same
  glass material rather than a flat cutout next to the more translucent unfocused
  windows. Matching the tag rather than `.*` matters: Omarchy deliberately
  untags what must not go translucent — DaVinci Resolve, PiP and webcam overlays,
  Steam, QEMU, RetroArch, YouTube/Zoom web apps — and gives browsers their own
  `1.0 0.985`, which the tag match above therefore never touches. Left as-is,
  Chromium/Firefox windows would stay effectively opaque when unfocused (98.5%)
  with no blur reading through, so `looknfeel-decoration.lua` re-matches
  `chromium-based-browser` / `firefox-based-browser` directly (after
  `browser.lua` has run) and pins those to `0.99 0.875` too — same glass as
  everywhere else. The YouTube/Zoom exclusion still holds: `browser.lua` strips
  the browser tag from those windows before this runs.
  Figma Desktop isn't one of Omarchy's stock colour-critical exclusions, so
  `looknfeel-decoration.lua` adds its own: `.*[Ff]igma.*` matched loosely
  against the class (the live window class is the lowercase `figma-desktop`,
  not the `Figma` the AppImage's own `.desktop` declares as `StartupWMClass`),
  untagged and
  pinned to `1 1` — same reasoning and idiom as Omarchy's own
  `davinci-resolve.lua`.
  Because `blur.ignore_opacity` is true, a semi-transparent window has the full
  blur pass rendered behind it, so unfocused windows read as glass over whatever
  is beneath. That is the intended effect, which is why `dim_inactive` is
  explicitly `false` — it was tried at 0.10 and stacking a darkening pass on top
  muddied the result and worked against the blur.
- **The Omarchy shell slaves its surface radius to `decoration:rounding`.**
  `Style.qml` runs `hyprctl getoption decoration:rounding` on startup and after
  `omarchy theme set`, so bar/menu/launcher/notification/OSD corners follow the
  same 18 — but as a **plain circular arc**: `rounding_power` and `border_size`
  don't reach the shell (its border widths come from generated `shell.toml`
  tokens). At `rounding_power = 2.2` the windows curve only a hair tighter than
  the bar and menu that mirror their radius. A live
  `hyprctl reload` alone won't update a running shell — `omarchy-restart-shell`
  or `omarchy theme set` does.
- **`omarchy font set`** (Style ▸ Font) rewrites `~/.config/fontconfig/fonts.conf`
  wholesale — re-run `overrides/apply.sh` if you ever use it. It leaves
  `conf.d/99-cllpse-macos-ui-font.conf` alone.

## Also on the author's machine (not installed by `apply.sh`)

Settings this machine carries that the repo deliberately leaves alone, recorded
so a rebuild isn't guesswork:

| Setting | Where | Why it isn't installed |
|---|---|---|
| `gtk-enable-primary-paste = true` | `gsettings org.gnome.desktop.interface` | Middle-click paste — a personal habit, unrelated to the macOS look |
| `SSH_AUTH_SOCK` → `${XDG_RUNTIME_DIR}/gcr/ssh` | `~/.config/environment.d/ssh-agent.conf` | Points ssh at the GNOME keyring; would break ssh on a machine without it running |
| Nautilus / GTK file-chooser window state | `dconf` | Incidental UI state, not configuration |

Third-party shell plugins are not installed either — `apply.sh` has no source
URL for any of them, and the bar layout it writes names none. That is enough to
disable one: a third-party plugin is enabled iff its id appears somewhere in
`shell.json`, so a layout without its widget is the uninstall as far as the shell
is concerned, though the directory under `~/.config/omarchy/plugins/` still has
to be deleted by hand.

A settings plugin that writes its own region into `looknfeel.lua` or `input.lua`
wins over ours if its block lands later in the file — and a plugin's block
outlives the plugin, since uninstalling it leaves the block behind. OmaSettings
is the version of this worth watching: rather than a fenced block it writes a
separate `~/.config/hypr/omasettings.lua` and appends `require("hypr.omasettings")`
to the *end* of `hyprland.lua`, after every user file, so it wins every key it
sets for as long as that file exists. Anything of its it makes sense to keep
belongs in the overrides here, with the line deleted there. The keyboard layout
in `hyprland-env.lua` is the same story from the other side: it sits after
`require("default.hypr.toggles")`, so it applies on a machine with no layout
plugin, and a plugin that owns the layout (`nomarkoo.keyboard-layout`) would take
it back. These blocks exist for self-sufficiency, not to fight a plugin.

### Everything else installed here

The complete set, so a rebuild isn't guesswork and so the *Before you run this*
list stays honest about what it leaves out. Regenerate it with:

```bash
comm -23 <(pacman -Qqe | sort -u) \
         <(cat /usr/share/omarchy/install/*.packages | sed 's/#.*//' \
           | tr -s ' \t' '\n' | sed '/^$/d' | sort -u)
```

That prints every explicitly-installed package Omarchy's own lists do not
contain — 20 here. Nine of them are this repo's dependencies and are covered in
[`overrides/README.md`](overrides/README.md); the other eleven are the two
groups below. Anything that turns up in the command's output and not in this
section is either new or was never wanted.

**Keyboard firmware toolchain** — `pacman -S qmk avrdude avr-gcc avr-libc`.
Not used by anything in this repo, but two of its features exist *because* of
the keyboard it flashes: step 5c's `us-danish-letters` xkb layout, and
`window-management-mod.lua` moving window navigation from `SUPER` to `CTRL+ALT`
because the Preonic's firmware intercepts `SUPER` on the keys those binds used.
Read that as provenance for two otherwise-arbitrary decisions.

**Helium** — `~/Applications/helium-<version>-x86_64.AppImage`, a Chromium
fork, and not a package, so it does not appear in the command's output at all.
`Hud.qml` buckets it with the browser family for its switcher glyph and names
it, but nothing here installs or requires it — the switcher simply recognises
the window if it is there. Same relationship as Figma Desktop, minus the
launcher entry.

**Audio workaround** — `~/.local/bin/force-analog-sink`, run by
`~/.config/systemd/user/force-analog-sink.service`. The onboard Realtek ALC897
rear line-out does not report jack presence, so WirePlumber marks the analog
route unavailable and refuses to restore the analog sink on every login. Neither
the script nor the unit is in this repo — hardware-specific, and nothing here
touches audio.

**CLI tools that install themselves** — `~/.local/bin/` holds a set of one-line
wrappers (`copilot`, `crush`, `cursor-agent`, `gemini`, `ghui`, `grok`,
`hermes`, `muse`, `omp`, `opencode`, `pi`, `playwright`) that each `mise use -g`
their own tool on first run and then exec it. They need no install step and
appear in no package list. `herdr`, `claude`, `codex`, `gh` and `hunk` come from
`mise` proper (`~/.config/mise/config.toml`); only `hunk` and `gh` matter to this
repo.

**Arch and Omarchy base** — `efibootmgr`, `intel-ucode`, `mkinitcpio`, `sudo`,
`omarchy`, `omarchy-keyring`, `omarchy-settings`. Listed only so that running
the command above and diffing it against this section comes out empty.

### Figma Desktop — installing and updating it

`apply.sh` installs no applications, and Figma has no self-updater, so the app
itself is yours to keep current. What the repo *does* own is its launcher entry
(step 7e), because the app writes its own on every launch and gets two fields
wrong for this desktop — `Name=Figma` where the product is *Figma Desktop*, and
`StartupWMClass=Figma` against a live Hyprland class of `figma-desktop`, which
joins to no window and costs the window switcher its tile label.

The app is [`nickvdp/figma-desktop-linux`](https://github.com/nickvdp/figma-desktop-linux),
an AppImage repack of Figma's own Electron build — not the community
`figma-linux` wrapper around the web app, which is a different project with a
different settings schema. It is run **extracted**, not as a mounted AppImage:

```bash
# installing and updating are the same steps
cd ~/Applications
./figma-desktop-<version>-amd64.AppImage --appimage-extract   # -> squashfs-root/
rm -rf figma-desktop && mv squashfs-root figma-desktop

cd ~/Sites/omarchy-cllpse-macos && ./overrides/apply.sh
```

**Nothing inside `~/Applications/figma-desktop/` belongs to this repo**, so an
extraction has nothing of ours to destroy and the third step only rewrites the
launcher entry. That is a deliberate property, not luck. The app's launcher
regenerates the entry whenever `Exec` differs from `Exec="${appimage_path}" %u`,
and with no `APPIMAGE` in the environment that path is `readlink -f "$0"` —
`~/Applications/figma-desktop/AppRun`, which carries no version number. So the
entry the repo writes matches what the app would write, on every release, and is
never taken back.

A wrapper script around `AppRun` breaks exactly that. It has to displace the
launcher to `AppRun.real`, which changes the computed path, which then needs an
`APPIMAGE` export to repair — and it lives inside the app directory, where the
next extraction deletes it and hands `Name` and `StartupWMClass` back silently.
This machine ran one for a while. Step 7e removes it if it finds it. The only
thing it did that is still wanted, `FIGMA_USE_WAYLAND=1`, is an `environment.d`
drop-in instead (step 7c), which no update can reach.

Two things worth knowing after an update: the entry change needs no relogin, but
`environment.d` does, so a *first* install wants a logout before Figma runs as a
native Wayland client at the right scale. And `keyd` — the one package this repo
depends on, for Figma's `Cmd`+click and `Cmd`+scroll — is configured by step 8b
and not installed by it.
