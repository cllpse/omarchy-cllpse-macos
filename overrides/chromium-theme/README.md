# chromium-theme

Chromium's frame and tabs coloured from the active Omarchy theme by a **theme
extension**. There is a light and a dark one, generated from the two themes'
`colors.toml`. A managed policy force-installs one of them, and it is
**swapped live on every `omarchy theme set`**. Installed by `apply.sh
chromium-theme` (sudo) and removed by `revert.sh`. Only our two themes have one:
any other Omarchy theme turns ours off and hands Chromium back to Omarchy's own
colour.

```
build.py                       renders a theme manifest from a colors.toml; the colour mapping lives here
chromium-theme.sh              the apply step: build, pack, install root-owned, link the hook (sudo)
cllpse-chromium-theme-policy   the root-owned policy writer: light | dark | off
../hooks/theme-set.d/chromium-theme.sh   runs on every theme set: writer, then a policy refresh
```

| What | Where | Owner |
|---|---|---|
| Signing keys (fix the extension ids), build output, version counters | `~/.local/state/cllpse-macos/chromium-theme/` | you, `0700`; keys `0600`, never committed |
| Packed themes, update manifests, ids | `/usr/local/share/cllpse-macos/chromium-theme/{light,dark}.{crx,xml,id}` | root |
| The writer | `/usr/local/bin/cllpse-chromium-theme-policy` | root |
| Its passwordless rule | `/etc/sudoers.d/cllpse-chromium-theme` | root, `0440` |
| The policy it writes | `/etc/chromium/policies/managed/zz-cllpse-macos-theme.json` | root |
| The hook | `~/.config/omarchy/hooks/theme-set.d/chromium-theme.sh` → repo | symlink (re-linked by the post-update repair hook) |

**Probe:** `jq -r .extensions.theme.id ~/.config/chromium/Default/Preferences`
should equal `/usr/local/share/cllpse-macos/chromium-theme/<mode>.id`. Chromium
writes `Preferences` a few seconds after a change, not at once.

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

| Surface | Keys (focused, unfocused) | `colors.toml` variable | Light | Dark |
|---|---|---|---|---|
| Frame / tab strip — the background | `frame`, `frame_inactive` | light `darker_background`, dark `dark_background` | `#E6E6E6` | `#1A1A1A` |
| Inactive tabs | `background_tab`, `background_tab_inactive` | light `darker_background`, dark `dark_background` | `#E6E6E6` | `#1A1A1A` |
| Active tab (and toolbar), either state | `toolbar` (one key for both) | `lighter_background` | `#FFFFFF` | `#282828` |
| All text and icons: tabs, tab-strip ⌄ and +, toolbar | `tab_text`, `tab_background_text`, `tab_background_text_inactive`, `toolbar_text`, `toolbar_button_icon` | `light_foreground` | `#000000` | `#FFFFFF` |

