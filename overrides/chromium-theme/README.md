# chromium-theme — scaffold

A Chromium **theme extension** that will colour the browser from the active
Omarchy theme: one general colour for the frame, and a colour for the active
and inactive tabs. In an unfocused window the frame and inactive tabs turn the
grey of an unfocused window border; the active tab stays put (§2). Right now it
is a scaffold: the colours are the light theme's, copied in by hand, not
generated. **Nothing here is wired into `apply.sh` or `revert.sh`, and nothing
is installed.**

```
extension/manifest.json   the theme (MV3), the light theme's blue, white and inactive-border grey
policy.json.tpl           the managed-policy file that would load it and mask Omarchy's colour
```

## 1. What Omarchy does — there is no Omarchy extension

Omarchy themes Chromium with a **managed policy**, not an extension. The three
extensions it ships (`copy-url`, `yt-dlp`, `whatsapp-slim`, loaded with
`--load-extension` from `~/.config/chromium-flags.conf`) have nothing to do
with colour. The theming chain, read from Omarchy 4.0.4:

1. `omarchy theme set` calls `omarchy-theme-set-browser` unconditionally
   (`omarchy-theme-set:331`; there is no setting to skip it).
2. That reads the theme's `chromium.theme` (one hex colour) and runs
   `omarchy-theme-set-browser-policy`, which as root (sudo or pkexec) writes
   `/etc/chromium/policies/managed/color.json`:
   `{"BrowserThemeColor": "#ececec", "BrowserColorScheme": "device"}`
   (and the same file for Chrome, Edge and Brave).
3. It "subscribes" the running browser by pushing: `chromium
   --refresh-platform-policy --no-startup-window` makes a running Chromium
   re-read every managed policy file, live, with no relaunch.

`BrowserThemeColor` is a single **seed**. Chromium runs it through Material's
palette generator and derives every surface from it, so tab colours cannot be
set through it at all — and with a grey seed it comes out faintly cyan, which is
what `../chromium/neutral-theme.py` works around.

## 2. Why a theme extension, and what it can set

