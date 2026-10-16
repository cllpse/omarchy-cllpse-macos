# Chromium

Two halves that run at opposite ends of an apply run: user-level flags, a neutral UI and the profile avatar early; the managed policy last, because it is the only part needing sudo.

## 1. Two halves

Two halves, and they run at DIFFERENT points of an apply.sh run: the
user-level flags/UI half early (it was step 7d), the managed policy last
because it is the only part needing sudo and a password prompt should not
stall a run halfway through (it was step 9). Calling this with no argument
-- which is what running it by hand does -- does both, in that order.

## 2. Drawing at 2×, and the fractional UI scale before it

Since 2026-10-12 Chromium draws at 2× and Hyprland scales the window down by
1.6 at the monitor's 1.25 (1.5 at the 4/3 it was decided at), as macOS does at
its in-between "looks like" resolutions. Two flags, both needed:

- `WaylandFractionalScaleV1` in `--disable-features` turns off Wayland's
  fractional-scale protocol, so Hyprland asks for a whole-number buffer scale,
  2 at the monitor's 1.25, as at 4/3.
- `--force-device-scale-factor=2` then sets Chromium's whole rendering scale.
  In this mode it does not touch layout: one DIP, and at 100% zoom one CSS
  pixel, is one desktop pixel, drawn as 2×2 device pixels.

Pages report `devicePixelRatio` 2, so media queries, `srcset` and
`image-set()` all choose sharp images. At 1.33 they chose 1×, being under
Google's 1.5× threshold, and Gmail's icons were stretched by a third.
Neither flag works alone: fractional off with the old 0.95 drew at 0.95× and
was upscaled, blurrier than before; with fractional on, the scale flag only
replaces the UI scale, as described below.

| Measured on a throwaway Chromium at this browser's size | Before (0.95, fractional) | 2× |
|---|---|---|
| Chromium's GPU busy, scrolling | 5.6% | 12.0% |
| Hyprland's GPU busy, scrolling | 51% | 21% |
| Power, scrolling / 1080p60 video / idle | 15.2 / 11.8 / 5.4 W | 12.3 / 10.3 / 5.4 W |

Chromium's own GPU work grows 2.2×, with 2.25× the pixels, and the GPU never
left its lowest clock. Overall it came out cheaper, because the fractional
window was 1 px off its viewport (1541 against 1540 device px), which made
Hyprland's work per frame 2.5×; at 2× there is no such mismatch. The cost is
in the text: drawn at 2× and shrunk by 1.5 with smoothing (1.6 at 1.25), a
little softer than native rendering. The UI has no separate scale in this mode, so
the toolbar is at one desktop px per DIP, about 5% over 0.95 (table below).
2 is a whole number, which turns off the fractional fix described below, but
at 2 every DIP edge falls on a whole device row, so there is no
part-transparent row to fix. That is reasoned from the cause, not measured.

`../figma/README.md` measured the same mode for Figma and rejected it there,
where there are no 1× images to gain: Hyprland's downscale left a grey fringe
on the canvas's text and icons.

From 2026-10-11 to 12, `--force-device-scale-factor=0.95` pinned Chromium's UI
scale. It was picked at monitor scale 1.25, where 1.25 × 0.95 = 1.1875 device
pixels per DIP, exactly 19 for every 16. At 1.33333 (2026-10-11 to 12) it
was 1.2667, 19 for every 15. The sizes in desktop px below are
the same at either scale.
Chromium's
toolbar is fixed in DIPs (a 34-DIP address bar and buttons, 35-DIP tabs), and
the address bar text is always 14 DIP, whatever the GTK font. Only tab titles
follow the GTK font. So the one control is the UI scale, and it moves the
whole toolbar and its text together:

| UI scale | Tab titles | Address bar text | Bar height | (desktop px) |
|---|---|---|---|---|
| GTK factor, 71/64 (2026-10-10 to 11) | 13.3 | 15.5 | 37.7 | |
| 0.9 (measured, a few hours on 2026-10-11) | 10.8 | 12.6 | 30.6 | |
| 0.95 (2026-10-11 to 12) | 11.4 | 13.3 | 32.3 | |
| **2, fractional off (now)** | **12** | **14** | **34** | |

