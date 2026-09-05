# overrides/

Everything the `omarchy-cllpse-theme` themes need that lives **outside** an
Omarchy theme folder — fonts, fontconfig, GTK settings, font hinting, Hyprland
env var + window decoration (rounding, blur), Cursor editor prefs, and colour
configs for apps Omarchy doesn't theme. Omarchy's design puts all of this at
machine level (it applies to every theme, reading whatever palette is active),
so it can't ship inside a theme folder.

## Use

```bash
./apply.sh     # install everything + apply the theme (keeps light if light is active)
./revert.sh    # undo everything, restoring what the machine had before
```

`revert.sh` only ever **undoes** — it never picks a font or theme for you. Omarchy
has no `font reset` / `theme reset`, so `apply.sh` records the font and theme the
machine had *before* it first ran (in `~/.local/state/cllpse-macos/`) and
`revert.sh` puts those back. Values that are already ours are refused at record
time, so re-running `apply.sh` can't turn revert into a no-op.

With nothing recorded, revert deletes the `fonts.conf` that `omarchy-font-set`
generates — `monospace` then falls back to the packaged default on its own — and
tells you the terminal configs may still name SF Mono rather than guessing a
replacement.

Both are idempotent, need **no sudo**, and are safe to re-run.

## What `apply.sh` does

