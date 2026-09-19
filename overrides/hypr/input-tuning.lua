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
-- scroll_factor is the top-level (mouse-wheel) multiplier; touchpad.scroll_factor
-- is a separate knob that only affects the trackpad. They move in opposite
-- directions here on purpose: 1.5 (150%) on the wheel, because a notched wheel
-- moves in coarse discrete steps and Omarchy's base felt short of a line's worth
-- per notch -- 1.35 undershot, 1.45 was lived with for a while and still read
-- as short, and 1.5 is where it settled; 0.35 on
-- the trackpad, below Omarchy's stock 0.4, because a
-- continuous two-finger surface wants the opposite -- macOS trackpad scrolling
-- is slow and precise per unit of finger travel, and it is the momentum fling,
-- not the gain, that covers distance.
--
-- emulate_discrete_scroll is Hyprland's own words: "Emulates discrete scrolling
-- from high resolution scrolling events." Its map is disable=0, non_standard=1
-- (the default), force_all=2, so stock manufactures notches out of a device's
-- fine-grained stream. 0 is the only lever in the whole compositor that points
-- towards smooth scrolling -- there is no smooth-scroll option; the complete
-- scroll surface is scroll_points, scroll_method, scroll_button,
-- scroll_button_lock, scroll_factor, natural_scroll, this, and the touchpad
-- pair, and none of the others animate anything.
--
-- The hardware half is already there: /proc/bus/input/devices reports
-- REL=1943 for the Pulsar 8K, and bits 11 and 12 of that mask are
-- REL_WHEEL_HI_RES and REL_HWHEEL_HI_RES. In libinput's v120 API one detent is
-- 120 units and high-res events fire 4-8x more often than clicks.
--
-- Tempered expectation, recorded so it is not re-derived: the Pulsar ALSO
-- emits genuine discrete REL_WHEEL (bit 8), and this option reads as though it
-- is aimed at devices that only send high-res. It may well change nothing.
-- What it cannot do is make anything worse that a single edit does not undo.
--
-- Set here rather than left at stock: it was 0.4 for a while, and this value
-- arrived via the OmaSettings GUI, which writes ~/.config/hypr/omasettings.lua
-- and requires it from the *end* of hyprland.lua -- i.e. after this file. See
-- the settings-plugin trap in CLAUDE.md: while that file exists it wins over
-- anything here, so folding a value in means deleting its line there too.
hl.config({
  input = {
    sensitivity = -1.00,
    accel_profile = "adaptive",
    follow_mouse = 2,
    natural_scroll = false,
    touchpad = {
      natural_scroll = false,
      scroll_factor = 0.35,
    },
    left_handed = false,
    scroll_factor = 1.5,
    emulate_discrete_scroll = 0,
    mouse_refocus = false,
  },
})
