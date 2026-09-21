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

## 4. editor.fontSize is DERIVED

editor.fontSize is DERIVED, not pinned. `omarchy display text size` is the
one knob for apparent text size across the desktop -- it already drives the
shell base size (px), the GTK scaling factor and the terminal point size
(px * 9/12) -- and VS Code's editor.fontSize is in px like the first of
those, so Cursor can ride the same knob instead of holding its own number.
The value in cursor/settings.json is the fallback for when the reading
fails; it is not the source of truth.

## 5. The derivation above is a one-shot

The derivation above is a one-shot, taken during this merge. Keeping it
tracking a LATER `omarchy display text size` needs a trigger, and
omarchy offers none: that command fires no hook, and none of the hook
dirs it does have (battery-low / font-set / post-boot / post-update /
pre-refresh-pacman / theme-set) covers text size. So the trigger is a
systemd path unit on the file the command writes.

User units, not system: the target is $HOME/.config/Cursor. The .path
is what gets enabled; it starts the oneshot .service, which is why only
the former is in [Install].

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
open and rewrites it from memory. NEITHER `pgrep` form tests for that -- the
process NAME is `electron` (/usr/lib/electron42/electron), so `pgrep -x cursor`
finds nothing, and `pgrep -f` is the whole-command-line trap in CLAUDE.md.

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
would change shade as tabs activate. 25% is the weight the weight Omarchy
already gives every other divider of that class (`editorGroup.border`,
`panel.border`, `sideBarSectionHeader.border`), so they read as the same line
rather than outweighing their neighbours. `tab.lastPinnedBorder` stays at full
`muted`, a step heavier, so it still marks where the pinned tabs end. Values
come from Omarchy's generated file rather than a second derivation of
`colors.toml`, so there is nothing to drift, and both modes are correct by
construction. Only the editor canvas and its syntax stay Bearded
