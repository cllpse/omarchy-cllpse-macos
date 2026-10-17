# Cursor

Cursor is themed in three separate places, because its settings live in three separate places: a JSON file we can merge, a SQLite DB we cannot, and a generated VS Code theme Omarchy owns.

## 1. Cursor's window chrome

Cursor's window chrome, repainted from Omarchy's own generated VS Code theme
so the editor frame matches every other window instead of wearing Bearded's
greys. Chrome only — the editor pane and syntax stay Bearded. Hook, because
the palette changes per theme; see the hook for the scoping.

## 2. Cursor

Cursor — deep-merge our editor prefs into settings.json with jq: our keys win,
any key we don't set is kept. Omarchy owns workbench.colorTheme (it rewrites it
to "Omarchy" on every `omarchy theme set`, via omarchy-theme-set-vscode), so
cursor/settings.json deliberately omits it. Cursor is the only editor of this
family installed here; VS Code / VSCodium would each want their own merge.

## 3. cursor/bearded-dark-tokens.json is the third input

cursor/bearded-dark-tokens.json is the third input: the syntax colours for
dark mode, derived from Bearded Theme Light by
cursor/derive-dark-from-light.py and scoped to the dark variant by name,
so light mode is untouched. jq's `*` merges objects recursively and takes
the right-hand side for arrays, which is what the textMateRules list wants.

## 4. Text is Omarchy's text size

Cursor's text is Omarchy's text size, like every other app's (2026-10-10;
`../README.md`, "One text size"). Cursor runs on Electron 42, which multiplies
every CSS px by the GTK text factor, about text size / 12. Measured with a
hidden Electron 42 window: `devicePixelRatio` 1.09375, the 12/11 factor at the
time, before any surface scale. So a CSS size of 12 lands on the text size.
The text size isn't held here; the factor carries it.

VS Code draws its own UI (sidebar, tabs) at 13 CSS px, and the editor and
terminal take their own sizes. `window.zoomLevel` -0.439 is 1.2^-0.439 = 12/13,
which puts the 13px UI at 12. `editor.fontSize` and
`terminal.integrated.fontSize` are 13 so they land there too. At text size 18
all three come out at 18.75 desktop px (13 × 12/13 × 100/64; 17.25 at 17, 14.6 at 14, 13.3 at 13).

History, same day: `editor.fontSize` used to be copied from the text size in
px. That counted the text size twice, once in the px and once in Electron's
factor. Both sizes were then 15 for a few hours, to match Chromium's tab titles
before those were brought down to the text size too.

## 5. No watcher

Following a later text-size change used to take a systemd path unit on
`~/.config/omarchy/shell.toml` (`cllpse-cursor-text-size.path`, its oneshot
`.service`, and the script in `~/.local/bin`), since that command fires no
hook. Electron's GTK factor carries the change now, so `cursor.sh` disables
and deletes those where an earlier apply installed them.

## 6. Cursor's window layout

Cursor's window layout — NOT settings keys. Both live in
~/.config/Cursor/User/globalStorage/state.vscdb, so the jq merge above cannot
reach them, and both get flipped by Cursor updates rolling out a new default.

  cursor/unifiedAppLayout          enum `{ Agent: "agent", Editor: "editor" }`,
                                   read out of Cursor's own bundle, default
                                   Editor. In `agent` the editor tab bar is
                                   replaced by the agent pane's own strip. Set
                                   here by a migration latched on
                                   cursor/migrateEditorMode.forceUnified.

  cursor/noTitlebarLayout.visibility
                                   `hide` puts `no-titlebar-layout` on <body>
                                   and applies a **-35px top inset to the whole
                                   workbench** -- exactly one tab-strip height.
                                   Cursor's own code:
                                     m = stored === "hide" && showTabs !== "none"
                                     body.classList.toggle("no-titlebar-layout", m)
                                     updateWorkbenchInsets({ top: m ? -35 : 0 })
                                   The intent is that the tabs themselves become
                                   the titlebar (there is a matching CSS rule
                                   giving .tabs-container `-webkit-app-region:
                                   drag`), but with our `window.controlsStyle`
                                   / `menuBarVisibility` hidden and
                                   `layoutControl.enabled` false the titlebar
                                   part is already collapsed, so the -35px eats
                                   the tab strip instead. Persisted from a
                                   `hide_titlebar_default` feature gate.

BOTH present as "the tabs disappeared" with `workbench.editor.showTabs` unset
(still `multiple`, the registered default) and every `tab.*` colour correct,
which sends you to the chrome hook for an hour. Verified by screenshotting the
live window, not by reading the config.

Each is written only over the one wrong value named below. An absent key is
already Cursor's default and is left absent, any other value is somebody's
deliberate choice and is left alone, and
cursor/migrateEditorMode.forceUnified is NOT cleared -- it reads as "this
migration already ran", so clearing it invites the migration to run again.

