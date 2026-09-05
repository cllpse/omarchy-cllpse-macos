# omarchy-cllpse-switcher

A macOS-style window switcher HUD for the Omarchy 4 (Quickshell) shell — hold
`SUPER`, tap `TAB` / `SHIFT+TAB` to cycle a horizontal strip of open windows,
release `SUPER` to focus the highlighted one.

Plugin id **`io.eject.window-switcher`** (kept for the `shell.json` `plugins[]`
entry and the `omarchy-shell shell summon` keybinds in `~/.config/hypr/bindings.lua`).
`overrides/apply.sh` symlinks this folder to
`~/.config/omarchy/plugins/io.eject.window-switcher`; `revert.sh` removes the
symlink.

## Files

| File | Role |
|---|---|
| `manifest.json` | schemaVersion 1, `kinds: ["panel"]`, `keepLoaded: true`, entry point `Hud.qml`. |
| `Hud.qml` | The whole plugin. Click-through `Overlay` layer surface, namespace `omarchy-window-switcher-hud`. Keyboard-driven only — Hyprland keybinds `summon` it with a `{"action":"next|prev|commit"}` payload. |

## Look

The card binds `Color.menu.background` / `Color.menu.scrim` / `Color.menu.border`
and `Style.cornerRadius`, so it tracks the active theme's menu chrome with no
plugin-side theming. Under **omarchy-cllpse-theme** that means:

- corner radius follows `decoration:rounding` (14) like every shell surface;
- translucency comes from `[menu] background-alpha` (0.92) in
  `omarchy-cllpse-theme/*/shell.menu.toml`;
- blur comes from the `hl.layer_rule` in
  `overrides/hypr/looknfeel-decoration.lua`, whose namespace match includes
  `window-switcher-hud` so the HUD blurs exactly like the Omarchy menu.

## Notes

- The plugins dir is watched with `inotifywait -r`; live edits inside a
  *symlinked* plugin may not auto-reload. Run `omarchy-restart-shell` after
  changing files here.
- The dir name is cosmetic — Omarchy keys plugins by `manifest.json` `id`, not
  the folder. The symlink is named for the id so enablement and keybinds don't
  care that the source moved.
