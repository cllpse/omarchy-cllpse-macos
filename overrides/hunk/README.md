# hunk

hunk — the one tool here that cannot use the terminal palette (its validator
takes hex only, and every built-in theme is a bundled Shiki theme), so its
colours are BAKED from the active colors.toml on every theme-set, the same
hook mechanism [`../starship/`](../starship/README.md) uses. The hook writes config.toml whole, which
is why it is backed up once before the first run.

Script: [`hunk.sh`](hunk.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
