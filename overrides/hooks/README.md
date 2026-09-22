# Hooks

The post-update repair hook — re-link what an `omarchy update` could quietly take out.

Everything this script installs lives either in directories that are ours
alone (~/.icons/, ~/.local/, ~/.config/hypr/) or as symlinks inside
directories Omarchy ships and manages (~/.config/omarchy/{hooks,themes,
plugins}/). The first group no Omarchy command touches. The second is exposed:
Omarchy ships its own content into those paths — config/omarchy/hooks/
theme-set.d/ carries .sample files — so a refresh, a migration, or a future
install step that repopulates one of them takes our symlink with it, silently.
The icons would simply revert to vendor logos at the next theme change with
nothing to say why.

omarchy-update calls `omarchy-hook post-update` (omarchy-update:49), so a hook
dropped here re-links everything once per update at no scheduling cost. It is
idempotent, so it runs unconditionally rather than trying to detect damage.

## What it re-links

"Everything" is a claim that drifts -- this hook re-linked five of the seven
theme-set hooks for a while, so gh-dash and ytm-player silently stopped
tracking the theme after an update while the other five healed themselves.
The set is therefore written out rather than described:

| link | installed by |
|---|---|
| `theme-set.d/app-icons.sh` | `icons/icons.sh` |
| `theme-set.d/starship-colors.sh` | `starship/starship.sh` |
| `theme-set.d/hunk-colors.sh` | `hunk/hunk.sh` |
| `theme-set.d/yazi-syntax.sh` | `yazi/yazi.sh` |
| `theme-set.d/cursor-chrome.sh` | `cursor/cursor.sh` |
| `theme-set.d/gh-dash-colors.sh` | `gh-dash/gh-dash.sh` |
| `theme-set.d/ytm-player.sh` | `ytm/ytm.sh` |
| `themed/ytm-player.toml.tpl` | `ytm/ytm.sh` — the only link outside `theme-set.d/`, which is why it was one of the three this hook was missing |
| `post-update.d/cllpse-macos-repair.sh` | itself |
| `themes/omarchy-cllpse-theme-{dark,light}` | `apply.sh` |
| `plugins/cllpse.window-switcher` | `apply.sh` |

The first eight are also enumerated by `revert.sh`, which removes them. Three
lists, one set, nothing enforcing it — `CLAUDE.md`'s *Three lists have to
agree about the theme-set hooks* carries the one-liner that compares them;
run it after adding an app.

## From the step table

Post-update repair hook. Everything `apply.sh` installs is either in a
directory that is ours alone (`~/.icons/`, `~/.local/`, `~/.config/hypr/`) or
a **symlink inside a directory Omarchy ships and manages**
(`~/.config/omarchy/{hooks,themes,plugins}/` — Omarchy's own
`config/omarchy/hooks/theme-set.d/` carries `.sample` files, so those paths
are its territory). The second group is exposed: a refresh, migration or
future install step that repopulates one of them takes our symlink with it and
nothing reports the loss — icons would just revert to vendor logos at the next
theme change. `omarchy-update` calls `omarchy-hook post-update`
(`omarchy-update:49`), so a hook there re-links all of it once per update.
Idempotent, so it runs unconditionally rather than trying to detect damage.
Deliberately does **not** repair `shell.json` — that file is personal, and
rewriting it from a hook mid-update is a worse failure than the one it
prevents

Script: [`hooks.sh`](hooks.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
