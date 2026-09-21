# starship

starship has no Omarchy-aware theming and no config import, so its colours are baked from colors.toml on every theme-set.

The script is [`starship.sh`](starship.sh). It is runnable on its own and is also
called by [`../apply.sh`](../apply.sh), which owns the order. Numbered
sections below match the `# See README.md (n)` pointers in that script.

## 1. say "starship -> ~/.config/omarchy/hooks/theme-set.d/starship-colors.s

Starship has no Omarchy-aware theming of its own and no config "import"
mechanism to point at a themed file the way Ghostty/Alacritty/foot do, so
instead of a themed/*.tpl this hooks into `omarchy-hook theme-set`
(~/.config/omarchy/hooks/theme-set.d/), called on every `omarchy theme set`
— see the hook script itself for why. Backed up like bat/lazygit/lsd above
since it replaces the user's ~/.config/starship.toml outright; run once now
so the currently active theme's colour reaches it without waiting for the
next theme switch.
