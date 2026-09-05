-- Session-level Hyprland settings for cllpse-macos.
-- Appended to ~/.config/hypr/hyprland.lua by overrides/apply.sh, which puts this
-- block at the END of the file -- after `require("default.hypr.toggles")`. That
-- position matters for the keyboard layout below.
-- hl.env only applies at Hyprland start, so relogin/reboot for the env vars.

-- Omarchy shell popups (menu, launcher, polkit, emoji, clipboard) draw in this
-- family instead of the monospace alias -- see Style.qml menuFontFamily. The bar
-- itself has no such override and stays on `monospace`. cllpse-macos wants the
-- proportional macOS UI face here (BUILD.md section 4).
hl.env("OMARCHY_MENU_FONT", "SFProText Nerd Font Propo")

-- Cursor theme (Bibata Modern Ice). Xcursor only; Hyprland falls back from
-- hyprcursor to Xcursor automatically since no hyprcursor variant is installed.
-- Needs the bibata-cursor-theme package -- apply.sh warns if it is missing
-- rather than installing it (no sudo).
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "22")
hl.env("HYPRCURSOR_SIZE", "22")

-- Never warp the pointer to a window on focus changes -- the window switcher,
-- workspace switches, focuswindow dispatches. Keeps the cursor where it was,
-- matching follow_mouse = 0 / mouse_refocus = false in the input block.
hl.config({ cursor = { no_warps = true } })

-- Keyboard layout: Danish, "mac" variant.
--
-- This has to live here rather than in hypr/input.lua because hyprland.lua
-- requires default.hypr.toggles AFTER hypr.input, so a layout set in input.lua
-- loses to any toggle plugin that writes one. On this machine that is
-- nomarkoo.keyboard-layout, whose state file
-- (~/.local/state/omarchy/toggles/hypr/) sets exactly these values -- so where
-- both are present they agree and the plugin simply wins. The point of keeping
-- it here is the same as the animation block in looknfeel-decoration.lua: the
-- theme should be self-sufficient on a machine with no such plugin installed.
--
-- Obviously regional. Anyone not on a Danish keyboard wants this line gone.
hl.config({
  input = {
    kb_layout = "dk",
    kb_variant = "mac",
    kb_options = "compose:caps,shift:both_capslock_cancel,grp:alt_shift_toggle",
  },
})
