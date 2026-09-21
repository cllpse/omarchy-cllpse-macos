# hunk

hunk's validator takes hex only and every built-in theme is a bundled Shiki theme, so its colours are baked per theme-set.

The script is [`hunk.sh`](hunk.sh). It is runnable on its own and is also
called by [`../apply.sh`](../apply.sh), which owns the order. Numbered
sections below match the `# See README.md (n)` pointers in that script.

## 1. if command -v hunk >/dev/null 2>&1; then

hunk — the one tool here that cannot use the terminal palette (its validator
takes hex only, and every built-in theme is a bundled Shiki theme), so its
colours are BAKED from the active colors.toml on every theme-set, the same
hook mechanism starship uses above. The hook writes config.toml whole, which
is why it is backed up once before the first run.