**The design** (2026-10-10; `build.py` holds the mapping). The background,
meaning the frame and the inactive tabs, is `darker_background` in light and
`dark_background` in dark. The active tab, and the toolbar under it, is
`lighter_background`. Every text and icon key is `light_foreground`, macOS
`textColor`. Nothing changes with window focus: every `_inactive` key equals its
focused twin. In light that is the `#E6E6E6` / white the design was iterated to
(history below), with black text at about 17:1. **The dark theme uses the same
variable names**, except for the background, one step lighter (see "Grey keys
differ" below). The active tab's `lighter_background` is `#FFFFFF` in light, the
same as `background`, so its bump moved dark alone.

**Unfocused translucency is Hyprland's, not the theme's.**
`../hypr/looknfeel-decoration.lua` re-matches the browser tags with
`opacity = "1.0 0.875"`, the same unfocused frost as the rest of the desktop.
It overrides the `1.0 0.985` that Omarchy's `default/hypr/apps/browser.lua`
sets. Checked live: `hyprctl getprop address:<test window> opacity_inactive` is
`0.875`. So an unfocused browser shows 12.5% of the blurred wallpaper through
every surface, whatever the theme says. With a light wallpaper that reads as a
lift toward white; where the wallpaper is coloured it reads as a tint, the
"right-end shading" in the log below. A theme cannot prevent it. Only that
Hyprland rule can.

**The active tab cannot follow focus.** Of the manifest keys
(`kOverwritableColorTable` in `browser_theme_pack.cc`), only `toolbar` sets the
active tab. `COLOR_TAB_BACKGROUND_ACTIVE_FRAME_INACTIVE` is not overwritable,
and the tab-strip mixer defaults it to the focused colour. 0.0.7 ran into this.
It asked for an active tab that changes with focus, the lightest grey
unfocused and a touch darker focused, so the tab had to be fixed at one
colour.

**Grey keys differ between the themes.** The dark theme files the same macOS
roles under other keys. There, `gridColor` is `dark_background` (`#1A1A1A`),
`underPageBackgroundColor` is `lighter_background` (`#282828`), and
`darker_background` is `#000000`, macOS `shadowColor`. Mapping by macOS role
would have given dark a `#1A1A1A` background beside a `#1E1E1E` active tab,
four levels apart. The decision (2026-10-10) was to map by **variable name**
instead: "map the color variable names for the dark theme 1-1 with what's used
in the light theme". That gave dark `#000000` behind a `#1E1E1E` tab (1.0.1).
Seen live, dark's background was then asked to be "a shade lighter (within
theme variables)". The next variable up is `dark_background` (`#1A1A1A`), so
dark is `#1A1A1A` behind `#1E1E1E` from 1.0.2. That is the four-level step the
role mapping would have given; this time it was chosen by eye. The active tab
then got "a shade-bump as well (still within theme variables)": from
`background` (`#1E1E1E`) to `lighter_background` (`#282828`, macOS
`underPageBackgroundColor`), 1.0.3. Dark is now `#1A1A1A` behind `#282828`.

