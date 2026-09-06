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
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Never warp the pointer to a window on focus changes -- the window switcher,
-- workspace switches, focuswindow dispatches. Keeps the cursor where it was,
-- matching follow_mouse = 0 / mouse_refocus = false in the input block.
hl.config({ cursor = { no_warps = true } })

-- The Preonic emits plain US keycodes in firmware (key overrides on the
-- board itself, not an xkb translation), so this stays a single us-based
-- group -- no secondary layout, no alt+shift toggle, nothing Omarchy's own
-- default keyboard behaviour has to fight with. The one addition is
-- us-danish-letters (installed by apply.sh to ~/.config/xkb/symbols/), a
-- static layer adding ae/oe/aa + uppercase on six otherwise-unused function
-- keys, which the Preonic's M0 layer reaches via shift-qualified taps -- see
-- that file for why. No dk(mac), no toggle, no compose, no host-side macro.
hl.config({
  input = {
    kb_layout = "us-danish-letters",
  },
})
