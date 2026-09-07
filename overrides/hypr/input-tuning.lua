-- Mouse/input tuning for cllpse-macos.
-- Appended to ~/.config/hypr/input.lua by overrides/apply.sh.
--
-- sensitivity -1.00 is Hyprland's own scale (-1 slowest, 1 fastest), not a
-- multiplier. accel_profile "adaptive" keeps pointer acceleration on.
-- follow_mouse = 0 means focus only changes on click, and mouse_refocus = false
-- stops the pointer re-taking focus when a window closes under it -- together
-- they pair with `cursor { no_warps = true }` in hyprland-env.lua.
--
-- scroll_factor is the top-level (mouse-wheel) multiplier -- a separate knob
-- from touchpad.scroll_factor, which only affects the trackpad and isn't set
-- here (so it stays on Omarchy's stock 0.4). 1.5 = 150% of the base speed.
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
    scroll_factor = 1.5,
    mouse_refocus = false,
  },
})