**"White" was `background`.** `colors.toml` has no `white` key. Omarchy's
terminal templates use `white` for `foreground`, which in the light theme is
`#272727`. The white meant in the iterations was the light theme's
`background`, macOS `windowBackgroundColor`. From 1.0.3 the active tab reads
`lighter_background`, which is the same `#FFFFFF` in light ("white is the
lightest surface", says its comment) and `#282828` in dark.

**How it got here** (all 2026-10-10):
- **0.0.1:** CMYK test colours, one per key.
- **0.0.2:** the theme's `blue` (`#0088FF`) on the frame and inactive tabs,
  with a white active tab and no focus switching.
- **0.0.3:** in an unfocused window, the frame and inactive tabs switched to
  the unfocused-border grey, `hyprland_inactive_border` (`#BDBDBD`; `#565656`
  in the dark theme). That key equals `muted`, but the theme keeps the two
  unlinked. A generator would read the border key and drop its alpha.
- **0.0.4:** white text and icons on the blue, about 3.5:1 (WCAG asks 4.5:1
  for body text).
- **0.0.5:** the blue replaced by `dark_background` (`#F6F6F6`), with black
  text.
- **0.0.6:** one step darker, `darker_background` (`#E6E6E6`).
- **0.0.7:** inverted. A white background in every state, and the active tab
  fixed at `#E6E6E6`.
- **0.0.8:** back to 0.0.6's colours, after 0.0.7 was seen on screen.
- **0.0.9:** the background no longer changes when the window loses focus.
- **1.0.1:** generated by `build.py` from both themes, force-installed by
  policy and swapped on theme set (§7). The light build has the same colours as
  0.0.9; dark's background was `darker_background`, `#000000`.
- **1.0.2 (dark only):** dark's background one shade lighter, `dark_background`
  (`#1A1A1A`).
- **1.0.3 (dark only):** the active tab one shade lighter, `lighter_background`
  (`#282828`). Light's `lighter_background` is `#FFFFFF`, so light did not
  change and was not repacked.

**Separators have no key and cannot be made transparent.** Checked in Chromium
152.0.7977.82's source:
- **Tab dividers** (between two inactive tabs, and before the new-tab button)
  paint `kColorTabDividerFrameActive` / `…FrameInactive`. `tab_strip_color_mixer.cc`
  sets both to `kColorToolbar`, the theme's `toolbar`: the active tab's colour.
- **The divider between the extensions button and the avatar** is a
  `ToolbarDivider` painting `kColorToolbarExtensionSeparatorEnabled`. With a
  custom theme, `chrome_color_mixer.cc` sets that to
  `kColorTabBackgroundInactiveFrameActive`, the theme's `background_tab`. It
  ignores focus, so an unfocused window keeps the focused colour there (blue
  before 0.0.5). The
  toolbar shows it whenever the extensions container is visible
  (`toolbar_view.cc`).
- **Alpha cannot hide either one.** Theme colours do accept a fourth alpha
  value. But `BrowserThemePack::GetColor` forces `frame`, `frame_inactive`,
  `background_tab`, `background_tab_inactive` and `toolbar` opaque.
- So a divider disappears only if its source colour matches what it sits on.
  For tab dividers, the active tab would need the inactive tabs' colour. For
  the extensions divider, the inactive tabs would need the toolbar's colour.
  A light grey beside white comes close on both counts. With 0.0.8's
  `#E6E6E6`, the tab dividers are white on grey tabs and the extensions divider
  is grey on the white toolbar, both about 1.25:1. With `#F6F6F6` it would be
  about 1.1:1. The one switch that hides tab dividers is the
  tab-strip declutter feature (`TabStripDeclutter`, or `DesktopGlowUp`), and
  it hides them only at 20 tabs or more
  (`kTabStripDeclutterMinTabsForSeparatorHide`).
- **The tab-strip icons** (tab search ⌄, new tab +) follow the Chrome Refresh
  (`CR`) mixers. They paint `kColorTabForegroundInactiveFrameActive`
  (`tab_background_text`) in a focused window, and `kColorToolbarButtonIconInactive`
  (a disabled grey over `toolbar`) in an unfocused one. Their circles are
  `background_tab` / `background_tab_inactive`.

**Menu separators and the omnibox selection come from the Material palette,
which no theme key reaches.** Traced in 152.0.7977.82's source:
- **Context-menu separators:** `kColorMenuSeparator` → `kColorSeparator` →
  `kColorSysDivider` (`ui_color_mixer.cc`, `material_ui_color_mixer.cc`).
- **Omnibox text selection:** with a custom theme,
  `kColorOmniboxSelectionBackground` → `kColorTextfieldSelectionBackground` →
  `kColorTextSelectionBackground` → `kColorSysTonalContainer`
  (`omnibox_color_mixer.cc`, `material_ui_color_mixer.cc`).
- In light mode **both resolve to `kColorRefPrimary90`** (`sys_color_mixer.cc`).
- **What seeds that palette** is decided by `ThemeService::GetColorProviderKey`
  from profile prefs, and the extension theme has no say:
  - Incognito, or grayscale (`browser.theme.is_grayscale2`), gives the
    grayscale source.
  - Otherwise, no user colour (`browser.theme.user_color2`) gives Google's
    baseline. Its `kColorRefPrimary90` is `#D3E3FD`, the light blue seen here.
  - A user colour seeds a generated palette. Its primary is a tint of that seed
    (Tonal Spot gives chroma 40). Chromium's own comment in `ref_color_mixer.cc`
    notes that grey seeds come out as the default blue.
- **Grayscale fixes the separators but not the selection.**
  `AddGrayscaleSysColorOverrides` moves `kColorSysDivider` to
  `kColorRefNeutral90`, which is `#E3E3E3` in light mode. It leaves
  `kColorSysTonalContainer` alone, and the reference palette under grayscale is
  still the baseline, so the selection stays `#D3E3FD`.
- **Grayscale and a user colour exclude each other.** Grayscale is checked
  first. So the choice is either grey separators with a baseline-blue
  selection, or both tinted from one seed. Neither path gives a grey selection.
- **A profile colour does not set a colour, it sets a seed.** The separators
  and the selection become tone 90 of the seed's generated primary palette, and
  Chromium never lets that palette go grey. Its least colourful variant,
  Neutral (`browser.theme.color_variant2` = 2), still keeps a chroma of 12, or
  20 for hues 260–315 (`palette_factory.cc`). Computed with Material's colour
  library for Chromium's configs:

  | Seed (`browser.theme.user_color2`) | Variant | Separators and selection |
  |---|---|---|
  | none | baseline | `#D3E3FD` |
  | `#E6E6E6` (`darker_background`) | Neutral | `#D4E6E9` |
  | `#007AFF` (`accent`) | Tonal Spot or Neutral | `#D8E2FF` |
  | `#B3D7FF` (`selection`) | Neutral | `#DAE3F1` |

- **And a profile colour does not coexist with an extension theme.** Applying
  an extension theme runs `SetThemePrefsForExtension`, which calls
  `ClearThemePrefs`. That deletes `user_color2`, `is_grayscale2` and
  `color_variant2` ("Extensions are incompatible with device themes").
  Chromium applies a theme on every install or update, whenever its cache file
  (`Cached Theme.pak`) is missing (`MigrateTheme`), and whenever the profile's
  theme id has been cleared. Run on the test profile, 2026-10-10:
  - With `is_grayscale2` written behind Chromium's back, the theme rendered at
    startup but the profile's theme id was empty after exit. The grayscale
    pref was gone by the next look, so the grayscale separators were most
    likely never in effect. An earlier note here said the pref "kept the
    theme"; that was read from `Preferences` before Chromium had written it,
    and is withdrawn.
  - With `user_color2` = `#E6E6E6` and Neutral written instead, and the theme
    id empty, the window came up in Chromium's own seeded palette (frame
    `[219,228,230]`), not this theme.
  - With both removed, the next launch re-applied the theme ("Installed theme"
    infobar) and the colours were back.
  - Grayscale retried properly. The theme id was intact, `Cached Theme.pak`
    was kept, and `is_grayscale2` was written with Chromium closed. Within
    seconds of launch Chromium rewrote `Preferences` without it, and the theme
    id was kept. **An extension loaded with `--load-extension` is installed
    afresh on every launch**, and installing a theme clears the pref. So with
    this test setup grayscale cannot stick at all.
