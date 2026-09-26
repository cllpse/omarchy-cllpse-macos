# Agent Task Patterns for omarchy-cllpse-macos

Patterns for common tasks. Each section is self-contained — read it, do it,
commit.

---

## Add a theme key to `colors.toml`

Both `omarchy-cllpse-theme-dark/colors.toml` and `omarchy-cllpse-theme-light/`
must be edited together.

1. Add the key in both files with its light and dark values.
2. If the key is used by a generated theme (btop, ghostty, vscode, etc.),
   check `omarchy-theme-set-templates` or the generated files to see if
   it already has a placeholder. If not, the key may need a template update.
3. Run `omarchy theme set <name>` on both themes to verify generation.
4. Do not commit generated files — only `colors.toml`.
5. If the key is used in `overrides/` (e.g. cursor chrome), update the
   consumer there too. Do not leave the two out of sync.

## Bump the window-switcher submodule

The switcher is a submodule at `omarchy-cllpse-plugin-switcher/`.
A change there requires two commits.

1. Commit the switcher change in the **submodule repo** and push.
2. In this repo: `cd omarchy-cllpse-plugin-switcher && git pull origin main`
   (or the relevant branch).
3. In the parent repo: `git add omarchy-cllpse-plugin-switcher && git commit`.
4. Push this repo.

Never edit files inside the submodule directory directly without committing in
the submodule first — the pointer will drift.

## Add an app icon

Icons live in two directories, keyed two different ways. See
`overrides/icons/AGENTS.md` for the full contract.

1. Determine if the mark should be recoloured (`icons/`) or kept verbatim
   (`verbatim/`). Recoloured only for silhouettes; anything defined by
   colour boundaries goes in verbatim.
2. Ensure the SVG has a **square `viewBox`** (e.g. `0 0 24 24`). The switcher
   scales from this; a non-square viewBox distorts.
3. The filename must match the **desktop entry's `Icon=`** for the Omarchy
   menu to find it. For the switcher, a second copy named for the **window
   class** may be needed (they often differ).
4. After adding, run `overrides/icons/app-icons.sh` to sync to `~/.icons/`.
5. Verify with `overrides/icons/AGENTS.md` check scripts — compare against
   the switcher's copies for drift.

## Add a bar widget or plugin

Omarchy loads plugins from `~/.config/omarchy/plugins/` and registers them
from `~/.config/omarchy/shell.json`.

- **Bar widgets** are enabled by appearing in `bar.layout`. Add the widget
  ID there; nothing in `plugins[]` is needed.
- **Non-widget plugins** (panels, services) load by default and are disabled
  by being listed in `disabledPlugins[]`.
- Third-party plugins are enabled only if their id appears somewhere in
  `shell.json`.

`overrides/omarchy/omarchy.sh` owns the `shell.json` key writes. Add the new
entry there rather than hand-editing the file.

## Update a theme's default background

The default background is the first file in sorted order. To pin one:

1. Name it with a `00-` prefix: `00-default.webp`. Digits sort ahead of
   letters in both C and UTF-8 collation.
2. Or drop a copy in `~/.config/omarchy/backgrounds/<theme>/` — that
   directory sorts before the theme's own `backgrounds/`.

After renaming, run `omarchy theme set <name>` to publish.

## Edit a Hyprland config file

User files load **after** the theme's `hyprland.lua`, so the user files win.
Our overrides live in:
- `~/.config/hypr/looknfeel.lua`
- `~/.config/hypr/bindings.lua`
- `~/.config/hypr/input.lua`
- `~/.config/hypr/autostart.lua`

These are managed through `sync_fenced` blocks by `apply.sh`. Edit the fenced
blocks in `overrides/hypr/` and re-run `apply.sh hypr`.

A bare `hyprctl reload` does **not** update a running shell's Quickshell
state. Use `omarchy-restart-shell` or `omarchy theme set` for that.

## Add or change a Chromium policy

Policies go in `/etc/chromium/policies/managed/*.json`, installed by
`overrides/chromium/chromium.sh` with `sudo install`. The step is last in
`apply.sh` because it needs sudo.

Policies are live-reloaded by `chromium --refresh-platform-policy` without a
browser restart. `omarchy-theme-set-browser` already calls this on every theme
set.

## Verify icon alignment between repos

Both this repo and the switcher submodule carry the same 100 marks. They can
silently drift.

```bash
for f in overrides/icons/*/*.svg; do
  cmp -s "$f" "omarchy-cllpse-plugin-switcher/icons/$(basename "$f")" \
    || echo "DRIFTED: $(basename "$f")"
done
```

Silence means agreement. If a mark drifts, the plugin's copy is the one
fitted to the `viewBox` contract; copy it back here.

## Working in a submodule (general)

Treat the submodule directory as a separate repo with its own `.git/`:
- `git submodule update --init --recursive` after clone or pull.
- `git diff` inside the submodule shows changes against its own HEAD.
- `git status` in the parent shows `-dirty` if the submodule has uncommitted
  changes, or a diff if the pointer changed.
- Never `git add -A` in the parent when untracked work sits in a submodule.