At the GTK factor, tab titles matched the desktop's text, but the address bar
read as huge next to everything else. At 0.95 its text was 13.3, the same as
every other app's, and tab titles a step smaller, as Safari's are. The scale
was picked for its ratio. 0.9 came first, at 9/8, the cleanest under 1. Asked
to go up a step, 0.95 was the clean one between 0.91 and 0.98: 19/16, so edges
fell on 16ths of a pixel and multiples of 8 DIP on half pixels. At 1.387 none
line up. The flags file's git history has the candidates. The cost: Chromium
no longer follows `omarchy display text size`, so the number has to move by
hand with it. Pages scaled with it too, so the default zoom was 1/0.95,
105.263% (§4), which put them back at the monitor's 1.33333 device px per
CSS px. At 2× the toolbar still ignores the text size. Pages follow it since
2026-10-15, through the default zoom (§4).

For a day before that there was no flag at all. The UI followed the monitor
scale times the GTK text factor, 10/9 at text size 13, which Chromium rounds
to 71/64 (1.387 device px per DIP), and pages were at Chromium's own 100%.

**Why the old `=1` flag went, and why 0.95 was fractional.** `--force-device-scale-factor=1` was written to pin the
device pixel ratio to 1 under the monitor scale (browser UI 20% under the
desktop at 1.25, as tuned on DP-2; 25% at 1.33333), paired with 110% zoom.
On Chromium 152 under Wayland it no longer did that (measured 2026-10-10):
the window renders at the monitor scale whatever the flag says, and the flag
only replaced the GTK text factor with 1
(`WaylandWindowManager::DetermineUiScale`). It still made Chromium report the
display's scale as exactly 1, and that had a cost:

- Chromium has a fix for fractional scales.
  `AvoidCrackingForFractionalDisplay()` in
  `browser_view_tabbed_layout_impl.cc` shows an opaque, toolbar-coloured
  background behind the toolbar whenever the display scale is not a whole
  number. The forced 1 kept it off.
- The toolbar background is an anti-aliased path (`CustomCornersBackground`).
  At 1.25 its bottom edge ends three quarters of the way into a device row.
  Chromium's window on Linux is always translucent, so that row stayed 75%
  opaque, and the wallpaper showed through just above the toolbar/page line,
  focused or not.
- Measured in dark, one device row above the line: `#1E1E1E` along the whole
  width with Hyprland's `force_rgbx` (alpha ignored), which is 75% of the
  `#282828` toolbar. Without it, `#27251E` and `#393F49` toward the right,
  where the wallpaper behind is coloured.

Measured after the relaunch without the flag (unfocused, 2026-10-10): the row
above the line matches the toolbar rows to within 1 per channel, including
where the wallpaper behind is coloured, and the line is a single device row.
Dropping the flag brings the text factor back, so UI and pages both grew by
9%. Asked on 2026-10-10, the zoom stays at 110% rather than dropping to 100%,
which would have kept pages where they were. Later that day the GTK UI font
went from 11pt to 9pt, so every app's text is the text size. Tab text went
from 16.4 to 13.3 desktop px. The factor went from 12/11 to 10/9, so the rest
of the UI and pages grew by another 1.4%. Then the 110% zoom went (§4), and
pages came down 9% to 1.387 device px per CSS px. The next day a 0.9, then 0.95, flag
and 110% zoom replaced both (§2, §4).

The flag file is Omarchy's, so our lines go in a fenced block, as in every
other shared config here. The launcher skips "#" lines, which makes the
markers inert. Our scale flag is inside the block. A copy outside it would be
passed twice, or, if it is an old whole-number `=1` in fractional mode, turn
the fix off again, so `chromium.sh` deletes any copy outside the block.

## 3. A repeated --enable-features is not merged