Chromium has **no runtime theme API** for extensions (`browser.theme` is
Firefox's). The only way an extension colours Chromium's UI is a *theme*
extension: a manifest whose `theme.colors` are read once, when the theme is
applied. Every key below was checked to exist in Chromium 152's binary.

| Surface | Keys (focused, unfocused) | Colour now | From `colors.toml` |
|---|---|---|---|
| Frame / tab strip, focused — the general colour | `frame` | `#0088FF` | `blue` |
| Frame / tab strip, unfocused | `frame_inactive` | `#BDBDBD` | `hyprland_inactive_border` (= `muted`) |
| Active tab (and toolbar), either state | `toolbar` (one key for both) | `#FFFFFF` | `background` (light) |
| Inactive tabs, focused | `background_tab` | `#0088FF` | `blue` |
| Inactive tabs, unfocused | `background_tab_inactive` | `#BDBDBD` | `hyprland_inactive_border` (= `muted`) |
| Active tab text | `tab_text` | `#000000` | not chosen yet |
| Inactive tab text | `tab_background_text`, `tab_background_text_inactive` | `#000000` | not chosen yet |
| Toolbar text and icons | `toolbar_text`, `toolbar_button_icon` | `#000000` | not chosen yet |

**Focus follows the window border** (decided 2026-10-10). An unfocused window
swaps the blue for the colour Hyprland draws an unfocused window's border in.
The active border is the accent gradient, not the blue, so the focused side
does not mirror the border. Text keeps one colour in both states. The active
tab cannot follow focus at all: Chromium paints it with `toolbar` in both
states and offers no `toolbar_inactive`. Before this, briefly (0.0.2), the
decision was no focus switching at all, with every `_inactive` key equal to its
focused twin. That version measured below.

`hyprland_inactive_border` is `rgba(bdbdbdff)` in the light theme and
`rgba(565656ff)` in the dark theme. It is `muted` at full opacity, but the theme
keeps the two unlinked (see `colors.toml`), so a generator should read
`hyprland_inactive_border` and drop its alpha. Black text on `#BDBDBD` is
about 11:1.

**"White" is `background`.** `colors.toml` has no `white` key. Omarchy's
terminal templates use `white` for `foreground`, which in the light theme is
`#272727`. The white meant here is the light theme's `background`, macOS
`windowBackgroundColor`. In the dark theme that key is `#1E1E1E`, which would
make the active tab dark. When the generator exists it has to decide whether
that is right or whether white should be a literal. `blue` is `#0088FF` in both
themes (`accent` is `#007AFF`). Black text on that blue is about 6:1 contrast;
white text would be about 3.5:1.

**Measured with the first scaffold** (0.0.1, CMYK test colours, one per key):
- A focused window paints `frame` and `toolbar` exactly.
- The tab strip's own buttons (tab search, new tab) take `background_tab` and
  `background_tab_inactive`.
- In an **unfocused** window something lifts every surface about 11% toward
  white, on top of the keys. `frame_inactive` `[128,255,255]` read
  `[142,252,252]`, and the active tab's `[255,0,255]` read `[253,29,252]`.
  Hyprland's unfocused browser opacity (0.985, `default/hypr/apps/browser.lua`)
  accounts for 2–3 levels at most, so the wash is most likely Chromium's own.
  If it is, matching keys will not keep an unfocused window identical: its
  blue lifts slightly, while white cannot get lighter.

**Measured with 0.0.2** (two tabs, no focus switching, 2026-10-10). Focused: frame
and inactive tab `[0,136,255]`, active tab and toolbar `[255,255,255]`, all
exact. Unfocused: frame and inactive tab `[30,148,252]`, active tab
`[253,252,252]`. That fits about 12% of a light grey (~250) over the keys,
plus Hyprland's 0.985. So the wash survives identical `_inactive` keys: an
unfocused window's blue reads a shade lighter, and no theme key removes it.
The inactive tab is the frame colour, so it shows only as a separator.

**Measured with 0.0.3** (unfocused grey, 2026-10-10). Unfocused: frame and
inactive tab `[195,195,195]`, active tab `[253,252,252]`. That is `#BDBDBD`
plus the same lift, which is barely visible on a grey. The focused keys are
0.0.2's, so the focused window was not re-measured.

## 3. Following theme changes — the subscription problem

A theme extension is static, so following `omarchy theme set` means
regenerating it (colours from the theme's `colors.toml`, rendered by a
`theme-set.d` hook like the repo's others) and getting Chromium to load the new
one. Options, best first:

1. **Swap by policy, live** — the Omarchy-shaped answer. Per theme, a separately
   packed CRX; the theme-set hook rewrites which one the policy force-installs
   and runs `--refresh-platform-policy`. A policy change installs and removes
   force-installed extensions immediately, so this is the one route that can be
   live. Cost: writing `/etc` on every theme switch needs root, as Omarchy's own
   writer does (sudo or pkexec).
2. **Update in place** — one extension ID, the hook bumps `version` and repacks.
   Chromium only checks for updates periodically (hours) and at startup, and
   Chromium 152 no longer has the `--extensions-update-frequency` switch that
   could have shortened that (checked: absent from the binary). So: lands at the
   next restart, not live.
3. **Unpacked via `--load-extension`** — how Omarchy loads its three extensions.
   No packing, but it is a flag rather than a policy, and an unpacked theme is
   only re-read on a manual reload or a restart.
   Loading it also makes Chromium write `Cached Theme.pak` into the extension's
   own folder. That file is gitignored, and it is stale once the colours change.

## 4. Loading it through this repo's policy

`policy.json.tpl` is the shape: an `ExtensionSettings` entry with
`installation_mode: force_installed` and an `update_url` pointing at a local
update manifest (`update.xml`, naming the CRX and its version). This would be a
**second** policy file next to `../chromium/policies-managed.json` rather than a
key in it, because it is per machine: the extension ID is derived from the key
the CRX is signed with. That private key should be generated once per machine
into `$STATE` and never committed. Packing needs `chromium --pack-extension`
with a throwaway `--user-data-dir`, so it cannot hand off to a running browser.

Unverified (§6): whether Chromium 152 accepts a `file://` `update_url` for a
force-installed extension, and whether a force-installed *theme* is applied
automatically.

## 5. Disabling Omarchy's colour through the policy overrides

`color.json` cannot simply be deleted: Omarchy rewrites it, as root, on every
theme switch. And while `BrowserThemeColor` is set, Chromium treats the theme as
managed, so an extension theme would not take effect.

The policy route is **masking**. Chromium merges every file in the managed
directory, and when two files set the same key **the file that sorts last
lexicographically wins**. So the scaffold's policy file must be named to sort
after `color.json` (for example `zz-cllpse-macos-theme.json`; the existing
`cllpse-macos.json` sorts *before* it). It sets `BrowserThemeColor` to `""`. That
value takes precedence at the merge and is then rejected as an invalid colour,
which should leave no policy theme at all. `chrome://policy` will show it as an
error, which is expected.

Verified in effect (§6 step 2): with `zz-cllpse-theme-test.json` beside
`color.json`, a theme extension installs. The precedence rule itself comes from
my reading of Chromium's policy loader; `chrome://policy` has not been read to
confirm it. Also note that once the seed is masked,
`../chromium/neutral-theme.py`'s two preferences (the GTK system theme, plus
grayscale) stop being needed, and the system-theme one actively competes with an
extension theme. That step would have to stand down.

## 6. Verification plan, in order

1. **Theme alone, no policy.** Launch Chromium with a throwaway
   `--user-data-dir` and `--load-extension=<this>/extension`. Confirm each
   surface in the §2 table (then CMYK test colours), the active tab in an unfocused window, and whether
   the theme applies at all while `color.json` is in force. Takes focus (a
   window opens).
   **Run 2026-10-10, under the live policy: refused.** Chromium's log
   (`--enable-logging=stderr`): `Failed to load extension from: …/extension.
   cllpse-macos theme (scaffold) (extension ID "dhimobpmbjncgndljeoncdpkcdhlmpld")
   is blocked by the administrator.` Nothing in `cllpse-macos.json` restricts
   extensions, and Omarchy's own command-line extensions (not themes) load in the
   main profile, so the block is almost certainly `BrowserThemeColor` refusing
   *any* theme. That makes step 2 a precondition, not an option. The second
   `--load-extension` replaces the flags file's one (last value wins), so the
   test instance had none of Omarchy's three.
   **Re-run 2026-10-10 with step 2's mask in place: applied.** No block in the
   log. Chromium showed "Installed theme "cllpse-macos theme (scaffold)"" with
   Undo, and the surfaces measured as recorded in §2. Not yet seen: an inactive
   tab beside an active one (a test window had only one tab) and its text
   colours.
2. **Masking.** Install a `zz-…json` with only `"BrowserThemeColor": ""`
   (needs sudo), refresh policy, and read `chrome://policy`: is `color.json`'s
   seed gone?
   **Run 2026-10-10: works.** Installed as
   `/etc/chromium/policies/managed/zz-cllpse-theme-test.json` with `pkexec
   install` (`sudo` cannot prompt without a terminal). A fresh test instance then
   accepted the theme (step 1's re-run), so the empty value displaced
   `color.json`'s seed. `chrome://policy` was not read: a `chrome://` URL handed
   to a running instance on the command line opens a blank new window instead.
3. **Policy load.** Pack a CRX with a fresh key, write `update.xml`, and install
   the rendered `policy.json.tpl` (sudo). Does the theme install and apply from a
   `file://` update URL?
4. **Swap.** Two CRXs, change which one is forced, refresh: does the theme change
   live?
