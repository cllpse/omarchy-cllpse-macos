# Hyprland

Four fenced snippets appended to the user's own hypr config, plus the keybind allowlist that decides which of Omarchy's stock binds survive.

## 1. keybind-scan.lua sandboxes the live ~/.config/hypr/hyprland.lua

keybind-scan.lua sandboxes the live ~/.config/hypr/hyprland.lua (dofile'd
under a fake hl/o -- no interaction with the running Hyprland session, see
the script itself) to enumerate every bind currently in effect: Omarchy
defaults, the active theme, and the overrides just synced above.

Two files, two lifecycles:
  keybind-current.conf    regenerated from that scan on EVERY apply --
                           reference only, never hand-edit, diff it against
                           the allowlist below to see what Omarchy
                           added/changed
  keybind-allowlist.conf  seeded from -current once, then yours -- delete
                           a line to have the next apply unbind it;
                           apply.sh never rewrites it again once it exists.
                           It is TRACKED IN GIT and therefore already exists
                           in a fresh clone, so the seeding never runs there
                           and a second machine is diffed against the
                           author's bind set rather than its own. Delete it
                           and re-apply to seed from this machine instead;
                           the file's own header covers the consequences.

## 2. Note this ALWAYS fires on a fresh clone

Note this ALWAYS fires on a fresh clone: the allowlist is tracked in git,
so it exists before the first apply and the seeding branch below is
unreachable until someone deletes it. That means a second machine is
diffed against the author's bind set, not its own — see the file's header.

## 3. macOS-parity shortcuts

macOS-parity shortcuts. Must be synced AFTER keybind-unbinds.lua above:
some of these repurpose a combo (SUPER+LEFT/RIGHT, SUPER+SHIFT+LEFT/RIGHT)
that the allowlist diff just unbound from its old WM meaning -- these
bindings need to be the last word for that combo, not the unbind.

## 4. Window navigation/arrangement on CTRL+ALT instead of SUPER

Window navigation/arrangement on CTRL+ALT instead of SUPER -- see the
header comment in window-management-mod.lua for why (the Preonic
keyboard's Gui-triggered symbol overrides were eating SUPER+UP/SHIFT+UP
before Hyprland ever saw them). Also synced after keybind-unbinds.lua,
same reasoning as macos-shortcuts.lua above, though these don't actually
share a chord with anything being unbound.

## From the step table

`OMARCHY_MENU_FONT` + cursor theme + `no_warps` + keyboard layout
(`hyprland.lua`), window-switcher keybinds (`bindings.lua`), mouse tuning
(`input.lua`), and the presentation-popup width rule (`looknfeel.lua`).

**The decoration moved out.** Rounding, `rounding_power`, borders, gaps, blur,
window opacity, the shell-surface `layer_rule`s and every animation now live in
each theme's own `hyprland.lua`, which Omarchy loads from the active theme —
see [`../../README.md`](../../README.md) for the theme-folder table. The
popup-width rule stayed because it has to load *after* Omarchy's own float
sizing to win, and a theme loads earlier (`omarchy.lua` requires the theme at
line 22, its window rules at 19).

The consequence is intended: the macOS decoration is now scoped to these
themes. Switch to a stock Omarchy theme and rounding returns to 0.

## From the step table

Keybind allowlist + macOS-parity shortcuts. `keybind-scan.lua` sandboxes the
live `hyprland.lua` (fake `hl`/`o`, no live Hyprland IPC) to enumerate every
bind in effect; `keybind-allowlist.conf` seeds from that scan once and is
yours from then on — delete a line to have the next apply unbind it;
`keybind-unbinds.lua` is regenerated from the current allowlist on every
apply, so an Omarchy update that adds new default binds gets pruned too,
without reseeding. `macos-shortcuts.lua` (word/line navigation,
close/undo/redo/save, quit — synthesized via `send_key_state`, guarded off
inside terminals where forwarding Ctrl+Z/W/S would be destructive) and
`window-management-mod.lua` (window nav/arrangement moved `SUPER` →
`CTRL+ALT`, working around the Preonic firmware's key overrides suppressing
`SUPER` on the keys they trigger on) are synced in *after* the unbinds, so
their own binds land fresh every run

Script: [`hypr.sh`](hypr.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