- **Where grayscale could stick:** with a theme installed by policy (§4). An
  already-installed CRX loads at startup without being installed again, so
  `OnExtensionLoaded` returns early and nothing clears the pref. It would
  still be cleared on every theme swap, which is an update. It would then have
  to be rewritten with Chromium closed, so it cannot follow a live theme
  switch. Untested; this is §6 step 3. Chromium has no managed policy for
  grayscale or a user colour: `BrowserThemeColor` is the only theme-colour
  policy name in the binary.
- **"Grey default color" in Chromium's settings *is* grayscale, without the
  theme.** Its handler (`ThemeColorPickerHandler::SetGreyDefaultColor`) calls
  `SetIsGrayscale(true)`, which runs `ClearThemeData` first. Chosen in the test
  window on 2026-10-10, it removed this extension theme: the profile's theme id
  became empty, with `is_grayscale2` true. Chromium's own grey theme then
  measured as follows (same window, same spot, both under Hyprland's 0.875
  unfocused opacity):

  | | Focused | Unfocused |
  |---|---|---|
  | Grey default: frame and inactive tabs | `[227,227,227]` (`#E3E3E3`) | `[244,242,241]` |
  | Grey default: active tab and toolbar | `[255,255,255]` | — |
  | This theme 0.0.9: frame | `[230,230,230]` | `[231,230,230]` |

  So Grey default nearly matches this design focused, and gives grey menu
  separators besides. It lightens the background when unfocused, though: the
  grayscale `kColorSysHeaderInactive` is a blend toward `kColorRefNeutral98`.
  Without an extension theme, no key can stop that. Nothing clears the pref
  either, because only applying an extension theme does, and
  `../chromium/neutral-theme.py` already writes it.
- So these two colours cannot be redefined alongside a theme extension in any
  way that lasts. A profile pref only survives until the theme is next applied,
  and this design applies a new theme on every Omarchy theme switch (§3).
  `../chromium/neutral-theme.py` writes `is_grayscale2` for the policy-themed
  setup, where no extension theme clears it. It is still run by `apply.sh
  chromium-user`, and has not been retired for this setup. With the theme
  installed by policy it should now stick until the next swap, but that is
  untested. `system_theme` was seen flipped to `0` by Chromium the moment the
  forced theme applied.

**Measured with the first scaffold** (0.0.1, CMYK test colours, one per key):
- A focused window paints `frame` and `toolbar` exactly.
- The tab strip's own buttons (tab search, new tab) take `background_tab` and
  `background_tab_inactive`.
