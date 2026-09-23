# macOS keyboard parity: audited against Apple's own list

An audit of every chord this machine actually binds against
[Apple's *Mac keyboard shortcuts*](https://support.apple.com/en-us/102650)
(`support.apple.com/en-us/102650`), taken **2026-09-23** against Omarchy 4.0.4
and a live set of **151 binds**. Nothing here is implemented — it is the list of
what is missing, what is blocked, and what was ruled out, so the next pass is a
decision rather than a re-derivation.

The chords that *are* implemented live in
[`overrides/hypr/macos-shortcuts.lua`](overrides/hypr/macos-shortcuts.lua),
and the *why* of each one lives in that file's comments. This document does not
restate them; it covers the gap.

---

## How to re-run it

**Read the live set, not the repo's files, and not Omarchy's.**
`keybind-allowlist.conf` unbinds every chord it does not list, and it prunes
most of Omarchy's stock set — so a chord that looks taken in
`/usr/share/omarchy/default/hypr/bindings/` is very often free here. That single
fact changed the answer for six of the nine candidates below: `SUPER+CTRL+Q`
(Omarchy: Calculator), `SUPER+CTRL+SPACE` (Background switcher), `SUPER+CTRL+F`
(Tiled full screen), `SUPER+SHIFT+S` (Google Maps), `SUPER+ESCAPE` (System menu)
and `PRINT` (Screenshot) are all **unbound** on this machine.

```bash
hyprctl binds -j | jq -r '.[] | "\(.modmask) \(.key)\t\(.description)"' | sort
```

`modmask` is a bitfield: **SHIFT 1, CAPS 2, CTRL 4, ALT 8, SUPER 64**. So 64 is
SUPER, 65 SUPER+SHIFT, 68 SUPER+CTRL, 72 SUPER+ALT, 12 CTRL+ALT, 13
CTRL+ALT+SHIFT, 76 CTRL+ALT+SUPER. Grep a candidate by key across *every*
modmask before calling it free — eyeballing the sorted list is how you miss the
one entry that matters.

**One caveat applies to every chord added from here on.** While Figma is
focused, keyd binds the meta key to the `figma:C` layer, so Hyprland never sees
SUPER except for the layer's carve-outs (`tab`, `q`). Any new SUPER chord is
therefore inert in Figma and arrives at Figma as the Ctrl-equivalent instead —
`SUPER+SHIFT+3` becomes Ctrl+Shift+3, `SUPER+CTRL+Q` becomes a plain Ctrl+Q.
That is the accepted cost recorded in `overrides/keyd/default.conf`; it is not a
reason to skip a chord, but it is a reason not to promise it works everywhere.

---

## Two findings that are not chords

**There is no screenshot keybind on this machine at all.** The allowlist
comments out `PRINT` (Screenshot) and `ALT + PRINT` (Screenrecording) with no
supersession note, so `omarchy-capture-screenshot` is reachable only through the
SUPER+SPACE menu. Apple's Shift-Cmd-3/4/5 would fill a genuine hole rather than
rename an existing one.

**Shift-Cmd-Q is "Log out of your macOS user account" on macOS**, and it is what
this repo gave the close-every-window sweep on 2026-09-23. Apple's own chord for
that sweep is Option-Cmd-W ("Close All Windows"), which was offered and declined
in favour of Shift+Q. Recorded so the divergence is deliberate rather than
discovered later: `SUPER+SHIFT+Q` here closes an app's windows, it does not log
out.

---

## Not yet wired, and nothing live conflicts

Each chord below was checked against every modmask in the live set and is
unbound. Mechanisms are ones this repo has already proven, not guesses.

| macOS chord | Apple's wording | chord here | mechanism |
|---|---|---|---|
| Ctrl-Cmd-F | "use or stop using the app in full screen" | `SUPER + CTRL + F` | `hl.dsp.window.fullscreen({ mode = "fullscreen" })` |
| Ctrl-Cmd-Q | "lock your screen" | `SUPER + CTRL + Q` | `omarchy-system-lock` |
| Ctrl-Cmd-Space | "show the Character Viewer" | `SUPER + CTRL + SPACE` | `omarchy-shell shell toggle omarchy.emojis` |
| Option-Cmd-Esc | "force quit an app" | `SUPER + ALT + ESCAPE` | `hl.dsp.window.kill()` |
| Shift-Cmd-3 | screenshot, whole screen | `SUPER + SHIFT + 3` | `omarchy-capture-screenshot fullscreen` |
| Shift-Cmd-4 | screenshot, region | `SUPER + SHIFT + 4` | `omarchy-capture-screenshot region` |
| Shift-Cmd-5 | "take a screenshot or make a screen recording" | `SUPER + SHIFT + 5` | `omarchy-menu toggle capture` |
| Option-Delete | "delete the word to the left of the insertion point" | `ALT + BACKSPACE` | Ctrl+Backspace, `terminal_aware` → Ctrl+W (readline's own word-erase) |
| Option-Up/Down | paragraph jump; Option-Shift-Up/Down "extend text selection to the beginning/end of current paragraph" | `ALT + UP/DOWN`, `ALT + SHIFT + UP/DOWN` | Ctrl+Up/Down, Ctrl+Shift+Up/Down |
| Shift-Cmd-S | "show the Save As dialog, or duplicate the current document" | `SUPER + SHIFT + S` | Ctrl+Shift+S |
| Option-Shift-Cmd-V | "Paste and Match Style" | `SUPER + SHIFT + V` | Ctrl+Shift+V |

Notes on three of them:

- **Force Quit is the one place `window.kill()` belongs.** The Cmd+Q comment
  rejects it as a hard kill that gives an app no chance to prompt — which is
  precisely what Option-Cmd-Esc is for, so the rejection there is the argument
  for it here.
- **Option-Delete needs the terminal branch, not the terminal guard.** Ctrl+W is
  readline's `backward-kill-word`, i.e. the wanted behaviour, so this is a
  `terminal_aware` case like Cmd+W and not an `unless_terminal` one.
- **Paste-and-Match-Style is shortened, not literal.** Apple's chord carries four
  modifiers; `SUPER+SHIFT+V` is what Linux apps already answer with Ctrl+Shift+V.
  The literal `SUPER+ALT+SHIFT+V` is equally free if faithfulness wins.

---

## Blocked by the keyboard, not by the desktop

**Cmd-Up / Cmd-Down ("move the insertion point to the beginning/end of the
document") and their Shift variants.** `SUPER+UP/DOWN` and `SUPER+SHIFT+UP/DOWN`
are all free now that window focus moved to CTRL+ALT, so the allowlist's old
reason for leaving these out ("SUPER+UP/DOWN is still live as
window-focus-up/down") no longer holds. The real blocker is the one that caused
that move: the Preonic's firmware turns **Gui+Up into `/`**.

If that is still true, `SUPER+UP` does not merely fail — it arrives as
`SUPER+slash`, which the generic forwarder binds to **Ctrl+/ (toggle comment)**.
Wrong action, not a no-op.

Unresolved here on purpose: input cannot be synthesized below the keyboard's own
firmware, so this needs a **press test** — hit SUPER+UP in an editor and see
whether a comment marker appears. If it does, document start/end belongs on
another chord or nowhere.

---

## Deliberately absent, but the recorded reason is narrower than the option

`Cmd-H` ("hide the windows of the front app"), `Cmd-M` ("minimize the front
window to the Dock") and `Cmd-grave` ("switch between the windows of the app
you're using") are documented in `macos-shortcuts.lua` as left unbound on
purpose, because *forwarding* them to Ctrl would invent behaviour rather than
reproduce macOS (Ctrl+H opens browser history; Ctrl+` toggles Cursor's terminal
panel).

That reasoning rules out the forward and says nothing about a **compositor
action**, which is a different proposal and the one this repo already uses for
the close ladder: hide and minimise both map onto Hyprland's special workspace,
and "cycle this app's windows" is `hl.get_windows({ class = … })` plus a focus —
the same machinery `SUPER+SHIFT+Q` runs. All three chords are free. Undecided,
not rejected.

---

## Low value, listed so they aren't re-found

- **Cmd-Delete** "move the selected item to the Trash" — only meaningful in a
  file manager, where the Delete key already does it. `SUPER+BACKSPACE` → Delete
  if ever wanted.
- **Shift-Cmd-minus / Shift-Cmd-plus** "decrease/increase the size of the
  selected item" — `SUPER+equal/minus` already zoom, and the Shift pair is
  app-specific.
- **Option-Cmd-F** "go to the search field", **Option-Cmd-T** "show or hide a
  toolbar", **Option-Cmd-I** inspector, **Option-Cmd-C/V** Copy/Paste Style —
  each is one app's menu item rather than a desktop convention.
- **Cmd-K** — Apple lists it as "add a web link" (text) and "Connect to Server"
  (Finder). Here it is the terminal clear, and inert elsewhere, which
  `macos-shortcuts.lua` already argues for: the non-terminal meaning is whatever
  the focused app decided (Cursor's AI prompt, Slack's switcher), so there is
  nothing general to synthesize.

---

## Out of scope, enumerated so it isn't re-derived

- **The Finder go-to-folder family** — Shift-Cmd-C/D/F/G/H/I/K/O/U,
  Option-Cmd-L, Cmd-1/2/3/4 as view modes, Command-Left/Right-Bracket as folder
  history, Cmd-Up as parent folder. No desktop-wide referent; the file manager's
  own bindings are the right home.
- **The fn layer** — Fn-A/C/D/N/Q, Fn-Shift-A, Fn-Fn, Fn-Delete, Fn-arrows.
  There is no fn modifier to bind.
- **Power-button chords, Siri, Quick Look, Type to Siri, Mission Control
  variants** — either no hardware equivalent or no feature to point at.
- **Apple's emacs-style Control set** — Ctrl-A/E/K/H/D/F/B/N/P/O/T/L. Partly
  native already (readline in a terminal, GTK text fields for some), and
  Ctrl-A specifically is *select all* on Linux, so synthesizing the family would
  break more than it fixed. Cmd+A already selects all here.
- **Cmd-Option-Left/Right** (previous/next tab) is not on Apple's page at all —
  it is Safari's and Chrome's, not the system's. `SUPER+ALT+LEFT/RIGHT` is free
  and Ctrl+Page_Up/Down is the Linux equivalent, if it ever comes up.

---

## Already covered

Everything else on Apple's page resolves to something here:

| Apple | here |
|---|---|
| Cmd-X / C / V | `clipboard.lua`'s universal cut/copy/paste |
| Cmd-Z, Shift-Cmd-Z | Undo / Redo, terminal-guarded |
| Cmd-S | Save, terminal-guarded |
| Cmd-W | Close tab (Ctrl+Shift+W in a terminal) |
| Cmd-Q | Close window — see the file for why it is not the app |
| Cmd-A, F, G, O, D, E, I, U, B, J, Y and their Shift pairs | the generic Cmd→Ctrl forwarder |
| Cmd-comma "open settings for the front app" | forwarder |
| Cmd-semicolon "find misspelled words" | forwarder |
| Cmd-1…9 | forwarder — which is also browser tab N |
| Cmd-[ / ] and Cmd-{ / } | forwarder (`bracketleft`/`bracketright`) |
| Cmd-T new tab, Shift-Cmd-T reopen, Cmd-R reload, Shift-Cmd-R force reload, Cmd-N new window, Cmd-L address bar, Shift-Cmd-P command palette | explicit binds |
| Cmd-P "open a print dialog" | forwarder — with the known conflict that Ctrl+P is Quick Open in Cursor, recorded in the file |
| Cmd-Space "show or hide the Spotlight search field" | `SUPER+SPACE`, the Omarchy menu |
| Cmd-Tab "switch to the next most recently used app" | `SUPER+TAB`, the window switcher |
| Cmd-Left/Right, Shift-Cmd-Left/Right | line start/end and select-to |
| Option-Left/Right, Option-Shift-Left/Right | word jump and select-word |
| Shift-arrows | native, nothing to bind |