A repeated --enable-features is not merged: base::CommandLine keys switches
by name, so the last one wins outright and everything an earlier copy named
is dropped (measured both ways round -- see the snippet's own header). Our
block is appended, so it is always the last one, which means it has to
restate whatever Omarchy's stock line asks for. Nothing keeps the two in
step automatically, so compare them and say so rather than silently turning
an Omarchy feature off on the next update.

--disable-features is the same switch machinery and is checked the same
way: Omarchy ships no such line today, but if it ever adds one, ours would
drop it just as silently.

## 4. Default page zoom, derived from the scale flag and the text size

`chromium.sh` computes the zoom from the flags file and from the GTK text
factor that step 7b's text size has just set, so none of them can drift
apart. Two parts, multiplied:

- **Geometry.** While `WaylandFractionalScaleV1` is disabled, as now (§2), the
  scale flag sets only the rendering scale and a CSS pixel is already one
  desktop pixel: 100%. With fractional scaling on, the flag is a UI scale that
  pages inherit, and this part is 100 divided by it.
- **Text** (since 2026-10-15). 12 × the GTK factor / 13: **143.594%** at text
  size 18 (factor 1.5556), 112.818% at 14, 102.563% at 13. Without a readable factor, the
  zoom is the geometry part alone.

The text part keeps macOS's ratio of web text to UI text. There a CSS pixel
is one point, so web body text is 16 against the system's 13, 1.23 to 1. Here
every app's text is 12 px times the factor, 18.7 desktop px at text size 18,
so at 100% it would be 16 against 18.7, 0.86 to 1 (1.09 at 14), and pages read small next to
everything else. At 143.594% body text is 22.98 desktop px (18.05 at 14). The text size
departs from macOS's 13 on purpose (`reference/BUILD.md`), and pages now
follow it rather than staying at macOS's proportions. The author had zoomed
four sites to 110% by hand (Gmail, YouTube, LinkedIn, cllp.se), which pointed
the same way; those entries were cleared so the sites follow the default. The
cost is macOS's geometry: a CSS pixel is 1.128 desktop px rather than one, so
a 1280 px layout takes 1444.

The zoom follows the text size saved in `display.conf` when apply.sh runs,
not live: `omarchy display text size` moves the GTK factor and not this. The
toolbar does not follow the text size either way (§2).

From 2026-10-11 to 12 the geometry part gave 105.263% for 0.95, with no text
part. Page size was the product of the two, 1.2667 × 1.0526 = 1.33333 device
px per CSS px (1.1875 × 1.0526 = 1.25 when picked). That is exactly the
monitor scale, so a CSS pixel was one desktop pixel, as it was at 2× and 100%
from 2026-10-12 to 15: macOS's geometry, one CSS pixel per point, which the
text part gives up for macOS's text ratio.

**A default between Chromium's zoom steps is added to them.** Ctrl+plus and
Ctrl+minus walk Chromium's preset steps (…, 100, 110, 125, …), and
`PageZoom::Zoom` (`components/zoom/page_zoom.cc`) inserts the default zoom
when it is not one of them: 125 → 143.594 → 150 (100 → 110 → 112.818 → 125
at text size 14), and Ctrl+0 returns to it. Read from Chromium's source on 2026-10-15, not yet measured on 152. Until
then this section said Ctrl+plus and Ctrl+minus never landed back on 105.263%,
which the source contradicts, and counted 100% being on the steps in its
favour. The one cost: from the default, Ctrl+plus is a 4.5% step to 150% (at 14,
Ctrl+minus was a 2.5% step to 110%).

For revert.sh, the step records the zoom found before its first apply,
refusing 100 and 105.263, which earlier versions of this step set. When it
records nothing it leaves the state file empty, which marks the first apply as
done. Without that, a later text size, which moves our own value, would get
the old value recorded as the machine's.

History: 110% paired with the old `=1` flag until 2026-10-10. It was dropped
with the flag (pages then followed the GTK factor at 100%). It came back a day
later with the new flag, at 125% (with 0.9), then 110% (with 0.95), then
105.263%, then 100% with the 2× rendering on 2026-10-12, then 112.818% with
the text part on 2026-10-15, and 143.594% at text size 18 on 2026-10-16. Like every Preferences write, it needs Chromium
closed (see the script).

There is no command-line flag for default page zoom; the script header has
what was checked, and the log scale the preference is stored in. revert.sh
still restores a zoom recorded before the first apply, if there was one.

## 5. The third Chromium setting with no flag and

The third Chromium setting with no flag and no policy: a neutral browser UI.
The seed Omarchy feeds Chromium as BrowserThemeColor cannot give one -- a
zero-chroma seed, which both of our themes ship, comes back out of Material's
tonal-spot scheme as a faintly cyan palette. Two profile keys are needed and
neither is enough alone: the system (GTK) theme for the frame and the menus,
grayscale for the accent the GTK theme leaves behind (the omnibox focus ring
is a dark teal without it). The script header has the measurements and the
two attempts that lose to the policy. Recorded before it is changed, on the
same terms as the zoom above.

## 6. record_prior refuses one value

record_prior refuses one value, and this step can leave more than one that
is ours: the grayscale half was added after the system-theme half shipped,
so a machine that ran the earlier version reads back `st=1,gs=` -- half our
own work, which must not be recorded as what the machine came with.

## 7. LAST on purpose

LAST on purpose. This is the only half of this script that needs sudo, so it
runs late (step 9, with apply.sh's other sudo steps 8b, 9b, 10 and 11) rather than
stalling a run halfway through on a password prompt. It used to sit between
7f2 and 7h.
Spellcheck / Translate / password-save-prompt / Autofill / Print / Cast /
QR-code / Reading-list all end up here, not in a Preferences file.
An earlier version of this step wrote the first five as plain Preferences
keys instead — a plain pref only changes the *default*, so Settings still
showed the toggle as changeable, and per Chrome's own docs a bare
`translate.enabled` pref (unlike the `TranslateEnabled` policy) never
suppresses the manual "Translate to…" context-menu entry, only the
automatic offer. Confirmed live on this machine: the pref round-tripped
correctly and the menu item was still there. (It also silently failed for
four of the five keys regardless — `browser.enable_spellchecking`,
`translate.enabled` and both `autofill.*` keys have dots in their real pref
name, and Chromium's JsonPrefStore nests dotted names into nested objects
on write/read; writing them as flat top-level keys with a literal dot in
the JSON key name — as that version did — creates a key Chromium never
reads. Only `credentials_enable_service`, with no dot, actually landed.)
The enterprise-policy names for all five (`TranslateEnabled`,
`SpellcheckEnabled`, `PasswordManagerEnabled`, `AutofillAddressEnabled`,
`AutofillCreditCardEnabled`) are confirmed present in this machine's
installed Chromium binary. Policy also has no "must be closed to write"
trap: `chromium --refresh-platform-policy --no-startup-window` reloads the
whole managed directory live, so a running Chromium picks this up with no
relaunch — the same mechanism Omarchy uses for its own color.json.

That refresh used to come for free: omarchy-theme-set-browser runs it on
every theme-set, and this step sat BEFORE step 8. Now that it runs after,
step 8's refresh has already happened by the time this file is written, so
the refresh is invoked explicitly below. It mirrors that script's own
refresh_running_browser: `pgrep -x chromium`, where -x matches the process
NAME — unlike -f, which matches whole command lines and would happily match
this script for containing the string.

Mirrors Omarchy's own /etc/chromium/policies/managed/ guard verbatim (see
omarchy-theme-set-browser-policy): only write into a policy directory that
already exists, since Chromium (or another Chromium-family browser sharing
this path) being absent means the directory won't exist either, and
creating one would hand a browser a managed-policy root it doesn't
otherwise have. `install` (no -D) leaves ownership at root:root under sudo,
which also matters here: a one-time Omarchy migration purges anything in
this directory NOT owned by root.

DevTools is deliberately NOT in this list. DeveloperToolsAvailability=2 was
here originally, as part of the context-menu declutter, but it is the one key
whose blast radius went well past the menu: it blocks Inspect everywhere,
including your own local dev servers. Dropping the key restores Chromium's
own default (0 — DevTools available except on force-installed extensions)
rather than asserting a value, which is what a managed policy should do for a
setting we have no opinion about. "Inspect" comes back in the context menu as
a consequence; there is no lever that separates the two.

ExtensionInstallForcelist pins two extensions, both by ID against Google's
CRX endpoint (the only update URL the Chrome Web Store serves):
  ddkjiahejlhfcafbddmgiahcphecmpfh  uBlock Origin Lite
  ghmbeldphafepmbegfdlkpapadhbakde  Proton Pass
Both IDs verified against the vendors' own listings, not typed from memory —
the store has a long tail of copycats trading on these names, and an ID is
the only identifier a forcelist entry actually matches on.

uBOL rather than uBlock Origin because MV2 is gone: `grep -a` on this
machine's chromium binary finds no ExtensionManifestV2Availability at all
(Chromium 152), so the policy that used to force MV2 back on no longer
exists to set. uBOL installs in its Basic filtering mode and the mode is a
per-profile setting with no policy behind it — raise it to Optimal by hand,
once, in the extension's own UI. A forcelist entry controls presence, not
configuration.

Proton Pass is the other half of PasswordManagerEnabled:false above: that key
turns off Chromium's built-in manager and save prompts, which leaves nothing
offering to store a credential unless something else does.

Forced means forced: neither extension can be removed or disabled from
chrome://extensions while this file is in place. That is the point (they
survive a profile reset), but it is also the usual reason an extension looks
stuck — revert.sh removing this file is the supported way out, and Chromium
uninstalls both on the next policy refresh once it is gone.