| # | Action | Target |
|---|---|---|
| 0 | Record the font and theme the machine had *before* the first apply, so `revert.sh` has something true to restore. Written once; values already ours are refused | `~/.local/state/cllpse-macos/previous-{font,theme}` |
| 1 | Symlink both `omarchy-cllpse-theme/` folders as themes, and `omarchy-cllpse-switcher/` as a plugin | `~/.config/omarchy/themes/omarchy-cllpse-theme-{dark,light}`, `~/.config/omarchy/plugins/io.eject.window-switcher` |
| 2 | Install SF fonts + fontconfig drop-ins (UI font + hintnone) | `~/.local/share/fonts/SF/`, `~/.config/fontconfig/conf.d/{99-cllpse-macos-ui-font,11-cllpse-macos-hinting}.conf` |
| 3 | Monospace → SF Mono (Omarchy's own knob) | `omarchy font set` → terminal configs + `fonts.conf` |
| 4 | GTK/GNOME fonts → SF Pro / SF Mono | `gsettings org.gnome.desktop.interface` |
| 5 | Font hinting → `none` — SF faces render unhinted; grid-snapped stems read as sharp under grayscale AA (Wayland fractional scaling) | `gsettings … font-hinting 'none'` (GTK/GNOME) + fenced `freetype-load-flags = no-hinting` in `~/.config/ghostty/config`, on top of Omarchy's stock config (fontconfig side is the step-2 drop-in) |
| 5b | GTK window buttons → none. Hyprland draws no titlebars; a GTK/libadwaita app's min/max/close is its own CSD, laid out from this key. `':'` vs Omarchy's `'appmenu:close'`. Electron/Qt ignore it — Cursor's are step 7 | `gsettings org.gnome.desktop.wm.preferences button-layout ':'` |
| 6 | `OMARCHY_MENU_FONT` + cursor theme + `no_warps` + keyboard layout (`hyprland.lua`), decoration/blur/opacity/animations (`looknfeel.lua`), window-switcher keybinds (`bindings.lua`), mouse tuning (`input.lua`) + `decoration` (`rounding = 18` / `rounding_power = 2.2` / `border_part_of_window = true`, `blur` on @ size 7 / passes 4 / vibrancy 0.30, `border_size = 2`, `gaps_in/out = 8/16`) + window `opacity = 0.98 0.875` (re-matched onto `chromium-based-browser` / `firefox-based-browser` too, since Omarchy pins those to `1.0 0.985` otherwise) + 2× animation speeds + `layer_rule` blur on the shell surfaces | fenced blocks synced into `~/.config/hypr/hyprland.lua` and `~/.config/hypr/looknfeel.lua` |
| 7 | `bat` / `lazygit` / `fzf` colours → terminal ANSI; Cursor editor prefs (whitespace/format-on-save, chrome trimmed — activity + status bars, menu bar, layout control, agents-window button and the `custom` title bar's min/max/close all hidden) merged into `settings.json` with `jq` — our keys win, `workbench.colorTheme` left to Omarchy, no extension-dependent keys | `~/.config/bat/config`, `~/.config/lazygit/config.yml`, `~/.config/Cursor/User/settings.json`, fenced block in `~/.bashrc` |
| 7b | Restore saved display scaling + text size from `display.conf` (skipped if the file is absent; each empty key skipped) | `omarchy display text size`, the two scale variables in `~/.config/hypr/monitors.lua` |
| 7c | Install session environment drop-ins (Figma → native Wayland) | `~/.config/environment.d/50-cllpse-macos-figma-wayland.conf` |
| 7d | Chromium scale: `--force-device-scale-factor=1` (browser UI 20% under DP-2's 1.25) + `110%` default page zoom. Page size is the product of the two — 125% would be exactly 1:1 with native | fenced block in `~/.config/chromium-flags.conf` + `partition.default_zoom_level` in each `~/.config/chromium/*/Preferences` |
| 7e | Helium (Chromium fork, extracted AppImage) — the same `--force-device-scale-factor=1` + `110%` zoom pairing as 7d. No flags-file launcher, so the flag is injected into the `Exec=` lines of the `.desktop` entry in place (once; guarded); no ozone flag (Helium already runs Wayland off the session env). Zoom reuses `chromium/default-zoom.py` via `CLLPSE_ZOOM_*` | `Exec=` lines of `~/.local/share/applications/helium.desktop` + `partition.default_zoom_level` in `~/.config/net.imput.helium/*/Preferences` |
| 7f | Brave Origin (`brave-origin-bin`, AUR — Chromium fork) — the same pairing as 7d. Keeps the flags-file launcher convention (`/usr/bin/brave-origin`, a bash script, one flag per line), so the scale flag is a fenced block like 7d; the flags file must already exist (it also carries the ozone lines). Zoom reuses `chromium/default-zoom.py` (binary `brave`) | fenced block in `~/.config/brave-origin-flags.conf` + `partition.default_zoom_level` in each `~/.config/BraveSoftware/Brave-Origin/*/Preferences` |
| 8 | Apply the theme — refreshes whichever cllpse-macos theme is already active, else sets dark | `omarchy theme set …` |

The blur `layer_rule` only opts the shell surfaces *into* blur; the matching
translucency (`background-alpha`) is the theme's half —
`omarchy-cllpse-theme/*/shell.*.toml`. Blur shows nothing until both are in place. The rule's
namespace match also covers `omarchy-window-switcher-hud`, so the
`omarchy-cllpse-switcher/` plugin (symlinked in step 1) blurs like the menu.

Injected blocks are wrapped in `>>> cllpse-macos overrides >>>` fences (comment
leader `--` in Lua, `#` in shell — Ghostty config takes `#`); `revert.sh` deletes
exactly those. Pre-existing `~/.config/bat/config` /
`~/.config/lazygit/config.yml` / `~/.config/Cursor/User/settings.json` are saved
as `*.pre-cllpse` and restored on revert.

Cursor `settings.json` is the one JSON target: `apply.sh` deep-merges
`cursor/settings.json` with `jq` (`.[0] * .[1]` — our keys win, everything else
stays). It refuses if the live file has JSONC comments `jq` can't parse, and
never writes an empty result. `workbench.colorTheme` is intentionally absent from
our file — `omarchy-theme-set-vscode` rewrites it to `"Omarchy"` on every theme
switch, and merging in a competing value would just lose that race.

**Re-running updates an existing block in place.** `sync_fenced` replaces the
fenced region and leaves everything around it alone, so edits to
`hypr/looknfeel-decoration.lua` reach an already-applied machine. (The earlier
`append_fenced` bailed whenever it saw the marker, which silently pinned a
machine to whatever version it first installed.) If the block already matches the
snippet the file is not rewritten at all.

## Display scaling + text size

```bash
./save-display.sh    # capture the machine's current values into display.conf
./apply.sh           # restore them (step 7b)
```

`display.conf` holds three keys — `text-size`, `monitor-scale`, `gdk-scale`.
Only the two **scale variables** in `~/.config/hypr/monitors.lua` are written
(`omarchy_monitor_scale` / `omarchy_gdk_scale`, both stock Omarchy variables the
`hl.monitor()` lines reference). Monitor topology — outputs, modes, positions —
is never touched, so the same `display.conf` is safe on different hardware even
though the values themselves are a preference.

`text-size` goes through `omarchy display text size`, which moves the shell's rem
root, the GTK `text-scaling-factor` and the terminal point size together.

These are **the author's values**, tuned for a 3840x1600 display, and they are
not part of the macOS look — edit `display.conf` or re-run `save-display.sh` on
your own machine. Since `apply.sh` reasserts them on every run, retuning by hand
and *not* re-saving means the next apply pulls you back; `save-display.sh` is how
you make a change stick. Scale changes land on the next Hyprland reload.

Step 8 matters more than it looks: `omarchy theme set` **copies** the theme
folder into `~/.local/state/omarchy/current/theme/` rather than symlinking it, so
it is also what publishes a theme-folder edit — a new background, a changed
`shell.*.toml` — to the live desktop.

Hinting is `hintnone` on three fronts that don't share a knob: the fontconfig
drop-in covers Qt / Alacritty / Electron; `gsettings font-hinting` covers
GTK/GNOME; the Ghostty block covers Ghostty (Kitty hardcodes light hinting —
no override). Middle ground if it reads too soft: `hintslight` + `autohint`.

## What `apply.sh` does and does not guarantee

Within what it controls it is deterministic: every step is idempotent, fenced
blocks are replaced rather than appended so a re-run converges on the snippet,
pre-existing state is recorded once and never overwritten, and re-running changes
nothing that already matches. Running it twice gives the same result as once.

It is **not** a complete machine build. On a clean install these are the gaps:

| Gap | Effect |
|---|---|
| **No sudo, so no packages.** `bibata-cursor-theme-bin` (AUR — `pacman -S` will not find it) is warned about but not installed — yet the cursor theme is still set in `gsettings` and `hl.env`, so a missing package leaves the cursor falling back. `lsd` missing just skips the alias (guarded). Ghostty, Foot, `lazygit`, `bat`, `jq` are assumed present | Cursor visibly wrong; other items silently absent |
| **Cursor editor not installed.** The `settings.json` merge is skipped when both `/usr/bin/cursor` and `~/.config/Cursor/User/` are absent. The override carries no marketplace-extension keys, so nothing in it needs a network step | Merge skipped on a machine without Cursor |
| **Third-party plugins are not installed** — `bobbynicholas.omaland`, `dizziee.system-updates`, `nomarkoo.keyboard-layout` | Absent, and the blocks that coordinate with them behave differently (see below) |
| **`display.conf` values are hardware-specific** — text size 14, monitor scale 1.25, GDK scale 1 are tuned for one ~110 PPI 3840x1600 display. `gdk-scale` in particular is wrong on a HiDPI panel, where Omarchy's default of 2 is right | Wrong sizing on different hardware, applied confidently |
| **Some settings need a relogin** — the `environment.d` drop-ins (Figma → Wayland, FreeType darkening) and `OMARCHY_MENU_FONT` are read at session start | State immediately after `apply.sh` is not the final state |
| **`sync_fenced` creates the target if absent.** If `~/.config/ghostty/config` does not exist, the file it writes contains only our block — losing Omarchy's `config-file` line that pulls in theme colours | Terminal colours silently unthemed |
| **Plugin-owned regions are won on file position, not ownership.** `input-tuning.lua` sits after Omaland's mouse block, and the keyboard layout after `default.hypr.toggles` — but opening Omaland's settings panel rewrites its block below ours | Mouse/keyboard settings can flip back later |
| **`revert.sh`'s restore paths are unit-tested but never run end-to-end** | Unverified on a real machine |

So: an agent following this on a clean install gets the look right, and every value
in it is written down. It will not get a byte-identical machine, and the
differences above are the ones to check by hand.

## Follow-ups `apply.sh` can't do live

- **Log out / back in** (or reboot) for `OMARCHY_MENU_FONT` — `hl.env` only applies at Hyprland start. (The `looknfeel.lua` decoration block — rounding, blur — picks up on the theme-set reload in step 8; the Omarchy shell re-reads what it mirrors on that same `omarchy theme set`, or `omarchy-restart-shell`.)
- **Open a new shell** for the `fzf` colours.
- **Restart Ghostty / Foot** windows for the new monospace font + `hintnone` (Kitty/Alacritty reload themselves).
- **Relaunch running GTK/Qt apps + the bar** to pick up `hintnone`.
- **Log out / back in** for the `environment.d` drop-ins — the systemd user session reads them at session start.
- **Quit Chromium / Helium / Brave Origin before the step 7d / 7e / 7f zoom half**, and relaunch after. All rewrite `Preferences` from memory on exit, so a write made while running is discarded; the script detects this and skips rather than reporting a change that will not survive. The flag half needs only a relaunch. Sites already zoomed with ctrl+/- keep their own `per_host_zoom_levels` and ignore the default.
- **Helium's scale flag rides on its `.desktop` entry**, not a flags file — Helium is an extracted AppImage with no `chromium-flags.conf` launcher. Re-extracting the AppImage can regenerate `~/.local/share/applications/helium.desktop` without the flag; re-run `apply.sh` to re-inject it. `revert.sh` strips just the flag and leaves the file (it is Helium's).
- **Brave Origin's flags file must already exist** (`~/.config/brave-origin-flags.conf`) — step 7f fences into it but won't create it, because it also holds the `--ozone-platform` lines that keep Brave on Wayland here. If it's missing, install/launch Brave Origin once (or recreate it with the Omarchy `chromium-flags.conf` lines) and re-run.

## Contents

```
apply.sh  revert.sh
fonts/                        20 SF .otf (SF Mono, SF Pro Text, SF Pro Display)
fontconfig/conf.d/99-cllpse-macos-ui-font.conf   SF Pro for sans-serif/system-ui + optical-size crossover
fontconfig/conf.d/11-cllpse-macos-hinting.conf   hintstyle -> hintnone (overrides system 10-hinting-slight)
ghostty/ghostty.conf          freetype-load-flags = no-hinting + a few non-default prefs
bat/config                    --theme="ansi"
lazygit/config.yml            gui.theme with ANSI colour names
cursor/settings.json          Cursor editor prefs, jq-merged in; omits workbench.colorTheme (Omarchy's) + extension-dependent keys
hypr/hyprland-env.lua         OMARCHY_MENU_FONT + cursor theme/size + no_warps + kb layout
hypr/window-switcher-bindings.lua  SUPER+TAB keybinds driving the switcher plugin
hypr/input-tuning.lua         mouse sensitivity/accel/follow_mouse
hypr/looknfeel-decoration.lua rounding 18 / rounding_power 2.2 / border_part_of_window true / blur / border_size 2 / gaps 8,16 / window opacity 0.98 0.875 / 2x animations / layer_rule blur on shell surfaces
bash/shell.sh                 FZF_DEFAULT_OPTS derived from the live palette + lsd alias
display-lib.sh                shared readers/writers for scale + text size (sourced, not run)
display.conf                  saved text-size / monitor-scale / gdk-scale
save-display.sh               capture the live values into display.conf
environment.d/*.conf          systemd user-session env (Figma native Wayland, FreeType stem darkening on + stronger curve)
chromium/chromium-flags.conf  --force-device-scale-factor=1 (fenced into Omarchy's flags file)
chromium/default-zoom.py      default page zoom -> 110% (no flag exists; it is a profile preference). Reused for Helium + Brave Origin via CLLPSE_ZOOM_{CONFIG_DIR,BINARY,LABEL}
brave-origin/brave-origin-flags.conf  --force-device-scale-factor=1 (fenced into ~/.config/brave-origin-flags.conf)
```

Helium has no flags file of its own: apply.sh step 7e injects the scale flag
straight into `~/.local/share/applications/helium.desktop` and drives
`chromium/default-zoom.py` against `~/.config/net.imput.helium`. Brave Origin
(step 7f) keeps a flags file, so it gets a fenced snippet like Chromium, plus
the same zoom pass against `~/.config/BraveSoftware/Brave-Origin`.
