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