Note the interaction with the DevTools paragraph above: Chromium's default 0
means "available EXCEPT on force-installed extensions", so from here on there
are two extensions whose own pages and service workers cannot be inspected.
Pages we did not write, so this costs nothing; worth knowing before it reads
as a DevTools bug.

## 8. Profile avatar, by replacing a built-in one's picture

There is no pref, policy or theme key for the avatar, and Customize profile
only offers the built-in set. So `avatar.png` (192×192, the size of the stock
pictures) goes over built-in avatar 55's picture,
`~/.config/chromium/Avatars/avatar_abstract_sandwich.png`; the profile here
uses 55, and the step warns about any profile that does not. From the
Chromium 152 source (`chrome/browser/profiles/`):

- The toolbar asks for the full-size picture
  (`GetAvatarIconWithType(…, use_high_res_file=true)`), which is read from
  that folder (`GetHighResAvatar`, `GetPathOfHighResAvatarAtIndex`).
- It is decoded as PNG only (`ReadBitmap`: `CreateFrom1xPNGBytes`), so an SVG
  has to be rendered first, and the toolbar crops it to a circle
  (`SHAPE_CIRCLE`).
- Chromium downloads it only when the file is missing (`RunCallbackIfFileMissing`),
  which it checks for every profile's avatar at launch (`DownloadAvatars`). So
  ours is never overwritten, and `revert.sh` just deletes it: the stock picture
  comes back on the next launch.
