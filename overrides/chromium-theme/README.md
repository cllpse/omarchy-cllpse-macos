# chromium-theme — scaffold

A Chromium **theme extension** that will colour the browser from the active
Omarchy theme: one general colour for the frame, and separate colours for tabs
by state (active / inactive, window focused / unfocused). Right now it is a
scaffold: the colours are CMYK test values, one per key, so you can see which
key paints which surface. **Nothing here is wired into `apply.sh` or
`revert.sh`, and nothing is installed.**

```
extension/manifest.json   the theme (MV3), CMYK test colours
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

| State | Key | CMYK test colour |
|---|---|---|
| Frame / tab strip, window focused — the general colour | `frame` | C100 `[0,255,255]` |
| Frame / tab strip, window unfocused | `frame_inactive` | C50 `[128,255,255]` |
| Active tab (and toolbar), either focus state | `toolbar` | M100 `[255,0,255]` |
| Active tab text | `tab_text` | K100 `[0,0,0]` |
| Inactive tab, window focused | `background_tab` | Y100 `[255,255,0]` |
| Inactive tab, window unfocused | `background_tab_inactive` | Y50 `[255,255,128]` |
| Inactive tab text, window focused | `tab_background_text` | K100 `[0,0,0]` |
| Inactive tab text, window unfocused | `tab_background_text_inactive` | K50 `[128,128,128]` |
| Toolbar text and icons | `toolbar_text`, `toolbar_button_icon` | K100 `[0,0,0]` |

Focused surfaces are the 100% process colour; their unfocused counterparts are
the 50% tint of the same ink. Converted naively, R = 255(1−C)(1−K), and the same
for G with M and B with Y.

**One state has no key:** the active tab in an *unfocused* window. The active
tab is painted with `toolbar` in both focus states; Chromium offers no
`toolbar_inactive`. To be confirmed on screen (§6), but expect M100 there too.

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

Unverified (§6), and the precedence rule is from Chromium's policy loader as I
understand it, not measured here. Also note that once the seed is masked,
`../chromium/neutral-theme.py`'s two preferences (the GTK system theme, plus
grayscale) stop being needed, and the system-theme one actively competes with an
extension theme. That step would have to stand down.

## 6. Verification plan, in order

1. **Theme alone, no policy.** Launch Chromium with a throwaway
   `--user-data-dir` and `--load-extension=<this>/extension`. Confirm each CMYK
   surface in the §2 table, the active tab in an unfocused window, and whether
   the theme applies at all while `color.json` is in force. Takes focus (a
   window opens).
2. **Masking.** Install a `zz-…json` with only `"BrowserThemeColor": ""`
   (needs sudo), refresh policy, and read `chrome://policy`: is `color.json`'s
   seed gone?
3. **Policy load.** Pack a CRX with a fresh key, write `update.xml`, and install
   the rendered `policy.json.tpl` (sudo). Does the theme install and apply from a
   `file://` update URL?
4. **Swap.** Two CRXs, change which one is forced, refresh: does the theme change
   live?
