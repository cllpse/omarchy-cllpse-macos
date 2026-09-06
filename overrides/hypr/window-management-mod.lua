-- Window navigation/arrangement moved off SUPER onto CTRL+ALT.
--
-- The Preonic firmware's key overrides for symbol input (see
-- preonic-rev3_drop/keymap.c: Gui+Up=/, Shift+Gui+Up=?, Gui+Backspace=+)
-- suppress the Super modifier on the keys they trigger on, which meant
-- SUPER+UP and SUPER+SHIFT+UP stopped reaching Hyprland as window
-- focus/swap at all -- the keyboard was consuming the whole chord to type a
-- character instead of ever letting "Super held + Up" reach the compositor.
--
-- Rather than patch around whichever specific Super+key combos the keyboard
-- happens to touch today, the whole "navigate/arrange windows" group below
-- moved to CTRL+ALT: no key override in keymap.c ever uses Ctrl as a
-- trigger modifier (every override's negative mask blocks Ctrl outright),
-- so this is permanently collision-proof regardless of what the keyboard
-- does with Super/Shift/Alt in the future. Mouse-button window move/resize
-- (SUPER + mouse:272/273) stayed on Super -- mouse buttons were never
-- something the keyboard could intercept, so there was nothing to fix
-- there.
--
-- The corresponding keybind-allowlist.conf lines were commented out so
-- apply.sh's unbind diff removes the old SUPER chords; the dispatchers
-- below are copied verbatim from Omarchy's tiling.lua so behavior is
-- unchanged, only the modifier moved.
o.bind("CTRL + ALT + J", "Toggle window split", hl.dsp.layout("togglesplit"))
o.bind("CTRL + ALT + L", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")

o.bind("CTRL + ALT + UP", "Focus on above window", hl.dsp.focus({ direction = "u" }))
o.bind("CTRL + ALT + DOWN", "Focus on below window", hl.dsp.focus({ direction = "d" }))
o.bind("CTRL + ALT + SHIFT + UP", "Swap window up", hl.dsp.window.swap({ direction = "u" }))
o.bind("CTRL + ALT + SHIFT + DOWN", "Swap window down", hl.dsp.window.swap({ direction = "d" }))

-- Focus/swap-left/right have no home on Super at all right now -- SUPER+LEFT/
-- RIGHT and SUPER+SHIFT+LEFT/RIGHT were already given up to macos-shortcuts.lua's
-- Cmd-style line start/end before any of this CTRL+ALT work started. CTRL+ALT
-- doesn't collide with that, so these get the same parity as UP/DOWN above.
o.bind("CTRL + ALT + LEFT", "Focus on left window", hl.dsp.focus({ direction = "l" }))
o.bind("CTRL + ALT + RIGHT", "Focus on right window", hl.dsp.focus({ direction = "r" }))
o.bind("CTRL + ALT + SHIFT + LEFT", "Swap window to the left", hl.dsp.window.swap({ direction = "l" }))
o.bind("CTRL + ALT + SHIFT + RIGHT", "Swap window to the right", hl.dsp.window.swap({ direction = "r" }))

for workspace = 1, 10 do
  local key = "code:" .. tostring(workspace + 9)
  o.bind("CTRL + ALT + " .. key, "Switch to workspace " .. workspace, hl.dsp.focus({ workspace = tostring(workspace) }))
  o.bind("CTRL + ALT + SHIFT + " .. key, "Move window to workspace " .. workspace, hl.dsp.window.move({ workspace = tostring(workspace) }))
end

-- Resize, restored from Omarchy's stock (previously-unbound) big resize
-- step, but on the arrow keys instead of the original code:20/code:21 pair,
-- and Gui instead of a bare Ctrl -- mod+arrow is already focus and
-- mod+Shift+arrow is already swap, and mod+Ctrl+arrow can't exist as a
-- distinct chord since Ctrl is already part of mod itself (WM_MOD holds it
-- internally -- see keymap.c). Gui is the one modifier not already spoken
-- for on these keys. Right/down grow, left/up shrink -- matches which way
-- the arrow points.
o.bind("CTRL + ALT + SUPER + RIGHT", "Grow window width", hl.dsp.window.resize({ x = 300,  y = 0,    relative = true }))
o.bind("CTRL + ALT + SUPER + LEFT",  "Shrink window width", hl.dsp.window.resize({ x = -300, y = 0,    relative = true }))
o.bind("CTRL + ALT + SUPER + DOWN",  "Grow window height", hl.dsp.window.resize({ x = 0,    y = 300,  relative = true }))
o.bind("CTRL + ALT + SUPER + UP",    "Shrink window height", hl.dsp.window.resize({ x = 0,    y = -300, relative = true }))