Gated on Cursor being closed, same as the merge above: Cursor holds this DB
open and rewrites it from memory. NEITHER `pgrep` form is relied on for that --
the binary is `electron` (/usr/lib/electron42/electron) and `pgrep -x cursor`
found nothing on Cursor 3.20 (on 3.22.7 the main process's NAME reads `cursor`,
every helper's `electron`), and `pgrep -f` is the whole-command-line trap in
CLAUDE.md.

Script: [`cursor.sh`](cursor.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.

## Editor preferences

Cursor editor prefs (Bearded colour + icon theme selected via
`autoDetectColorScheme`, so the editor follows Omarchy's light/dark through
`gsettings color-scheme` rather than through `workbench.colorTheme`, which
Omarchy overwrites on every theme-set; whitespace/format-on-save, chrome
trimmed — activity + status bars, menu bar, layout control, agents-window
button and the `custom` title bar's min/max/close all hidden) merged into
`settings.json` with `jq` — our keys win, `workbench.colorTheme` left to
Omarchy. The Bearded keys are the override's one marketplace dependency;
everything else in it is a stock Cursor key

## Indent guides: only the current scope's

Cursor has no "active guide only" setting, so `cursor-chrome.sh` paints the
inactive indent guides out. `editorIndentGuide.background1` is `#00000001`.
It isn't `#00000000` because Cursor's theming code (3.25.6, the VS Code
`indentGuides` participant) drops any level whose inactive or active colour is
fully transparent. With no level left it emits no indent-guide rules at all,
so the active guide disappears too. An alpha of 1/255 is invisible and still
counts.

The guide that stays, the one for the scope the caret is in, is the editor's
selection colour, alpha included: `editorIndentGuide.activeBackground1` is
copied from `editor.selectionBackground`. That's `#22A5C94D` on light
(Bearded Theme Light) and `#54D7FB4D` on dark (the dark derivation), 30% each.
The hook reads it from the derivation, else the active Bearded variant, which
is the same order Cursor resolves it in. Over the window it lands at
`#BCE4EF` on `#FFFFFF` and `#2E5661` on `#1E1E1E`. Tried on the way: black /
white at the alpha that lands on `muted` (`#BDBDBD` / `#565656`), which read
too dark beside the code, then 20% and 15% of the same, then Bearded's own
guide teal `#68919C` at 15%, 50% and 25%.

The matching-bracket box is off (`editor.matchBrackets: "never"`, in
`cursor/settings.json`), so the guide is the only scope marker. The two are
independent: `matchBrackets` is read only by the bracket-matching controller,
and the active guide comes from `getActiveIndentGuide`, which works off
indentation, not brackets.

Only level 1 is set. Both Bearded variants and the dark derivation set only
level 1, and levels 2–6 default to transparent, so Cursor drops them already.
These keys can't go in `cursor/settings.json`. The dark derivation puts an
opaque `#666E70` for `background1` inside the theme scopes, and a scoped key
beats an unscoped one, so the hook writes both keys into the scopes, after the
derivation. Probe:
`jq '."workbench.colorCustomizations" | map_values(objects | with_entries(select(.key | startswith("editorIndentGuide"))))' ~/.config/Cursor/User/settings.json`

## Window chrome

The colour theme is Bearded, chosen for its editor and syntax colours, but
everything around the code was its own palette — a grey frame, blue-tinted
`#202027` text fields and cyan/teal accents — against a desktop that is flat
neutral with a `#007AFF` accent. `cursor-chrome.sh` now copies **everything
except the editor canvas** out of Omarchy's *own* generated
`vscode-theme.json` into `workbench.colorCustomizations`, which sits above the
active theme: 487 of the 624 keys in each scope. `$KEEP` is the exception list
(the code area, brackets/guides/line numbers/cursor, `symbolIcon.`, and the
overview ruler + minimap marks, which have to agree with the canvas); `$EXACT`
takes three surfaces back from it (`editor.background`,
`editorGutter.background`, `minimap.background`). On top of the copy: every
hover/active state is normalised onto the tab's 25% `muted` wash — Omarchy
paints several of them the window colour (no feedback) or opaque `muted` (far
heavier than a selected tab) — and the three families Cursor registers that
Omarchy has no key for (`inlineEdit.`, `scmGraph.`, `errorLens.`) are
re-tinted to `charts.*` hues while keeping the alpha the Bearded variant gave
them. Three structural edges are put back that Omarchy paints the window
colour, i.e. invisible: `sideBar.border` (the sidebar/editor separator),
`tab.border` (between tabs, every tab, active or not) and
`editorGroupHeader.border` (the line under the tab strip — that key, *not* the
similarly named `editorGroupHeader.tabsBorder`, which is forced transparent).
Cursor paints two 1px rules there, one on the tabs container and one on the
`.title` element wrapping it, both `bottom:0; z-index:9`, and a parent's
`::after` paints over its children's — so only `editorGroupHeader.border` is
ever visible and a `tabsBorder` set instead is covered, which makes that key
look inert. Established by probe: colouring the four keys differently produced
zero pixels of the `tabsBorder` colour anywhere on screen. The edge is
strip-wide rather than per-tab because it has to be: of the 29 `tab.*` ids
Cursor registers, the only bottom-edge ones are `tab.activeBorder`,
`tab.hoverBorder` and their unfocused pair — there is no `tab.inactiveBorder`,
so a line under every tab can only come from the container, at the cost of
running past the last tab. The per-tab bars (`tab.activeBorder` and friends)
need no change: they are already derived as the hover wash flattened onto the
strip — the same muted at the same 25% over the same backdrop — so they land
on the identical rendered colour (`#2C2C2C` dark, `#EEEEEE` light) and
continue the line instead of breaking it. All take `muted` at 25% flattened
onto the window background, written as an opaque `#EEEEEE` light / `#2C2C2C`
dark rather than a value with alpha — flattened because `tab.border` is a real
CSS border painted over each tab's own background, so a translucent value
would change shade as tabs activate. 25% is the weight Omarchy
already gives every other divider of that class (`editorGroup.border`,
`panel.border`, `sideBarSectionHeader.border`), so they read as the same line
rather than outweighing their neighbours. `tab.lastPinnedBorder` stays at full
`muted`, a step heavier, so it still marks where the pinned tabs end. Values
come from Omarchy's generated file rather than a second derivation of
`colors.toml`, so there is nothing to drift, and both modes are correct by
construction. Only the editor canvas and its syntax stay Bearded
