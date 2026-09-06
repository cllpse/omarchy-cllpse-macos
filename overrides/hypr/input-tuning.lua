-- Mouse/input tuning for cllpse-macos.
-- Appended to ~/.config/hypr/input.lua by overrides/apply.sh.
--
-- CAUTION: the Omaland settings plugin (bobbynicholas.omaland, not part of this
-- repo) owns its own `[[ OMARCHY_MOUSE_SETTINGS_START ]]` block in this same
-- file and rewrites it whenever its Settings panel is opened. This block is
-- appended after that one, so it wins on file position -- but if Omaland
-- regenerates its block below ours, Omaland's values take over. Same accepted
-- tradeoff as the animation leaves in looknfeel-decoration.lua: this exists to
-- make the setup self-sufficient without Omaland, not to fight it where both
-- are installed.
--
-- sensitivity -1.00 is Hyprland's own scale (-1 slowest, 1 fastest), not a
-- multiplier. accel_profile "adaptive" keeps pointer acceleration on.
-- follow_mouse = 0 means focus only changes on click, and mouse_refocus = false
-- stops the pointer re-taking focus when a window closes under it -- together
-- they pair with `cursor { no_warps = true }` in hyprland-env.lua.
--
-- scroll_factor is the top-level (mouse-wheel) multiplier -- a separate knob
-- from touchpad.scroll_factor, which only affects the trackpad and isn't set
-- here (so it stays on Omarchy's stock 0.4). 1.25 = 125% of the base speed.
hl.config({
  input = {
    sensitivity = -1.00,
    accel_profile = "adaptive",
    follow_mouse = 0,
    natural_scroll = false,
    touchpad = {
      natural_scroll = false,
    },
    left_handed = false,
    scroll_factor = 1.25,
    mouse_refocus = false,
  },
})
