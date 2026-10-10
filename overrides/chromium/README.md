# Chromium

Two halves that run at opposite ends of an apply run: user-level flags and a neutral UI early; the managed policy last, because it is the only part needing sudo.

## 1. Two halves

Two halves, and they run at DIFFERENT points of an apply.sh run: the
user-level flags/UI half early (it was step 7d), the managed policy last
because it is the only part needing sudo and a password prompt should not
stall a run halfway through (it was step 9). Calling this with no argument
-- which is what running it by hand does -- does both, in that order.

## 2. No scale flag and no page zoom

Since 2026-10-10 there is no scale flag. Browser UI follows the monitor scale
times the GTK text-scaling factor, which `omarchy display text size` sets.
That is 10/9 at text size 13 with the 9pt GTK font, rounded by Chromium to
71/64: 1.25 × 71/64 = 1.387 device pixels per DIP. Tab titles and menus are
the GTK UI font in DIP (12) times the same factor, which is the text size,
like every other app (`../README.md`, "One text size"). Pages render at
Chromium's own 100% (§4), so at the same 1.387: page text follows the text
size as well, and only the page's own CSS decides how big it is.

**Why the flag went.** `--force-device-scale-factor=1` was written to pin the
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
pages came down 9% to 1.387 device px per CSS px.

The flag file is Omarchy's, so our lines go in a fenced block, as in every
other shared config here. The launcher skips "#" lines, which makes the
markers inert. A copy of the flag outside the block would turn the fix off
again, so `chromium.sh` deletes one wherever it finds it.

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

## 4. No default page zoom

No default page zoom since 2026-10-10. The step used to set 110%, as the other
half of the scale flag in §2 (page size was the product of the two). With the
flag gone and every app's text at the text size, 110% only made pages 10%
larger than everything else, and it was removed when asked. The step now
clears `partition.default_zoom_level` if it still holds that 110%, so
Chromium's own 100% applies. It leaves any other value alone, since that is a
choice made in Chromium's settings, not ours. Like every Preferences write, it
needs Chromium closed (see the script).

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

## From the step table

Chromium: no default page zoom (the 110% this step set until 2026-10-10 is
cleared), so pages render at the monitor scale times the GTK text factor,
1.25 × 71/64 = 1.387; no scale flag, since
`--force-device-scale-factor=1` turned off Chromium's fix for the see-through
row above the toolbar/page line at fractional scales (§2); `--enable-features=…,OverlayScrollbar` for the
thin auto-hiding scrollbar (restating Omarchy's own feature, because a
repeated `--enable-features` is last-wins rather than merged);
`--disable-features=MediaSessionService`, the only lever that removes the
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
