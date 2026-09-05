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

-- No forced keyboard layout here anymore: the Preonic now emits plain US
-- keycodes in firmware (key overrides on the board itself, not an xkb
-- translation), so the host should just run Omarchy's own us default instead
-- of overriding it to dk(mac). nomarkoo.keyboard-layout's own toggle state
-- still lists dk(mac) as a secondary layout, reachable via alt+shift.
