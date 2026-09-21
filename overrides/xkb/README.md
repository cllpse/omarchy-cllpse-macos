# xkb

A static, single-group symbols file putting the Danish letters on the Preonic's M0 layer. Referenced by hypr/hyprland-env.lua's kb_layout.

The script is [`xkb.sh`](xkb.sh). It is runnable on its own and is also
called by [`../apply.sh`](../apply.sh), which owns the order. Numbered
sections below match the `# See README.md (n)` pointers in that script.

## 1. say "xkb: installing us-danish-letters -> ~/.config/xkb/symbols/"

Static, single-group symbols file (no toggle, no compose) - see the file
itself for why level 1 on these keys is dead weight. Referenced by
hyprland-env.lua's kb_layout below.

## From the step table

Danish letters on the Preonic's M0 layer — a static, single-group xkb symbols file with no toggle and no compose. Referenced by `hyprland-env.lua`'s `kb_layout`, which is why step 6's block wins over a layout set in the user files
