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

## Install

```bash
./overrides/apply.sh      # symlink both themes, install fonts + all system overrides, apply dark
./overrides/revert.sh     # undo it
```

Idempotent, no sudo. See [`overrides/README.md`](overrides/README.md) for exactly
what it touches and the manual follow-ups (relogin for the shell popup font, new
shell for fzf).

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
| `backgrounds/` | Wallpapers — macOS stock (Big Sur → Sequoia) plus macOS-styled community art; 17 dark / 15 light. Not redistributable, see [`THIRD-PARTY.md`](THIRD-PARTY.md). |
| `preview*.png`, `unlock.png` | Theme-picker / lock-screen art — still Last Horizon's dark art in both. |

`btop.theme`, `chromium.theme`, `hyprland.lua`, `vscode-theme.json`, `neovim.lua`
and the terminal color files are **generated** from `colors.toml` by Omarchy on
`theme set` — intentionally not committed (BUILD.md: "don't hand-author").

## Layout

```
omarchy-cllpse-theme/     the two themes (above), as omarchy-cllpse-theme-{dark,light}/
overrides/                everything that lives outside a theme folder + apply.sh / revert.sh
omarchy-cllpse-switcher/  macOS-style window-switcher HUD plugin (id io.eject.window-switcher);
                          apply.sh symlinks it into ~/.config/omarchy/plugins/
reference/                BUILD.md (the spec) + fonts.conf (BUILD's original, superseded)
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
  setting `decoration.rounding = 14` — just above the BUILD.md §5 fallback of 12
  (26 is faithful but dramatic on tiled windows), nudges
  `decoration.rounding_power` to 2.2 (toward Apple's squircle corner — windows
  only), enables `decoration.blur` at the §5 values (size 12, passes 3, vibrancy
  0.20, brightness/contrast 1.0), pins `general.border_size = 2` (also the
  Omarchy default) with `gaps_in = 8` / `gaps_out = 16` (§5's Apple 8pt grid),
  overrides window opacity to `1.0 0.88`, and halves every `hl.animation` leaf's
  stock speed for 2× faster animations. A separate, hand-written block higher up
  the same file does the theme-adaptive inactive border, reading `muted` from the
  active palette; the Omaland plugin, if installed, manages its own animation
  block below ours and wins on load order.
  `looknfeel-decoration.lua` also carries an `hl.layer_rule` opting the Omarchy
  shell surfaces (`omarchy-bar|menu|notifications|osd|polkit|clipboard|emojis|`
  `reminders|image-selector|network-qr|keyboard-panel|lock-preview`) plus our own
  `omarchy-window-switcher-hud` into that blur — `blur_popups` on,
  `ignore_alpha = 0.1` so the transparent margin around rounded cards doesn't
  blur into a rectangle. Additive to Omarchy's own `no_anim` layer rules.
- **Shell-surface translucency lives in the theme, per section.** A theme-shipped
  `shell.<section>.toml` is spliced into the generated `shell.toml` by
  `omarchy-theme-set-templates`, *replacing that whole `[section]`*. Each theme
  folder ships `shell.bar.toml` (α 0.72), `shell.menu.toml` (0.92),
  `shell.launcher.toml` (0.85, scrim 0.35) and `shell.notifications.toml` (0.92)
  — BUILD.md §6 values. Colours are role-name tokens (`"background"`,
  `"foreground"`, `"accent"`) that `Color.qml` resolves against the live palette,
  so nothing hardcodes hex; `tooltip` (0.97) and `lock` (0.8) already match §6
  and aren't shipped. Whole-section replace means any key omitted falls back to
  the `Color.qml` default, not the generated value — that's why each file
  restates its full section. The dark/light copies are currently identical
  (same α over each mode's own `background` colour); tune light up if it reads
  washed out.
- **Focused windows opaque, unfocused at 0.875 so the blur renders through them.**
  Omarchy's `windows.lua` tags every window `+default-opacity`, lets the per-app
  files strip that tag, then applies `0.985 0.96` to whatever still carries it.
  `looknfeel-decoration.lua` repeats that *same tag match* later in load order and
  sets `1.0 0.875`. Matching the tag rather than `.*` matters: Omarchy deliberately
  untags what must not go translucent — DaVinci Resolve, PiP and webcam overlays,
  Steam, QEMU, RetroArch, YouTube/Zoom web apps — and gives browsers their own
  `1.0 0.985`.
  Because `blur.ignore_opacity` is true, a semi-transparent window has the full
  blur pass rendered behind it, so unfocused windows read as glass over whatever
  is beneath. That is the intended effect, which is why `dim_inactive` is
  explicitly `false` — it was tried at 0.10 and stacking a darkening pass on top
  muddied the result and worked against the blur.
- **The Omarchy shell slaves its surface radius to `decoration:rounding`.**
  `Style.qml` runs `hyprctl getoption decoration:rounding` on startup and after
  `omarchy theme set`, so bar/menu/launcher/notification/OSD corners follow the
  same 14 (plain circular — `rounding_power` and `border_size` don't reach the
  shell; its border widths come from generated `shell.toml` tokens). A live
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
| Plugins: `bobbynicholas.omaland`, `dizziee.system-updates`, `nomarkoo.keyboard-layout` | `~/.config/omarchy/plugins/` | Third-party, installed through Omarchy's own plugin flow — `apply.sh` has no source URLs to fetch them from |
| Nautilus / GTK file-chooser window state | `dconf` | Incidental UI state, not configuration |

Two of the installed blocks overlap with plugins that own the same settings.
`input-tuning.lua` is appended after Omaland's `OMARCHY_MOUSE_SETTINGS` block and
wins on file position, but Omaland rewrites its own block whenever its Settings
panel is opened. The keyboard layout in `hyprland-env.lua` sits after
`require("default.hypr.toggles")`, so it applies on a machine with no layout
plugin — where `nomarkoo.keyboard-layout` is installed, its toggle state wins.
Both exist for self-sufficiency, not to fight the plugins.