- In an **unfocused** window something lifts every surface about 11% toward
  white, on top of the keys. `frame_inactive` `[128,255,255]` read
  `[142,252,252]`, and the active tab's `[255,0,255]` read `[253,29,252]`.
  At the time I put this down to Chromium, assuming browsers were at Omarchy's
  unfocused opacity of 0.985. **That was wrong** (corrected with 0.0.9): this
  repo sets browsers to 0.875, and the lift is the blurred wallpaper showing
  through. See "Unfocused translucency" above.

**Measured with 0.0.2** (two tabs, no focus switching, 2026-10-10). Focused: frame
and inactive tab `[0,136,255]`, active tab and toolbar `[255,255,255]`, all
exact. Unfocused: frame and inactive tab `[30,148,252]`, active tab
`[253,252,252]`. That fits about 12% of a light grey (~250) over the keys,
plus Hyprland's 0.985. So the wash survives identical `_inactive` keys: an
unfocused window's blue reads a shade lighter, and no theme key removes it.
(Corrected with 0.0.9: the "light grey" is the blurred wallpaper through
Hyprland's 0.875, not a 0.985 opacity plus a Chromium wash.)
The inactive tab is the frame colour, so it shows only as a separator.

**Measured with 0.0.3** (unfocused grey, 2026-10-10). Unfocused: frame and
inactive tab `[195,195,195]`, active tab `[253,252,252]`. That is `#BDBDBD`
plus the same lift, which is barely visible on a grey. The focused keys are
0.0.2's, so the focused window was not re-measured.

**Seen with 0.0.4** (white on the blue, three tabs, focused). The inactive
tabs' titles and ×, and the tab-search ⌄ and new-tab +, are white, so the
`CR` mapping above holds. The default globe favicon (a tab with no favicon,
such as `about:blank`) stays dark grey: `tab_background_text` does not
colour it. Real sites show their own favicons there.

**Seen with 0.0.5** (unfocused only; focus had moved on before the capture).
The frame and inactive tabs read `[195,194,194]`, the same as 0.0.3, as
expected: the unfocused keys did not change. The strip's right-most ~100 px
shaded toward `[172,184,194]`. That shading comes from outside the theme: the
strip is flat up to that point. (Traced with 0.0.9: it is the wallpaper behind
the window, blurred, showing through Hyprland's 0.875 unfocused opacity.)

**Seen with 0.0.6** (focused, then unfocused). Focused: frame `[230,230,230]`
and active tab `[255,255,255]`, exact. The dividers before the new-tab button
and beside the extensions button read about `[244,244,244]` and `[236,236,236]`:
visible, but faint. Unfocused: the border grey, as with 0.0.3. The right-end
shading appeared again. Hyprland's window shadows are off
(`decoration:shadow:enabled` false), so it is not a Hyprland shadow.

**Seen with 0.0.7** (focused, then unfocused). The frame and inactive tabs are
`[255,255,255]` and the active tab and toolbar `[230,230,230]` in both states,
exact. The lift seen on earlier unfocused windows does not show. (Probably
because the capture came 0.5 s after focus left, before Hyprland had finished
fading the window. Captures now wait 3 s.) The address field is white `[255,255,255]` while it has keyboard
focus. Without it, it turns darker than the toolbar, `[202,202,203]`. That
colour is Chromium's derived default, and the theme's `omnibox_background`
key (overwritable, unset here) would set it.

**Seen with 0.0.8** (= 0.0.6's colours). Focused: frame `[230,230,230]`, and
active tab and toolbar `[255,255,255]`, exact. Unfocused: the frame reads
`[193,194,195]` and the active tab white. The right-end shading is back. It
has appeared each time the unfocused frame was grey (0.0.5, 0.0.6, 0.0.8),
and not with 0.0.7's white frame.

**Seen with 0.0.9.** Focused: frame `[230,230,230]`, and active tab and toolbar
`[255,255,255]`, exact. Unfocused, 0.5 s after focus left: frame
`[230,230,230]` across the strip, which was mid-fade. Recaptured once fully
faded: `[231,230,230]` at the left, but `[210,223,230]` and `[219,218,210]`
toward the right, where the wallpaper behind is coloured. So the theme
holds and Hyprland's translucency tints it.

## 3. Following theme changes — the subscription problem

A theme extension is static, so following `omarchy theme set` means
regenerating it (colours from the theme's `colors.toml`, rendered by a
`theme-set.d` hook like the repo's others) and getting Chromium to load the new
one. Options, best first:

1. **Swap by policy, live** — the Omarchy-shaped answer, and **the one built**
   (§7). Per theme, a separately packed CRX; the theme-set hook rewrites which
   one the policy force-installs and runs `--refresh-platform-policy`. A policy
   change installs and removes force-installed extensions immediately, so this
   is the one route that can be live. Writing `/etc` on every switch needs root.
   That is solved the way Omarchy solves it for `color.json`: a passwordless
   sudo rule for one root-owned writer, and only for the exact words it takes.
2. **Update in place** — one extension ID, the hook bumps `version` and repacks.
   Chromium only checks for updates periodically (hours) and at startup, and
   Chromium 152 no longer has the `--extensions-update-frequency` switch that
   could have shortened that (checked: absent from the binary). So: lands at the
   next restart, not live.
3. **Unpacked via `--load-extension`** — how Omarchy loads its three extensions.
   No packing, but it is a flag rather than a policy, and an unpacked theme is
   only re-read on a manual reload or a restart.
   Loading it also makes Chromium write `Cached Theme.pak` into the extension's
   own folder, stale once the colours change. It is also reinstalled on every
   launch, which wipes the palette prefs (§2). This was the test setup only.

## 4. Loading it through this repo's policy

The writer puts an `ExtensionSettings` entry in
`zz-cllpse-macos-theme.json`, with `installation_mode: force_installed` and an
`update_url` pointing at a local update manifest (`<mode>.xml`, naming the CRX
and its version). It is a **separate** policy file from
`../chromium/policies-managed.json` (`cllpse-macos.json`) for two reasons:
- The extension ids are per machine. Each comes from the key its CRX is signed
  with, generated once into `$STATE` and never committed.
- That file sets `ExtensionInstallForcelist`. The same key in two files is not
  merged (one replaces the other), so ours uses `ExtensionSettings`.

Both questions this section left open were answered on 2026-10-10 (§6 step 3):
- Chromium 152 accepts a `file://` `update_url` for a force-installed
  extension. The source agrees: `ExtensionDownloader::GetURLLoaderFactoryToUse`
  builds a file URL loader.
- A force-installed **theme** is applied automatically: installing it sets it.

## 5. Disabling Omarchy's colour through the policy overrides

`color.json` cannot simply be deleted: Omarchy rewrites it, as root, on every
theme switch. And while `BrowserThemeColor` is set, Chromium treats the theme as
managed, so an extension theme would not take effect.

The policy route is **masking**. Chromium merges every file in the managed
directory, and when two files set the same key **the file that sorts last
lexicographically wins**. So our policy file must be named to sort
after `color.json` (for example `zz-cllpse-macos-theme.json`; the existing
`cllpse-macos.json` sorts *before* it). It sets `BrowserThemeColor` to `""`. That
value takes precedence at the merge and is then rejected as an invalid colour,
which should leave no policy theme at all. `chrome://policy` will show it as an
error, which is expected.

Verified in effect (§6 step 2): with `zz-cllpse-theme-test.json` beside
`color.json`, a theme extension installs. The writer now carries the mask in
`zz-cllpse-macos-theme.json`, and `chromium-theme.sh` deleted the hand-made
test file when it installed. `off` deletes ours, which is how any other Omarchy
theme gets its own colour back. The precedence rule comes from my reading of
Chromium's policy loader; `chrome://policy` has not been read to confirm it.
Once the seed is masked, `../chromium/neutral-theme.py`'s two preferences are
no longer what keeps the UI neutral (see the end of §2).

## 6. Verification, in order

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
3. **Policy load.** Pack a CRX with a fresh key, write `update.xml`, and
   install the policy (sudo). Does the theme install and apply from a `file://`
   update URL?
   **Run 2026-10-10 through `apply.sh chromium-theme`: yes, live.** The running
   main Chromium installed `klehdjbaeipmaiaejecohhogfjmjkfgf` 1.0.1 into
   `Default/Extensions/` and set it as the profile's theme within seconds of the
   refresh. Sampled from a sliver of the tab strip, while unfocused: frame
   `[232,231,229]` (`#E6E6E6` under the 0.875 translucency), toolbar
   `[254,253,251]`. The ids in both CRX headers match the ones derived from the
   keys.
4. **Swap.** Two CRXs, change which one is forced, refresh: does the theme change
   live?
   **Run 2026-10-10: yes, both ways, no relaunch.**
   - `omarchy theme set omarchy-cllpse-theme-dark`: the policy named the dark
     id. The profile switched to it in about 10 s, and the light theme's folder
     was gone. Frame `#000000`; toolbar `#1A1A1A` (`#1E1E1E`, unfocused).
   - Back to light: about 3 s, frame exactly `#E6E6E6`.
   - Forcing `off` then `light` uninstalled the theme and installed it afresh
     (new folder). That is the path §7.4 uses to land a repacked version live.
   - Not looked for: whether the default theme flashes between the uninstall
     and the install.

## 7. What `apply.sh chromium-theme` does

Idempotent. Without Chromium, without a managed-policy directory, or without
`openssl` / `python3`, it says so and does nothing.

### 7.1 Build and pack each mode

- **Keys and ids.** One RSA key per mode, generated once into `$STATE` (`0600`).
  The extension id is the first 128 bits of the SHA-256 of the public key, as
  hex mapped `0–f` to `a–p`, and is computed with `openssl`. Deleting a key
  changes that mode's id, and the next run force-installs a different extension.
- **Manifest.** `build.py <colors.toml> <mode> <version>` renders it from the
  repo's own theme folders, not from `~/.config/omarchy/themes`.
- **Version.** `1.0.<n>`, where `<n>` is bumped only when the rendered colours
  change. The test is a hash of a render made with a fixed version. A run with
  nothing changed repacks nothing.
- **Packing.** The real binary (`/usr/lib/chromium/chromium`, not the
  `chromium-flags.conf` wrapper) is run with `--pack-extension` and a throwaway
  `--user-data-dir`. It opens no window and does not hand off to a running
  browser (checked: no new client, focus unchanged).
- **Update manifest.** `<mode>.xml` points at
  `file:///usr/local/share/cllpse-macos/chromium-theme/<mode>.crx`.

### 7.2 The passwordless rule

`/etc/sudoers.d/cllpse-chromium-theme`, for the user who ran apply.sh:

```
<user> ALL=(root) NOPASSWD: /usr/local/bin/cllpse-chromium-theme-policy light, …dark, …off
```

It names three exact invocations, the way Omarchy's own rules do
(`omarchy-dns Cloudflare, …`). The writer takes a word, never a path or an id.
It reads the id and the update manifest from root-owned files, and pins `PATH`
as Omarchy's `omarchy-theme-set-browser-policy` does. The rule is checked with
`visudo -c` before it is installed. Since `/etc/sudoers.d` cannot be read from
user space, "already installed" is decided by `sudo -n -l -l <writer> <word>`
listing `!authenticate`, for all three words. That is Omarchy's own probe.

### 7.3 Install root-owned

Only what differs is reinstalled; a run with nothing to do needs no password.
The CRXs, update manifests and ids are root-owned on purpose: a managed policy
that force-installs from a file your user account can write would let any
user-level program choose what Chromium force-installs, silently and with any
permission. The keys stay in `$STATE`, because the policy names a root-owned
CRX; a key alone cannot get anything installed.

### 7.4 The hook, and landing a repack

The hook is linked into `~/.config/omarchy/hooks/theme-set.d/` (and re-linked
by `../hooks/post-update.d/cllpse-macos-repair.sh`), then run once for the
current theme. Omarchy calls it after `omarchy-theme-set-browser` has written
`color.json` and refreshed, so ours lands last. The theme name decides the mode:
`omarchy-cllpse-theme-light` gives light, `-dark` gives dark, anything else
gives `off`. It runs the writer through `sudo -n`, so it never prompts and does
nothing without the rule. Then it refreshes a running Chromium.

A **repack** (changed colours) would otherwise wait for Chromium's next update
check: the policy names the same id, so a refresh alone changes nothing. When
something was repacked and Chromium is running, the step first forces `off`,
refreshes, and waits 3 s. That uninstalls the theme, and the hook then installs
it afresh from the new update manifest. Checked with the off→on cycle in §6
step 4. Not yet checked with a real repack.

**Revert** (`revert.sh`) removes the policy file first, so the themes stop being
forced, then the writer, the rule, the CRX folder and the hook, and refreshes
Chromium. The keys in `$STATE` are left, so a later apply reuses the same ids.
