-- Mouse/input tuning for cllpse-macos.
-- Appended to ~/.config/hypr/input.lua by overrides/apply.sh.
--
-- sensitivity -1.00 is Hyprland's own scale (-1 slowest, 1 fastest), not a
-- multiplier. accel_profile "adaptive" keeps pointer acceleration on.
--
-- follow_mouse = 2 detaches *pointer* focus from *keyboard* focus: the window
-- under the cursor receives motion, hover and scroll events, while the typing
-- focus (and therefore the active border and the focused window's opacity)
-- only moves on a click. That is macOS behaviour -- scroll wheel acts on
-- whatever is under the pointer without raising or focusing it -- and it is
-- the reason this is 2 rather than 0. It was 0 for a while, which is click-to-
-- focus in the strict sense: pointer focus never leaves the focused window, so
-- scrolling over an unfocused window did nothing at all.
--
-- Not 1 (that is plain focus-follows-mouse, which moves keyboard focus on
-- hover) and not 3 (which detaches the same way as 2 but stops a click from
-- moving keyboard focus too, leaving no way to focus by mouse).
--
-- Verified live: with follow_mouse = 2, warping the cursor over Chromium and
-- then over a different Ghostty left `hyprctl activewindow` on the originally
-- focused window both times.
--
-- mouse_refocus = false stops the pointer re-taking focus when a window closes
-- under it -- it is documented as a follow_mouse = 1 modifier, so it is inert
-- here, but harmless and kept for the day this changes. Both pair with
-- `cursor { no_warps = true }` in hyprland-env.lua.
--
-- scroll_factor is the top-level (mouse-wheel) multiplier -- a separate knob
-- from touchpad.scroll_factor, which only affects the trackpad and isn't set
-- here (so it stays on Omarchy's stock 0.4). 1.5 = 150% of the base speed.
hl.config({
  input = {
    sensitivity = -1.00,
    accel_profile = "adaptive",
    follow_mouse = 2,
    natural_scroll = false,
    touchpad = {
      natural_scroll = false,
    },
    left_handed = false,
    scroll_factor = 1.5,
    mouse_refocus = false,
  },
})