- It is read once per run and cached, so a change shows after a Chromium
  restart. Writing it while Chromium runs is safe.

The picker in Customize profile still shows the sandwich: its tiles come from
the low-resolution copies built into Chromium. A signed-in profile's Google
account picture would take precedence; the profile here is not signed in.

## From the step table

Chromium: drawn at 2× and scaled down by Hyprland (§2):
`--force-device-scale-factor=2` with `WaylandFractionalScaleV1` disabled, so
pages report `devicePixelRatio` 2 and load sharp images while layout stays in
desktop pixels, the toolbar at one desktop px per DIP (14 px address bar
text) and the default page zoom at 12 × the GTK factor / 13, `143.594%` at
text size 18, which keeps macOS's ratio of web text to UI text (§4); `--enable-features=…,OverlayScrollbar` for the
thin auto-hiding scrollbar (restating Omarchy's own feature, because a
repeated `--enable-features` is last-wins rather than merged);
`--disable-features=MediaSessionService,…`, the only lever that removes the
global-media-controls button beside the profile avatar — at the cost of
Chromium's MPRIS export (media keys, now-playing widgets); and a neutral
browser UI — Omarchy's `BrowserThemeColor` policy runs our grey seed through
Material's tonal-spot scheme and comes back cyan, which takes both the system
(GTK) theme (frame and menus) and grayscale (the accent: the omnibox focus
ring is a dark teal without it)

## From the step table

Chromium context-menu declutter: spellcheck, translate, password-save prompt,
address/card autofill, Print, Cast, "Create QR Code", and "Add to reading
list" off — all eight as enterprise policy, none as a Preferences key. (An
earlier version wrote the first five as plain `Preferences` booleans; a bare
pref only changes the default, so Settings still showed the toggle as
user-changeable, and per Chrome's own docs the bare `translate.enabled` pref
doesn't suppress the manual "Translate to…" context-menu entry the way the
`TranslateEnabled` policy does — confirmed live, plus four of those five keys
have a dot in their real pref name and Chromium nests dotted pref names into
nested JSON on write, so a flat key with a literal dot in it is never read
back at all.) Needs **sudo** (the only step in this script that does), and
only writes into `/etc/chromium/policies/managed/` if that directory already
exists — mirroring Omarchy's own guard, so a machine without Chromium doesn't
get handed a policy root it didn't have. No relaunch needed if Chromium is
running: the step calls Chromium's `--refresh-platform-policy` itself after
writing (step 8's `omarchy-theme-set-browser` refresh has already run by
then), which reloads the whole managed directory, same as Omarchy's own
`color.json`. The same file sets `NewTabPageLocation` to `about:blank`
(2026-10-11, asked for), so a new tab is an empty page rather than Chromium's
New Tab page. Like the declutter keys, it is policy rather than a Preferences
key, so Settings shows it as managed. It also carries
`ExtensionInstallForcelist`, which pins two extensions by ID against Google's
CRX endpoint: **uBlock Origin Lite** (`ddkjiahejlhfcafbddmgiahcphecmpfh`) and
**Proton Pass** (`ghmbeldphafepmbegfdlkpapadhbakde`). uBOL rather than uBlock
Origin because MV2 is gone — Chromium 152's binary contains no
`ExtensionManifestV2Availability` string at all, so there is no longer a
policy to force MV2 back on; Proton Pass is the other half of
`PasswordManagerEnabled: false`, which otherwise leaves nothing offering to
store a credential. Both are unremovable from `chrome://extensions` while the
file is in place, and uBOL's filtering mode is a per-profile setting with no
policy behind it — raise it from Basic to Optimal by hand, once

Script: [`chromium.sh`](chromium.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
