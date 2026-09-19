# overrides/

Everything the `omarchy-cllpse-theme` themes need that lives **outside** an
Omarchy theme folder — fonts, fontconfig, GTK settings, font hinting, Hyprland
env var + window decoration (rounding, blur), Cursor editor prefs, and colour
configs for apps Omarchy doesn't theme. Omarchy's design puts all of this at
machine level (it applies to every theme, reading whatever palette is active),
so it can't ship inside a theme folder.

## Use

```bash
./apply.sh          # install everything + apply the theme (keeps light if light is active)
./revert.sh         # undo everything, restoring what the machine had before
./install-figma.sh  # install or update Figma Desktop, then run apply.sh
```

`install-figma.sh` is the odd one out: it is the only script here that reaches
the network, and the only one that installs an **application** — `apply.sh`
installs nothing. Figma has no self-updater, so installing and updating are one
command. `--check` reports installed vs. latest and changes nothing; the rest of
its flags are in the root [`README.md`](../README.md#figma-desktop--installing-and-updating-it).

`revert.sh` only ever **undoes** — it never picks a font or theme for you. Omarchy
has no `font reset` / `theme reset`, so `apply.sh` records the font and theme the
machine had *before* it first ran (in `~/.local/state/cllpse-macos/`) and
`revert.sh` puts those back. Values that are already ours are refused at record
time, so re-running `apply.sh` can't turn revert into a no-op.

With nothing recorded, revert deletes the `fonts.conf` that `omarchy-font-set`
generates — `monospace` then falls back to the packaged default on its own — and
tells you the terminal configs may still name SF Mono rather than guessing a
replacement.

Both are idempotent and safe to re-run. Neither needs sudo except two steps in
each — keyd's config plus the `keyd` group grant (`apply.sh` step 8b) and
installing/removing the Chromium managed-policy file (step 9) — everything else
in both scripts is user-level.

## Before running `apply.sh`

**`apply.sh` installs nothing** — no packages, no gh extensions, no mise tools.
Install these first for a complete result.

| Channel | Install | Needed for |
|---|---|---|
| `pacman -S` | `lsd` `bat` `lazygit` `yazi` `lazydocker` `starship` `fzf` `jq` `imagemagick` `ghostty` `sqlite` | theme configs (step 7 / 7a), the Cursor + `shell.json` merges (`jq`), the app-icon hook (`imagemagick`), Cursor's layout-mode correction (`sqlite3`, step 7) |
| `yay -S` (AUR) | `bibata-cursor-theme-bin` | the cursor theme. Genuinely AUR — `pacman -S` will not find it |
| `pacman -S` (`extra`) | `msedit` | the `edit` alias. Needs no theme config — see *How each app is themed* |
| `pacman -S` (`omarchy` repo) | `cursor-bin` | the editor step 7 merges `settings.json` into, and the one the *Cursor marketplace* row below extends. Absent, the merge is skipped with a message telling you to merge `cursor/settings.json` by hand |
| `yay -S` (AUR) + `pacman -S` | `ytm-player` (AUR) `python-secretstorage` (`extra`) | the music player. Step 7 writes its preferences through `ytm/config-prefs.py`, renders `themed/ytm-player.toml.tpl` and installs the `ytm-player.sh` theme hook, so its colours follow `omarchy theme set` like everything else. `python-secretstorage` is separate and easy to miss: without it `cllpse-ytm-signin` cannot read the Chromium keyring and sign-in fails through a `yt-dlp` path that gives no useful error |
| `yay -S` (AUR) | `ryzenadj` | the CPU power limits (step 10), and only on the machine this repo was measured on — a Ryzen 7 8745HS in a Geekom A8. The step checks `/proc/cpuinfo` and DMI before writing anything, so on any other hardware it is inert whether or not `ryzenadj` is installed. `ryzen_smu` (DKMS) is optional and only buys the read-back of the live limits |
| `pacman -S` (daemon) | `keyd` | Figma's Cmd+click / Cmd+scroll (step 8b). The only dependency that is a system service rather than a program, and the only one `apply.sh` configures with **sudo** — it writes `/etc/keyd/default.conf` and adds you to the `keyd` group. Install it *before* applying, or the step skips and you re-run later |
| `mise use -g` | `hunk` `gh` | the `git diff` pager and the generated theme its hook writes; `gh` is what the row below runs through — this machine takes it from mise rather than `pacman`, so it is missing from a package-list restore too |
| `gh extension install` | `dlvhdr/gh-dash` | the `dash` alias, and its theme-set colour hook |
| Cursor marketplace | `beardedbear.beardedtheme` `beardedbear.beardedicons` | the Cursor colour + icon theme. The only marketplace dependency in the whole override; without them Cursor silently falls back to its defaults |

`hunk`, `gh` and `gh-dash` are the three that are not packages, so a
`pacman -Qqe` restore will not bring them back:

```bash
mise use -g hunk gh
gh extension install dlvhdr/gh-dash
```

**How each one fails if you skip it.** Only some of these are guarded, and the
difference matters — `apply.sh` runs under `set -euo pipefail`, so "degrades" is
a property of how the call is written, not a promise:

- *Guarded, with a skip message*: `lsd` (alias + theme files), `yazi`,
  `lazydocker`, `gh-dash` and `hunk` (their theme configs), Cursor
  (`settings.json` merge), `imagemagick` (app-icon hook), `starship`
  (`|| skip`). `bibata-cursor-theme-bin` warns but the cursor theme is set in
  `gsettings`/`hl.env` anyway, so it falls back **visibly** — the one omission
  you will notice unprompted.
- *Guarded, with a skip message, and the skip tells you the command*: `keyd`
  and `ytm-player`. Without `keyd`, Figma keeps Ctrl+click and Ctrl+scroll on
  the pinky; nothing else on the desktop changes, since the only remap is issued
  at runtime on Figma focus and dropped again on blur. Without `ytm-player`,
  the theme template and its hook are skipped — and `python-secretstorage` is
  reported separately, because ytm can be installed and still fail to sign in.
- *Guarded at every interactive shell rather than at apply time*: the `ls`,
  `edit`, `diff` and `dash` aliases, and the `ytm` function. The guard is
  re-evaluated per shell, so installing the tool later is enough — no re-apply
  needed.

Two of those five are worth knowing about beyond the guard:

- **`diff` shadows `/usr/bin/diff`.** Its guard is `command -v hunk`, falling
  back to `git diff`, so on every machine this targets it is always active.
  Bash does not expand aliases in non-interactive shells, so scripts — including
  `apply.sh`'s own `diff -q` — still reach diffutils, and `command diff a b`
  does too. But an interactive `diff a b` is `hunk diff a b`, which is a
  different tool with different arguments and output. It is `hunk diff` rather
  than `git diff` because both things wanted here are impossible through
  `git/pager.conf`: git pipes its output to the pager, hunk treats piped stdin
  as pager mode, and pager mode closes the files pane before config is read and
  has no `--watch` at all. The reload itself comes from `watch = true` under
  `[vcs]` in `hunk/config.toml.tpl`, not from a flag here — scoped to that
  section because a top-level `watch` breaks the pager path. Two costs come with that. watch refuses a
  non-terminal stdout and there is no `--no-watch`, so `diff > out.patch` and
  `diff | grep` fail — use `git diff`, which is unchanged and still paints
  through the hunk pager. And git-only flags (`--stat`, `-w`, `--name-only`)
  are rejected by hunk's parser, while untracked files are now included. If you
  want diffutils back, delete the line from `bash/shell.sh` rather than from
  `~/.bashrc`, or the next apply puts it back.
- **`ytm` is a function, not an alias, and it is not cosmetic.** It runs ytm
  with `:GNOME` appended to `XDG_CURRENT_DESKTOP`. yt-dlp maps that variable to
  a Chromium cookie-decryption backend and its table has no entry for Hyprland,
  so it falls through to a backend that assumes unencrypted cookies and returns
  no key — while Chromium here runs `--password-store=gnome-libsecret` and
  writes v11. Without the wrapper every cookie fails to decrypt, which breaks
  `cllpse-ytm-signin` *and* ytm's own silent session renewal, turning every
  token expiry into a manual re-signin. Hyprland stays first in the list, so
  everything else that reads the variable is unaffected.
- *Degrades with no message naming the tool*: `jq`. Every call sits inside an
  `if` condition or ends in `|| true`, so a missing `jq` skips the Cursor merge
  and step 7h instead of aborting, but nothing says why.
- *Falls back silently*: the two Bearded Cursor extensions. The settings keys are written either way; Cursor just uses its own default theme and icons until the extensions are installed.
- *Harmless when absent*: `bat`, `lazygit` (their config files are copied
  regardless — a config for a program you have not installed yet), `fzf`
  (`FZF_DEFAULT_OPTS` is exported and simply unused), `hunk` (git writes the
  diff to stdout and exits 0, measured — inert, not broken).
- *An actual trap*: `ghostty`. `sync_fenced` **creates** its target, so on a
  machine with no `~/.config/ghostty/config` the file it writes contains only
  our block — losing Omarchy's `config-file` line and with it the theme colours.
  See the gaps table below.

## What `apply.sh` does

| # | Action | Target |
|---|---|---|
| 0 | Record the font and theme the machine had *before* the first apply, so `revert.sh` has something true to restore. Written once; values already ours are refused | `~/.local/state/cllpse-macos/previous-{font,theme}` |
| 1 | Symlink both `omarchy-cllpse-theme/` folders as themes, and `omarchy-cllpse-switcher/` as a plugin | `~/.config/omarchy/themes/omarchy-cllpse-theme-{dark,light}`, `~/.config/omarchy/plugins/cllpse.window-switcher` |
| 2 | Install SF fonts + fontconfig drop-ins (UI font + hintnone) | `~/.local/share/fonts/SF/`, `~/.config/fontconfig/conf.d/{99-cllpse-macos-ui-font,11-cllpse-macos-hinting}.conf` |
| 3 | Monospace → SF Mono (Omarchy's own knob) | `omarchy font set` → terminal configs + `fonts.conf` |
| 4 | GTK/GNOME fonts → SF Pro / SF Mono | `gsettings org.gnome.desktop.interface` |
| 5 | Font hinting → `none` — SF faces render unhinted; grid-snapped stems read as sharp under grayscale AA (Wayland fractional scaling) | `gsettings … font-hinting 'none'` (GTK/GNOME) + fenced `freetype-load-flags = no-hinting` in `~/.config/ghostty/config`, on top of Omarchy's stock config (fontconfig side is the step-2 drop-in) |
| 5b | GTK window buttons → none. Hyprland draws no titlebars; a GTK/libadwaita app's min/max/close is its own CSD, laid out from this key. `':'` vs Omarchy's `'appmenu:close'`. Electron/Qt ignore it — Cursor's are step 7 | `gsettings org.gnome.desktop.wm.preferences button-layout ':'` |
| 5c | Danish letters on the Preonic's M0 layer — a static, single-group xkb symbols file with no toggle and no compose. Referenced by `hyprland-env.lua`'s `kb_layout`, which is why step 6's block wins over a layout set in the user files | `~/.config/xkb/symbols/us-danish-letters` |
| 6 | `OMARCHY_MENU_FONT` + cursor theme + `no_warps` + keyboard layout (`hyprland.lua`), decoration/blur/opacity/animations (`looknfeel.lua`), window-switcher keybinds (`bindings.lua`), mouse tuning (`input.lua`) + `decoration` (`rounding = 18` / `rounding_power = 2.0` — a plain circular arc, the squircle having been tried and dropped / `border_part_of_window = true`, `blur` on @ size 7 / passes 4 / vibrancy 0.30, `border_size = 2`, `gaps_in/out = 12/24`) + window `opacity = 0.99 0.875` (re-matched onto `chromium-based-browser` / `firefox-based-browser` too, since Omarchy pins those to `1.0 0.985` otherwise) + 3× animation speeds (floor 1) + `layer_rule` blur on the shell surfaces + `layer_rule` re-enabling the layer fade on the keyboard-driven panels, and `no_anim` on the window switcher (which fades its own scrim in QML) | fenced blocks synced into `~/.config/hypr/hyprland.lua` and `~/.config/hypr/looknfeel.lua` |
| 6b | Keybind allowlist + macOS-parity shortcuts. `keybind-scan.lua` sandboxes the live `hyprland.lua` (fake `hl`/`o`, no live Hyprland IPC) to enumerate every bind in effect; `keybind-allowlist.conf` seeds from that scan once and is yours from then on — delete a line to have the next apply unbind it; `keybind-unbinds.lua` is regenerated from the current allowlist on every apply, so an Omarchy update that adds new default binds gets pruned too, without reseeding. `macos-shortcuts.lua` (word/line navigation, close/undo/redo/save, quit — synthesized via `send_key_state`, guarded off inside terminals where forwarding Ctrl+Z/W/S would be destructive) and `window-management-mod.lua` (window nav/arrangement moved `SUPER` → `CTRL+ALT`, working around the Preonic firmware's key overrides suppressing `SUPER` on the keys they trigger on) are synced in *after* the unbinds, so their own binds land fresh every run | `overrides/hypr/keybind-allowlist.conf` (seeded once, user-owned, committed); `overrides/hypr/keybind-current.conf` + `overrides/hypr/keybind-unbinds.lua` (both regenerated every run in the repo itself, gitignored); three more fenced blocks (`: keybinds`, `: macos-shortcuts`, `: window-management-mod`) in `~/.config/hypr/bindings.lua` |
| 7 | `bat` / `lazygit` / `lazydocker` / `fzf` / `lsd` / `yazi` colours → terminal ANSI (`gh-dash` cannot: see *How each app is themed*) (see *How each app is themed* for which mechanism each uses, and why `msedit` needs none) (`lsd` additionally needs `color.theme: custom` in its own config to read the ANSI remap, since it otherwise pins several colours to fixed 256-colour indices); Cursor editor prefs (Bearded colour + icon theme selected via `autoDetectColorScheme`, so the editor follows Omarchy's light/dark through `gsettings color-scheme` rather than through `workbench.colorTheme`, which Omarchy overwrites on every theme-set; whitespace/format-on-save, chrome trimmed — activity + status bars, menu bar, layout control, agents-window button and the `custom` title bar's min/max/close all hidden) merged into `settings.json` with `jq` — our keys win, `workbench.colorTheme` left to Omarchy. The Bearded keys are the override's one marketplace dependency; everything else in it is a stock Cursor key; tool aliases (`edit` → msedit, `diff` → `hunk diff` — a live-reloading working-tree review with the files pane open (both from `hunk/config.toml.tpl`, not flags), which shadows `/usr/bin/diff` in interactive shells, `log` → `hunk log` — the commit browser that pairs with it, shadowing nothing, `dash` → `gh dash`) plus the `ytm` function (which fixes yt-dlp's keyring backend, not just the name), each guarded on its tool the way the `ls` → `lsd` alias is — `gh-dash` is a gh *extension* rather than a binary, so its guard tests the extension directory instead of shelling out to `gh extension list` (34ms, on every interactive shell); `git diff` routed through the `hunk` pager via a fenced block in `~/.config/git/config` — fenced rather than copied because that file is Omarchy's stock config plus the user's own `[user]` identity block, which must not come from this repo, and seeded from `/usr/share/omarchy/config/git/config` first when absent so a fresh machine doesn't get a git config consisting only of our block | `~/.config/bat/config`, `~/.config/lazygit/config.yml`, `~/.config/lazydocker/config.yml`, `~/.config/lsd/{config,colors}.yaml`, `~/.config/yazi/theme.toml`, `~/.config/gh-dash/config.yml` (merged), `~/.config/Cursor/User/settings.json`, fenced blocks in `~/.bashrc` and `~/.config/git/config` |
| 7\* | Starship prompt colours track the active theme's `accent` (the same hue driving Hyprland's active border) — Starship has no Omarchy-aware theming and no config-import mechanism like Ghostty/Alacritty/foot, so this hooks into `omarchy-hook theme-set` instead of a `themed/*.tpl`; regenerates `~/.config/starship.toml` on every theme switch, and once now so it doesn't wait for the next one. The template also swaps the built-in `git_branch` for a `custom.git_branch` that truncates in the middle (`chromium-scale-and-ghostty-fixes` → `chromium-sc…hostty-fixes`, 24 chars incl. the ellipsis) — Starship only truncates from the head Alongside it, `hunk-colors.sh` bakes the same palette into `~/.config/hunk/config.toml` — hunk is the one tool here that cannot name ANSI slots (hex-only validator, Shiki-only built-ins), so its diff backgrounds are blended over the theme background at 18%/30% and its Shiki `base` follows the `mode` key | `~/.config/omarchy/hooks/theme-set.d/{starship-colors,hunk-colors}.sh` (symlinked), `~/.config/starship.toml`, `~/.config/hunk/config.toml` |
| 7b | Restore saved display scaling + text size from `display.conf` (skipped if the file is absent; each empty key skipped) | `omarchy display text size`, the two scale variables in `~/.config/hypr/monitors.lua` |
| 7c | Install session environment drop-ins (Figma → native Wayland) | `~/.config/environment.d/50-cllpse-macos-figma-wayland.conf` |
| 7d | Chromium: `--force-device-scale-factor=1` (browser UI 20% under DP-2's 1.25) + `110%` default page zoom — page size is the product of the two, and 125% would be exactly 1:1 with native; `--enable-features=…,OverlayScrollbar` for the thin auto-hiding scrollbar (restating Omarchy's own feature, because a repeated `--enable-features` is last-wins rather than merged); `--disable-features=MediaSessionService`, the only lever that removes the global-media-controls button beside the profile avatar — at the cost of Chromium's MPRIS export (media keys, now-playing widgets); and a neutral browser UI — Omarchy's `BrowserThemeColor` policy runs our grey seed through Material's tonal-spot scheme and comes back cyan, which takes both the system (GTK) theme (frame and menus) and grayscale (the accent: the omnibox focus ring is a dark teal without it) | fenced block in `~/.config/chromium-flags.conf` + `partition.default_zoom_level`, `extensions.theme.system_theme` and `browser.theme.is_grayscale2` in each `~/.config/chromium/*/Preferences` |
| 7e | Figma Desktop's launcher entry. The app regenerates its own entry on every launch (`AppRun: integrate_desktop`) and gets two fields wrong for this desktop: `Name=Figma` (its AppStream `<name>` and `X-AppImage-Name` both say *Figma Desktop*) and `StartupWMClass=Figma` against a live Hyprland class of `figma-desktop` — so nothing that joins an entry to a window through that value lands, including the window switcher's class → entry lookup, which is where its tile label comes from. Rendered from a template (`{{ home }}` expanded), skipped entirely if Figma isn't installed. The regeneration only fires when `Exec` differs from `Exec="${appimage_path}" %u`, which for an extracted directory is `readlink -f "$0"` — a path with no version in it, so the template's Exec matches on every release and the entry is never taken back. The step also **removes a wrapper around `AppRun`** if it finds one: a wrapper displaces the launcher to `AppRun.real`, which is what breaks that path in the first place, and lives inside the app directory where the next extraction deletes it | `~/.local/share/applications/figma-desktop-appimage.desktop`, and `~/Applications/figma-desktop/AppRun` restored if wrapped |
| 7f | Flat app icons for the menu. The menu renders non-app rows as Nerd Font *text* tinted `foreground` (the flat look) but app rows as a plain `Image` of the vendor's icon with no recolouring — 48 of 52 visible entries here resolve to a full-colour logo. `AppLibrary.qml` checks its own `find`-built index *before* Qt's themed lookup, and `$HOME/.icons` is the first directory in both its svg and png passes, so a file dropped there outranks every installed theme; with no `index.theme` it stays invisible to GTK and Qt. **Nothing is generated** — `icons/fallbacks/` holds hand-placed SVGs, one per desktop-entry `Icon=` value, and an app with no file there simply keeps its vendor icon. Synced by a `theme-set` hook rather than here, because app icons are never recoloured by the shell: a synced file has a fixed colour and must be rewritten per theme, and the shell restart `omarchy theme set` performs is what drops Qt's image cache so the new colour lands. SVG paints are repainted — attribute *and* CSS-block fills, both quote styles, `fill="none"` preserved so outline shapes stay outlines, and a root fill injected when a file carries no paint at all (simple-icons ships bare `<path d>`, which would otherwise render black). PNGs are masked by their alpha. A file that fails to parse is skipped, so a missing icon means a malformed drop-in | `~/.icons/cllpse-flat/apps/`, `~/.config/omarchy/hooks/theme-set.d/app-icons.sh` (symlinked) |
| 7f2 | Post-update repair hook. Everything `apply.sh` installs is either in a directory that is ours alone (`~/.icons/`, `~/.local/`, `~/.config/hypr/`) or a **symlink inside a directory Omarchy ships and manages** (`~/.config/omarchy/{hooks,themes,plugins}/` — Omarchy's own `config/omarchy/hooks/theme-set.d/` carries `.sample` files, so those paths are its territory). The second group is exposed: a refresh, migration or future install step that repopulates one of them takes our symlink with it and nothing reports the loss — icons would just revert to vendor logos at the next theme change. `omarchy-update` calls `omarchy-hook post-update` (`omarchy-update:49`), so a hook there re-links all of it once per update. Idempotent, so it runs unconditionally rather than trying to detect damage. Deliberately does **not** repair `shell.json` — that file is personal, and rewriting it from a hook mid-update is a worse failure than the one it prevents | `~/.config/omarchy/hooks/post-update.d/cllpse-macos-repair.sh` (symlinked) |
| 7h | Omarchy shell config, five targeted `jq` key writes — never a whole-file copy or deep merge, since the file also holds `idle`, `version` and other plugins' widget config, and `plugins[]` is an array a merge would replace rather than append to. **`plugins[]`**: enable the window-switcher (entry keyed by the manifest id — step 1's symlink only *installs* it; without this entry the HUD never loads and nothing says so). **`bar.transparent`**: true (Omarchy ships false). **`bar.layout`** + **`bar.centerAnchor`** + **`disabledPlugins`**: from `omarchy/shell-bar.json`, the recorded bar. `disabledPlugins[]` reaches only first-party *non-widget* plugins — panels and services (`PluginRegistry.qml:148-165`); a widget is disabled by absence from the layout, which is also the whole uninstall for a third-party one. The tray's `pinned`/`hidden` arrays are carried over from the live file rather than replaced — they name items that exist on this box. `centerAnchor` stays at Omarchy's `omarchy.clock` although no clock is in the layout: with the anchor absent `Bar.qml`'s `hasAnchor` is false and the center section just centres as a block (`Bar.qml:1538`), so the key is inert until a clock comes back. The pre-existing values are recorded once for `revert.sh`, refusing values already ours | `~/.config/omarchy/shell.json` |
| 8 | Apply the theme — refreshes whichever cllpse-macos theme is already active, else sets dark | `omarchy theme set …` |
| 8b | keyd, for Figma alone: an identity `default.conf` pinned to the Preonic that also *defines* the inert `[figma:C]` layer, the focus helper, and the `keyd` group grant. Nothing is remapped until Figma takes focus, at which point `macos-shortcuts.lua` binds `leftmeta = layer(figma)` in the running daemon and drops it again on blur — Figma reads `ctrlKey` and ignores `metaKey` off macOS, and Hyprland has no pointer-button or scroll-axis dispatcher to translate Cmd+click / Cmd+scroll with. Needs **sudo**. keyd re-reads that config only at start, so this step's `systemctl restart` is the *only* thing that publishes an edit to `keyd/default.conf`; it ends by binding the layer and releasing it as a smoke test, because every link in the chain fails silently | `/etc/keyd/default.conf`, `~/.local/bin/cllpse-figma-keyd`, the `keyd` group |
| 8c | `hyprctl reload` — determinism, since autoreload already covers the hypr files. After 8b on purpose: a keyd restart drops every runtime bind, and the reload is what makes `macos-shortcuts.lua` re-seed its remap state from the live focus | the running compositor |
| 9 | Chromium context-menu declutter: spellcheck, translate, password-save prompt, address/card autofill, Print, Cast, "Create QR Code", and "Add to reading list" off — all eight as enterprise policy, none as a Preferences key. (An earlier version wrote the first five as plain `Preferences` booleans; a bare pref only changes the default, so Settings still showed the toggle as user-changeable, and per Chrome's own docs the bare `translate.enabled` pref doesn't suppress the manual "Translate to…" context-menu entry the way the `TranslateEnabled` policy does — confirmed live, plus four of those five keys have a dot in their real pref name and Chromium nests dotted pref names into nested JSON on write, so a flat key with a literal dot in it is never read back at all.) Needs **sudo** (the only step in this script that does), and only writes into `/etc/chromium/policies/managed/` if that directory already exists — mirroring Omarchy's own guard, so a machine without Chromium doesn't get handed a policy root it didn't have. No relaunch needed if Chromium is running: step 8's `omarchy-theme-set-browser` already calls Chromium's `--refresh-platform-policy` on every theme-set, which reloads this file too, same as Omarchy's own `color.json`. The same file also carries `ExtensionInstallForcelist`, which pins two extensions by ID against Google's CRX endpoint: **uBlock Origin Lite** (`ddkjiahejlhfcafbddmgiahcphecmpfh`) and **Proton Pass** (`ghmbeldphafepmbegfdlkpapadhbakde`). uBOL rather than uBlock Origin because MV2 is gone — Chromium 152's binary contains no `ExtensionManifestV2Availability` string at all, so there is no longer a policy to force MV2 back on; Proton Pass is the other half of `PasswordManagerEnabled: false`, which otherwise leaves nothing offering to store a credential. Both are unremovable from `chrome://extensions` while the file is in place, and uBOL's filtering mode is a per-profile setting with no policy behind it — raise it from Basic to Optimal by hand, once | `/etc/chromium/policies/managed/cllpse-macos.json` |
| 10 | CPU power limits: `ryzenadj` at 52W sustained / 58W burst, reapplied at **boot and on resume** by `ryzen-tdp.service` — runtime SMU settings persist across neither, so a machine tuned by hand is back at the firmware's 45W the next morning with nothing on it to say so. **Hardware-gated**: the step refuses unless `/proc/cpuinfo` reads 8745HS and DMI reads GEEKOM/A8, because 52W is a number for one chassis, not a general setting. Needs **sudo**, and does not install `ryzenadj` | `/etc/default/ryzen-tdp`, `/etc/systemd/system/ryzen-tdp.service` |
| 11 | Btrfs compression: `compress=zstd` (a bare `zstd` is the kernel's level 3) → `compress=zstd:1` on every btrfs line in `/etc/fstab`, then a live `mount -o remount` of each so it doesn't wait for a reboot. Level 3 costs ~2–3× the CPU of level 1 at compression for ~5–10% better ratio — the wrong trade on a disk that is 4% full and a CPU that is thermally capped. Backs `/etc/fstab` up first, rewrites **only** lines whose FS-type field is `btrfs` (a commented line, a `compress-force=`, or the same string on an ext4 line are all left alone — tested), and verifies with `findmnt --verify` before leaving it in place, restoring the backup if that fails. Bails out entirely if the machine mounts btrfs at mixed levels. Needs **sudo** | `/etc/fstab`, plus a live remount of each btrfs mountpoint |

`7\*` is not a separate step in the script — starship, the Cursor chrome repaint, yazi's syntect theme, hunk and ytm-player are all theme-set hooks installed from inside step 7. It is split out here because a hook behaves differently from a config file: it re-runs on every `omarchy theme set`.

Step 7 has two targets that are **not** config files, both in Cursor's
`~/.config/Cursor/User/globalStorage/state.vscdb`. Neither has a settings key, so
`cursor/settings.json` cannot carry them, and Cursor updates flip both:

- `cursor/unifiedAppLayout` → `agent` replaces the editor tab bar with the agent
  pane's own strip (enum `{ Agent: "agent", Editor: "editor" }`, default
  `editor`).
- `cursor/noTitlebarLayout.visibility` → `hide` applies a **-35px top inset to the
  whole workbench**, exactly one tab-strip height, on the assumption that the tabs
  themselves serve as the titlebar. With this override's `window.controlsStyle` /
  `menuBarVisibility` hidden the titlebar part is already collapsed, so the inset
  eats the tab strip instead.

Both present identically as *the tabs have disappeared*, with
`workbench.editor.showTabs` unset (still `multiple`) and every `tab.*` colour
correct. `apply.sh` writes the right value over the one wrong value only: an
absent key is Cursor's default and is left absent, any other value is a
deliberate choice and is left alone, and the
`cursor/migrateEditorMode.forceUnified` latch behind the first one is left at
`true`, because clearing it invites the migration to run again. Prior values go to
`$STATE/previous-cursor-layout` and `$STATE/previous-cursor-titlebar`, which is
all `revert.sh` acts on. Both the write and the revert are skipped while Cursor is
running — it holds that DB open and rewrites it from memory — and the running
check resolves `/proc/<pid>/exe`, since Cursor's process name is `electron` and
neither `pgrep -x` nor `pgrep -f` can test for it.

The blur `layer_rule` only opts the shell surfaces *into* blur; the matching
translucency (`background-alpha`) is the theme's half —
`omarchy-cllpse-theme/*/shell.*.toml`. Blur shows nothing until both are in place. The rule's
namespace match also covers `omarchy-window-switcher-hud`, so the
`omarchy-cllpse-switcher/` plugin (symlinked in step 1) blurs like the menu.

A second `layer_rule` re-enables Hyprland's layer fade (measured ~100ms) for the
keyboard-driven panels — menu, clipboard, emojis, image-selector,
keyboard-panel. The window switcher is deliberately excluded and gets a third
rule keeping `no_anim`: it fades its scrim alone from inside `Hud.qml` (120ms,
`Easing.OutCubic`), which the compositor cannot express because a card and its
scrim are a single layer surface. The Omarchy panels cannot do the same without
patching their own `Menu.qml`. Omarchy opts those
out in `default/hypr/apps/omarchy-shell.lua` while leaving notifications, OSD,
polkit and reminders fading, so the shell was inconsistent with itself; layer
rules accumulate and ours load later, so this needs no edit to Omarchy's file.
The bar is deliberately excluded: it is persistent chrome, so the fade would
only ever show on a shell restart.

Injected blocks are wrapped in `>>> cllpse-macos overrides >>>` fences (comment
leader `--` in Lua, `#` in shell — Ghostty config takes `#`), optionally suffixed
`: <name>` for a second/third/fourth block in the same file (`bindings.lua` carries
four: the plain one plus `: keybinds` / `: macos-shortcuts` / `: window-management-mod`);
`revert.sh` deletes all of them, matching the suffix generically. Pre-existing
`~/.config/bat/config` / `~/.config/lazygit/config.yml` /
`~/.config/lsd/{config,colors}.yaml` / `~/.config/Cursor/User/settings.json` /
`~/.config/starship.toml` are saved as `*.pre-cllpse` and restored on revert.

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

## How each app is themed

Omarchy repaints the terminal's 16-colour ANSI palette from the active theme's
`colors.toml` on every `omarchy theme set`. Any TUI that names palette *slots*
rather than literal colours therefore follows a theme switch for free, with
nothing to regenerate. That is the preferred mechanism here, and most of these
take it:

| App | Mechanism | Notes |
|---|---|---|
| `bat` | ANSI | `--theme=ansi` |
| `lazygit` | ANSI | colour names + `bold`/`reverse` per theme key |
| `lazydocker` | ANSI | same gocui colour layer and vocabulary as lazygit; four theme keys rather than lazygit's seven |
| `lsd` | ANSI | `color.theme: custom` opts into `colors.yaml`; filetype colours go through `LS_COLORS` in `bash/shell.sh` instead |
| `fzf` | live palette | `FZF_DEFAULT_OPTS` is *derived* in `bash/shell.sh` by reading `colors.toml` at shell start — real hex, not slots, because fzf needs more than 16 distinct roles |
| `yazi` | ANSI + generated | Split by surface. **Chrome, filetypes and icons are ANSI** — the chrome preset already was; the ~725 icon rules were fixed hex and are regenerated onto ANSI names by `yazi/generate-icons.py`, which reads the table out of the installed binary (re-run after a yazi upgrade). **The previewer is generated**: syntect reads a `.tmTheme`, which is hex-only, so `yazi-syntax.sh` bakes one per theme. That is a deliberate trade — unset, the previewer highlights in ANSI and tracks the terminal live; set, it gets the full macOS palette and Xcode's project-vs-system symbol split, but only updates at theme-set. Delete `syntect_theme` from `yazi/theme.toml` to go back |
| `gh-dash` | baked hex (theme-set hook) | termenv resolves a bare index against its OWN table and emits converted RGB, so slots 0-15 never reach the terminal — measured on v4.25.2, `"4"` rendered as xterm navy. Hex, regenerated per theme, is the only thing that tracks |
| `starship` | generated | no ANSI surface worth using; `accent` is substituted into a template by a `theme-set` hook |
| `yazi` previewer | generated | see the `yazi` row above |
| Cursor chrome | generated | The colour theme is Bearded, chosen for its editor and syntax colours, but everything around the code was its own palette — a grey frame, blue-tinted `#202027` text fields and cyan/teal accents — against a desktop that is flat neutral with a `#007AFF` accent. `cursor-chrome.sh` now copies **everything except the editor canvas** out of Omarchy's *own* generated `vscode-theme.json` into `workbench.colorCustomizations`, which sits above the active theme: 487 of the 624 keys in each scope. `$KEEP` is the exception list (the code area, brackets/guides/line numbers/cursor, `symbolIcon.`, and the overview ruler + minimap marks, which have to agree with the canvas); `$EXACT` takes three surfaces back from it (`editor.background`, `editorGutter.background`, `minimap.background`). On top of the copy: every hover/active state is normalised onto the tab's 25% `muted` wash — Omarchy paints several of them the window colour (no feedback) or opaque `muted` (far heavier than a selected tab) — and the three families Cursor registers that Omarchy has no key for (`inlineEdit.`, `scmGraph.`, `errorLens.`) are re-tinted to `charts.*` hues while keeping the alpha the Bearded variant gave them. Values come from Omarchy's generated file rather than a second derivation of `colors.toml`, so there is nothing to drift, and both modes are correct by construction. Only the editor canvas and its syntax stay Bearded |
| `hunk` | generated | **cannot** use ANSI — its validator takes hex only (`must be a hex color like #112233`) and every built-in theme is a bundled Shiki theme. A `theme-set` hook bakes `colors.toml` into `~/.config/hunk/config.toml`, including tinted diff backgrounds blended over the theme background |
| `ytm-player` | generated + a flag | Two halves, because one of them is out of reach of a colour file. `themed/ytm-player.toml.tpl` renders per theme and the hook copies it to `~/.config/ytm-player/theme.toml`; but `theme.toml` cannot set Textual's `dark` flag, and that flag drives every *derived* contrast token, so the hook also rewrites `[ui] theme` in `config.toml` to `textual-light`/`textual-dark` from the theme's own `mode`. Insert-or-replace on that one key, so the preferences `apply.sh` wrote stay put |
| `msedit` | nothing to do | it queries the terminal for its palette (emits OSC `4`/`10`/`11`, parses the `rgb:` replies) and has no colour config at all — its `settings.json` holds only `files.associations`. It already follows the theme |

The generated ones are the fragile half: a hook writes the whole file, so a
hand-edited `starship.toml`, `hunk/config.toml`, `yazi/cllpse-macos.tmTheme` or
`ytm-player/theme.toml` is overwritten at the next theme switch. The first two are backed up once before
their first run; the yazi `.tmTheme` is not, because nothing pre-existing lives
at that path — it is a file this repo introduces.

The generated ones also need contrast work the ANSI ones get for free. A palette
slot is whatever the terminal paints it, but a literal hex has to be legible
against a literal background, and these themes' system hues are macOS *UI* fills
rather than text colours: on the light theme, `systemYellow` `#FFCC00` sits at
1.51:1 against the `#FFFFFF` window background — invisible as code. So
`yazi-syntax.sh` raises each hue toward the background's opposite in 2% steps
until it clears WCAG 4.5:1 (3.0:1 for comments, which are meant to recede),
stopping at the first step that passes so the macOS hue is darkened as little as
possible — `#FFCC00` lands on `#8E7200` at 4.61:1. On the dark theme most hues
already clear the bar and pass through untouched.

## What `apply.sh` does and does not guarantee

Within what it controls it is deterministic: every step is idempotent, fenced
blocks are replaced rather than appended so a re-run converges on the snippet,
pre-existing state is recorded once and never overwritten, and re-running changes
nothing that already matches. Running it twice gives the same result as once.

It is **not** a complete machine build. On a clean install these are the gaps:

| Gap | Effect |
|---|---|
| **Four steps use sudo (8b's keyd config and group grant, step 9's Chromium policy, step 10's CPU power limits and step 11's `/etc/fstab` compression level), all deliberately near the end.** No package installation happens anywhere — `keyd` in particular must already be present, and step 8b skips with the `pacman -S keyd` line if it is not — see *Before running `apply.sh`* above for the full list and what each omission costs. `bibata-cursor-theme-bin` is the only one that fails loudly-ish (warned about, and the cursor theme is set in `gsettings`/`hl.env` regardless, so it falls back visibly); every other guard skips in silence. The two non-package channels, `mise` (`hunk`, `gh`) and `gh extension` (`gh-dash`), won't be restored by a `pacman -Qqe` rebuild | Cursor visibly wrong; other items silently absent |
| **Cursor editor not installed.** The `settings.json` merge is skipped when both `/usr/bin/cursor` and `~/.config/Cursor/User/` are absent. The override carries no marketplace-extension keys, so nothing in it needs a network step | Merge skipped on a machine without Cursor |
| **Third-party plugins are not installed.** `apply.sh` has no source URL for any of them, and step 7h's recorded `bar.layout` names none — the widgets that were there (`dizziee.system-updates`, `jankeesvw.notification-center`, `io.github.twiking.omasettings`) were removed along with the plugins. Since a third-party plugin is enabled iff its id appears somewhere in `shell.json`, a layout without it *is* the uninstall as far as the shell is concerned; the plugin directory under `~/.config/omarchy/plugins/` still has to be deleted by hand | Nothing to render, and nothing to install |
| **`display.conf` values are hardware-specific** — text size 14, monitor scale 1.25, GDK scale 1 are tuned for one ~110 PPI 3840x1600 display. `gdk-scale` in particular is wrong on a HiDPI panel, where Omarchy's default of 2 is right | Wrong sizing on different hardware, applied confidently |
| **Some settings need a relogin** — the `environment.d` drop-ins (Figma → Wayland, FreeType darkening) and `OMARCHY_MENU_FONT` are read at session start | State immediately after `apply.sh` is not the final state |
| **`sync_fenced` creates the target if absent.** If `~/.config/ghostty/config` does not exist, the file it writes contains only our block — losing Omarchy's `config-file` line that pulls in theme colours | Terminal colours silently unthemed |
| **Plugin-owned regions are won on file position, not ownership.** A settings plugin writing its own block into `looknfeel.lua`/`input.lua` beats ours if it lands later — and its block outlives the plugin, since uninstalling leaves it behind. OmaSettings is the sharpest case: it writes a whole separate `~/.config/hypr/omasettings.lua` and appends `require("hypr.omasettings")` to the *end* of `hyprland.lua`, i.e. after every user file, so while that file exists it wins every key it sets. Folding one of its values into this repo means deleting the line there too, not just adding it here. The keyboard layout sits after `default.hypr.toggles` for the same reason | Look/mouse/keyboard settings can be silently overridden by a leftover block |
| **Figma updates need one manual step, then `apply.sh`.** There is no self-updater: download the new AppImage and extract it over `~/Applications/figma-desktop/`, then re-run this script to restore the launcher entry. Nothing inside the app directory belongs to this repo, so an extraction has nothing of ours to destroy | Extract, then `apply.sh` — no hand-editing |
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
- **The flat app icons (7f) appear as soon as the menu next opens** — `AppLibrary.refreshIcons()` rescans when a consumer opens, so no restart is needed to *find* them. Changing their *colour* is different: Qt caches decoded images by URL, and the path does not change between themes, so a re-render only shows up after the shell restart that `omarchy theme set` performs anyway.
- **Quit Chromium before the step 7d zoom and theme halves**, and relaunch after. Chromium rewrites `Preferences` from memory on exit, so a write made while it is running is discarded; the script detects this and skips rather than reporting a change that will not survive. The flag half needs only a relaunch. Sites already zoomed with ctrl+/- keep their own `per_host_zoom_levels` and ignore the default.
- **Step 9 (the whole managed policy — the context-menu declutter *and* the two force-installed extensions) needs no relaunch** if Chromium is already running: `omarchy-theme-set-browser`, which step 8 always runs, calls `chromium --refresh-platform-policy --no-startup-window` whenever Chromium is running — the same live reload Omarchy uses for its own `color.json` — and that reloads the whole managed-policy directory.
- **DevTools is deliberately not in the policy.** `DeveloperToolsAvailability: 2` was there originally, as part of the same context-menu declutter, and it was the one key whose blast radius went past the menu — it blocks Inspect *everywhere*, local dev servers included. The key is now dropped rather than set to `1`, so Chromium's own default applies (`0`: available except on force-installed extensions); a managed policy should only assert what we actually have an opinion about. "Inspect" is back in the context menu as a consequence — no lever separates the two. That default now bites in one place: `0` means "available except on force-installed extensions", and as of the forcelist there are two of those, so uBOL's and Proton Pass's own pages and service workers cannot be inspected. They are not pages we wrote, so nothing is lost — but it reads like a DevTools bug the first time you hit it.
- **Figma's `figma://` login needs the launch to stay under 9 argv elements, and `FIGMA_USE_WAYLAND=1` is what pushes it over.** [electron/electron#52020](https://github.com/electron/electron/issues/52020): when a second instance hands its argv to the running one across the singleton socket, a payload of **9 or more elements fails to parse** — Chromium logs `additional_data_size exceeds payload length` from `process_singleton_posix.cc` — and the second instance then *seizes the lock and kills the first*. Eight or fewer is fine. `build_electron_args()` adds one flag for XWayland and four for native Wayland, so the native path is `electron` + 6 flags + `app.asar` + the URL = **exactly 9**; XWayland installs sit at 6 and never see this. The symptom is not a login error: the app **closes and reopens** and asks you to log in again, forever, because the browser's `figma://app_auth/redeem?g_secret=…` is lost in the failed handoff and every retry burns a fresh secret the same way. `install-figma.sh` comments out the two Wayland IME flags after every install to bring the native path to 7 — the one thing this repo writes *inside* the app directory, which is why it must be reapplied on each update. Diagnose from `~/.cache/figma-desktop-linux/launcher.log`: it records every launch's full argv, and the error appears there verbatim.
- **What the argv cap costs, and the alternative if that changes.** Only Wayland input-method support, in Figma alone. fcitx5 here runs a bare `keyboard-us` passthrough with no engine installed, and the Preonic's Danish letters come from xkb via `wl_keyboard`, which `text-input` is not in the path of — so nothing on this machine currently uses those two flags. Install a real fcitx5 engine and it becomes a live loss. The alternative, verified working: drop `--enable-features=UseOzonePlatform,WaylandWindowDecorations` instead and keep both IME flags. `UseOzonePlatform` is default-on in this Chromium, so the app still runs natively (`hyprctl clients` reports `xwayland: false`), and the launch lands at 8 — correct, but with **zero headroom**, so one added upstream flag silently brings the login loop back. The IME pair is the better thing to give up while it is unused.
- **The `keyd` group grant (8b) needs a reboot, and a relogin is not enough.** `uwsm` starts Hyprland as a unit of the systemd *user manager*, and with logind's stock `KillUserProcesses=no` that manager survives a logout — so every process on the desktop keeps inheriting the group set the manager was created with. Measured: two full graphical logins after the grant, Hyprland's `/proc/<pid>/status` still read the old `Groups:`. The tell is `getent group keyd` listing you while `id` does not. Nothing is broken in the meantime: `cllpse-figma-keyd` falls back to `newgrp`, which is setuid-root and reads `/etc/group` directly, so the remap works in the session that granted it — the reboot just moves it onto the fast path.
- **The CPU power limits (10) are live the moment the step runs**, and reapplied at boot and on resume — `ryzenadj` writes to the SMU at runtime and its settings persist across neither, which is the whole reason the unit exists rather than a line in a login script. Check them with `systemctl status ryzen-tdp`, or read them back with no root at all from `/sys/kernel/ryzen_smu_drv/pm_table` (STAPM limit, STAPM value, PPT fast limit, PPT fast value, PPT slow limit, PPT slow value — little-endian floats, in that order) if the `ryzen_smu` module is loaded. A `oneshot` that has already run shows as `inactive (dead)`; that is success, not failure.
- **Step 11's `zstd:1` applies to NEW writes only.** A mount option is not a property of the data — existing extents keep whatever level they were written at until something rewrites them. `btrfs filesystem defragment -r -czstd` would rewrite them and is deliberately *not* run: on a filesystem with Snapper snapshots it unshares extents and can multiply disk usage. Reads are unaffected either way, since zstd decompression speed is essentially level-independent.
- **The boot splash / login screen needs its own command, deliberately not run by `apply.sh`'s main flow**: `omarchy plymouth set by theme omarchy-cllpse-theme-dark` (or `-light`), which needs sudo. Step 8 prints this as a reminder.

## Contents

```
apply.sh  revert.sh  install-figma.sh
starship/starship.toml.tpl    stock starship.toml with {{ accent }} in place of every literal "cyan", plus a custom.git_branch module that middle-truncates long branch names to 24 chars
hooks/theme-set.d/starship-colors.sh  renders the template above into ~/.config/starship.toml on every theme switch
fonts/                        20 SF .otf (SF Mono, SF Pro Text, SF Pro Display)
fontconfig/conf.d/99-cllpse-macos-ui-font.conf   SF Pro for sans-serif/system-ui + optical-size crossover
fontconfig/conf.d/11-cllpse-macos-hinting.conf   hintstyle -> hintnone (overrides system 10-hinting-slight)
ghostty/ghostty.conf          freetype-load-flags = no-hinting, a few non-default prefs, and confirm-close-surface back on (Omarchy ships it off)
bat/config                    --theme="ansi"
lazygit/config.yml            gui.theme with ANSI colour names
lazydocker/config.yml         gui.theme with ANSI colour names (lazydocker's four keys)
yazi/theme.toml               ANSI theme; accent pinned to blue, chrome flattened onto `reset`, plus the regenerated ANSI icon table
yazi/generate-icons.py        rewrites yazi's ~725 icon rules onto ANSI names, read out of the installed binary — re-run after a yazi upgrade
yazi/cllpse-macos.tmTheme.tpl  previewer syntax theme with {{ placeholders }} — Xcode's scope assignment in the macOS palette; hex-only, so generated per theme
hooks/theme-set.d/yazi-syntax.sh  renders the template above into ~/.config/yazi/cllpse-macos.tmTheme on every theme switch, raising hues to 4.5:1 against the background
hooks/theme-set.d/cursor-chrome.sh  copies Omarchy's window-chrome colours into Cursor's workbench.colorCustomizations, scoped to the Bearded themes named in cursor/settings.json
cursor/cllpse-cursor-text-size      re-derives Cursor's editor.fontSize from `omarchy display text size`
cursor/cllpse-cursor-text-size.path systemd user path unit on ~/.config/omarchy/shell.toml that runs it
cursor/cllpse-cursor-text-size.service oneshot started by the .path unit above
gh-dash/theme.yml.tpl         theme.colors as HEX, baked from colors.toml by the theme-set hook and merged into gh-dash's own config.yml
hunk/config.toml.tpl          hunk's custom theme with {{ placeholders }} — hex only, so it is generated per theme
hooks/theme-set.d/hunk-colors.sh  renders the template above into ~/.config/hunk/config.toml on every theme switch
lsd/config.yaml               color.theme: custom (opts into colors.yaml below)
lsd/colors.yaml               user/group/size/date/etc. remapped from lsd's fixed 256-colour defaults onto basic ANSI; filetype colours (directory/executable/symlink/etc.) are LS_COLORS instead, in bash/shell.sh
cursor/settings.json          Cursor editor prefs, jq-merged in; omits workbench.colorTheme (Omarchy's) + extension-dependent keys
hypr/hyprland-env.lua         OMARCHY_MENU_FONT + cursor theme/size + no_warps + kb layout
hypr/window-switcher-bindings.lua  SUPER+TAB keybinds driving the switcher plugin
hypr/keybind-scan.lua         sandboxes hyprland.lua to enumerate every live bind (dump/unbinds modes)
hypr/keybind-allowlist.conf   seeded once from that scan, then user-owned -- delete a line to unbind it
hypr/keybind-unbinds.lua      generated every apply from the allowlist (gitignored)
hypr/keybind-current.conf     generated every apply, the raw scan before allowlist diffing (gitignored)
hypr/macos-shortcuts.lua      word/line nav, close/undo/redo/save/quit synthesized as Cmd-style chords
hypr/window-management-mod.lua  window nav/arrangement moved SUPER -> CTRL+ALT (Preonic firmware workaround)
hypr/input-tuning.lua         mouse sensitivity/accel + follow_mouse = 2 (scroll-under-cursor, click-to-focus) + wheel scroll_factor 1.5, trackpad 0.35
hypr/looknfeel-decoration.lua rounding 18 / rounding_power 2.0 (plain arc, no squircle) / border_part_of_window true / blur / border_size 2 / gaps 12,24 / groupbar off / window opacity 0.99 0.875 (the focused 1% is ~60% of the blur cost, kept deliberately; Figma fully opaque) / 3x animations, floor 1 / layer_rule blur on shell surfaces
bash/shell.sh                 FZF_DEFAULT_OPTS derived from the live palette + lsd alias/LS_COLORS + the edit/diff/dash aliases and the ytm keyring wrapper, each guarded on its tool
git/pager.conf                `git diff` through the hunk pager (fenced into ~/.config/git/config, which also holds the user's own [user] block)
display-lib.sh                shared readers/writers for scale + text size (sourced, not run)
display.conf                  saved text-size / monitor-scale / gdk-scale
save-display.sh               capture the live values into display.conf
environment.d/*.conf          systemd user-session env (Figma native Wayland, FreeType stem darkening on + stronger curve)
applications/figma-desktop-appimage.desktop.tpl  Figma Desktop's launcher entry -- corrects upstream's Name= and StartupWMClass=
install-figma.sh              installs/updates Figma Desktop from IliyaBrook/figma-linux: reads the installed version from the app's own bundled entry, refuses to extract over a running Figma, swaps the directory only after the extracted AppRun proves to be the real launcher, then runs apply.sh for the entry
cursor/derive-dark-from-light.py  generates the dark scheme FROM Bearded Theme Light: contrast-preserving for text, delta-mirroring for surfaces, verbatim for alpha/accents/transparent. Re-run after a Bearded update
cursor/bearded-dark-colors.json   GENERATED -- 318 workbench colours, merged by the theme hook under the chrome copy (dark mode only)
cursor/bearded-dark-tokens.json   GENERATED -- 55 textMate + 10 semantic rules, merged into settings.json by apply.sh, scoped to the dark variant so light mode is untouched
chromium/chromium-flags.conf  --force-device-scale-factor=1 + --enable-features=…,OverlayScrollbar + --disable-features=MediaSessionService (fenced into Omarchy's flags file)
chromium/chromium_prefs.py    shared plumbing for the two profile-preference scripts below
chromium/default-zoom.py      default page zoom -> 110% (no flag exists; it is a profile preference)
chromium/neutral-theme.py     system (GTK) theme + grayscale -> a neutral browser UI (the theme-colour policy can only give a tinted palette)
keyd/default.conf             identity config pinned to the Preonic, plus the inert [figma:C] layer the runtime bind activates (installed to /etc with sudo)
keyd/cllpse-figma-keyd        toggles that layer in the running daemon on Figma focus; diagnoses its own failures, since it is only ever reached through exec_raw
install-figma.sh              installs/updates the AppImage repack, and is the ONLY thing here that writes inside the app directory: it reapplies the Electron argv cap (electron/electron#52020) that keeps figma:// login working under FIGMA_USE_WAYLAND=1 -- see the follow-ups section
ryzen/ryzen-tdp.env           the power limits themselves: 52W sustained / 58W burst, with the measurements behind them (installed to /etc/default/ryzen-tdp with sudo)
ryzen/ryzen-tdp.service       reapplies them at boot AND on resume -- ryzenadj's settings survive neither (installed to /etc/systemd/system with sudo)
chromium/policies-managed.json  spellcheck/translate/password/autofill/Print/Cast/QR-code/Reading-list off, plus ExtensionInstallForcelist pinning uBlock Origin Lite + Proton Pass (managed policy, installed to /etc with sudo). DevTools deliberately absent — see the follow-ups section
omarchy/shell-bar.json        the recorded bar: widget layout, centerAnchor, disabledPlugins (jq-written into shell.json by step 7h)
icons/fallbacks/              app icons REPAINTED to the theme: <Icon=>.svg (or .png) placed by hand; see its README for the naming + silhouette contract
icons/color/                  app icons copied VERBATIM, for marks that only read in their own colours (vendor logos); same naming, no repaint
hooks/post-update.d/cllpse-macos-repair.sh  re-links our hooks/themes/plugin after an omarchy update, then re-syncs the icons
hooks/theme-set.d/app-icons.sh  syncs icons/fallbacks/ into ~/.icons/cllpse-flat/apps/ in the active theme's foreground, on every theme switch
```
