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

## From the step table

Post-update repair hook. Everything `apply.sh` installs is either in a directory that is ours alone (`~/.icons/`, `~/.local/`, `~/.config/hypr/`) or a **symlink inside a directory Omarchy ships and manages** (`~/.config/omarchy/{hooks,themes,plugins}/` — Omarchy's own `config/omarchy/hooks/theme-set.d/` carries `.sample` files, so those paths are its territory). The second group is exposed: a refresh, migration or future install step that repopulates one of them takes our symlink with it and nothing reports the loss — icons would just revert to vendor logos at the next theme change. `omarchy-update` calls `omarchy-hook post-update` (`omarchy-update:49`), so a hook there re-links all of it once per update. Idempotent, so it runs unconditionally rather than trying to detect damage. Deliberately does **not** repair `shell.json` — that file is personal, and rewriting it from a hook mid-update is a worse failure than the one it prevents

Script: [`hooks.sh`](hooks.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
