# bash

fzf, lsd colours and the tool aliases, fenced into ~/.bashrc.

Script: [`bash.sh`](bash.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.

## The aliases

tool aliases (`edit` → msedit, `diff` → `hunk diff` — a live-reloading
working-tree review with the files pane open (both from
`hunk/config.toml.tpl`, not flags), which shadows `/usr/bin/diff` in
interactive shells, `log` → `hunk log` — the commit browser that pairs with
it, shadowing nothing, `dash` → `gh dash`) plus the `ytm` function (which
fixes yt-dlp's keyring backend, not just the name), each guarded on its tool
the way the `ls` → `lsd` alias is — `gh-dash` is a gh *extension* rather than
a binary, so its guard tests the extension directory instead of shelling out
to `gh extension list` (34ms, on every interactive shell)
