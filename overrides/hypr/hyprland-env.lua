-- Session-level Hyprland settings for cllpse-macos.
-- Appended to ~/.config/hypr/hyprland.lua by overrides/apply.sh, which puts this
-- block at the END of the file -- after `require("default.hypr.toggles")`. That
-- position matters for the keyboard layout below.
-- hl.env reaches Hyprland's own children from the next reload (checked
-- 2026-10-23: a child exec'd after `hyprctl reload` saw a new variable), which
-- covers the Omarchy shell. The systemd user environment, which apps launched
-- through uwsm inherit, is only set at session start: relogin/reboot for those.

-- Omarchy shell popups (menu, launcher, polkit, emoji, clipboard) draw in this
-- family instead of the monospace alias -- see Style.qml menuFontFamily. The bar
-- itself has no such override and stays on `monospace`. cllpse-macos wants the
-- proportional macOS UI face here (BUILD.md section 4).
hl.env("OMARCHY_MENU_FONT", "SFProText Nerd Font Propo")

-- Qt Quick draws text as distance fields by default: unhinted and a touch soft.
-- This makes every Text use native FreeType glyphs instead, so the bar, the
-- Omarchy menus, the switcher and the supermenu take fontconfig's hinting,
-- which for SF is the autohinter (fontconfig/conf.d/99-cllpse-macos-autohint.conf).
-- Chosen by eye 2026-10-23 from a Qt Quick render of the plugins' text. Text
-- under a scale transform blurs in native mode; the shell has a few (the
-- slider's 1.15x hover, the monitor and speed-test panels). The shell inherits
-- this from Hyprland: omarchy-launch-shell runs from autostart, and
-- omarchy-restart-shell relaunches it through hl.dsp.exec_cmd.
hl.env("QML_DISABLE_DISTANCEFIELD", "1")

-- Cursor theme (Bibata Modern Ice). Xcursor only; Hyprland falls back from
-- hyprcursor to Xcursor automatically since no hyprcursor variant is installed.
-- Needs the bibata-cursor-theme package -- apply.sh warns if it is missing
-- rather than installing it (no sudo).
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
-- 24, Omarchy's own size (default/hypr/envs.lua sets the size and no theme),
-- since 2026-10-16; 22 before. Restated rather than dropped so that this and
-- gsettings cursor-size, which apply.sh set to 22 until then and sets to match,
-- move together. Read by clients at LAUNCH, so a change here reaches an app
-- only when it next starts -- gsettings is the half that GTK apps pick up live.
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
