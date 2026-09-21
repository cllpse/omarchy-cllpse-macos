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
