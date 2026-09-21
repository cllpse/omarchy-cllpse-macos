# hunk

hunk — the one tool here that cannot use the terminal palette (its validator
takes hex only, and every built-in theme is a bundled Shiki theme), so its
colours are BAKED from the active colors.toml on every theme-set, the same
hook mechanism [`../starship/`](../starship/README.md) uses. The hook writes config.toml whole, which
is why it is backed up once before the first run.

Script: [`hunk.sh`](hunk.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.

## Why the palette is baked

Alongside it, `hunk-colors.sh` bakes the same palette into
`~/.config/hunk/config.toml` — hunk is the one tool here that cannot name ANSI
slots (hex-only validator, Shiki-only built-ins), so its diff backgrounds are
blended over the theme background at 18%/30% and its Shiki `base` follows the
`mode` key
