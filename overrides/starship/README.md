# starship

Starship has no Omarchy-aware theming of its own and no config "import"
mechanism to point at a themed file the way Ghostty/Alacritty/foot do, so
instead of a themed/*.tpl this hooks into `omarchy-hook theme-set`
(~/.config/omarchy/hooks/theme-set.d/), called on every `omarchy theme set`
— see the hook script itself for why. Backed up like bat/lazygit/lsd
since it replaces the user's ~/.config/starship.toml outright; run once now
so the currently active theme's colour reaches it without waiting for the
next theme switch.

Script: [`starship.sh`](starship.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.

## Why a theme-set hook

Starship prompt colours track the active theme's `accent` (the same hue
driving Hyprland's active border) — Starship has no Omarchy-aware theming and
no config-import mechanism like Ghostty/Alacritty/foot, so this hooks into
`omarchy-hook theme-set` instead of a `themed/*.tpl`; regenerates
`~/.config/starship.toml` on every theme switch, and once now so it doesn't
wait for the next one. The template also swaps the built-in `git_branch` for a
`custom.git_branch` that truncates in the middle
(`chromium-scale-and-ghostty-fixes` → `chromium-sc…hostty-fixes`, 24 chars
incl. the ellipsis) — Starship only truncates from the head
