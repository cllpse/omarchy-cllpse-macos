-- Window Switcher HUD plugin (cllpse.window-switcher): a macOS-style
-- horizontal strip. Hold SUPER, tap TAB / SHIFT+TAB to move the highlight; the
-- instant SUPER is no longer held the highlighted window is focused and the
-- strip disappears. No timers, no delay.
--
-- Rather than trust a key-release keybind to fire, a lightweight poll asks the
-- compositor "is SUPER still physically down?" every 30ms while the strip is up
-- (hl.is_key_down is a cheap in-process check). The strip is on screen for
-- exactly as long as that stays true.
-- Delivered over Hyprland's global-shortcuts protocol, NOT by summoning the
-- plugin over IPC.
--
-- The IPC path (`omarchy-shell shell summon ...`) is bash -> timeout -> `qs
-- ipc`, and `qs ipc` starts a whole Quickshell binary to deliver one message.
-- Measured on this machine: 31-35ms per call, with spikes to 130-166ms -- paid
-- on EVERY TAB press, which is exactly what made the switcher feel sluggish.
--
-- hl.dsp.global() hands the event straight to the plugin's GlobalShortcut
-- (registered in Hud.qml, appid "cllpse-switcher"): no fork, no exec, no Qt
-- startup. It is a dispatcher like any other, so the key-release poll below can
-- fire `commit` through the same channel rather than shelling out.
--
-- If the plugin is not running the dispatch is simply a no-op, which is the
-- same outcome the old summon had.
local function ws_exec(action)
  hl.dispatch(hl.dsp.global("cllpse-switcher:" .. action))
end

local ws_watching = false

-- While the strip is up, SUPER + left-click belongs to the HUD.
--
-- Hyprland resolves mouse BINDS before handing a button to a layer surface, so
-- with "Move window" bound to SUPER + mouse:272 the HUD's input region never
-- sees the press at all -- verified on this machine: the press started a window
-- drag (default/hypr/bindings/tiling.lua:70) and the tile was never hit. A mask
-- does not change that; the bind is resolved first.
--
-- That used to be worked around by making the bind itself know about the strip
-- and dispatch a "click" into the plugin. It could not go further: a bind
-- reports a press and nothing else, and a DRAG needs press, motion and release.
--
-- So the bind stands down for exactly as long as the strip is on screen. With
-- nothing matching, the compositor forwards the button to the surface under the
-- cursor -- the HUD -- and the plugin gets ordinary Qt press / move / release
-- events, doing click-to-focus and drag-to-workspace itself.
--
-- hl.bind returns the keybind and set_enabled toggles it in place, so this
-- unbinds and rebinds nothing per gesture. Resize (mouse:273) is left alone.
hl.unbind("SUPER + mouse:272")
local ws_drag_bind = hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), {
  mouse = true,
  description = "Move window",
})

local function ws_hud_takes_clicks(taking)
  ws_drag_bind:set_enabled(not taking)
end

-- Which physical modifier the strip is actually being held open by.
--
-- Normally that is SUPER. But while Figma has focus, keyd has rewritten
-- leftmeta to the `figma:C` layer (see overrides/keyd/default.conf), so the
-- compositor never sees Super held at ALL -- it sees Control. The layer's
-- `tab = M-tab` carve-out emits a clean Meta+Tab for the TAB press itself and
-- restores Control the instant it is over, which is exactly enough for the
-- SUPER + TAB bind to match and nowhere near enough to hold a strip open.
-- Polling Super_L there would find it up on the very first tick and commit
-- 30ms after the first tap, collapsing the switcher to a plain "focus the next
-- window" -- so in that mode the question has to be asked about Control.
local ws_ctrl_mode = false

local function ws_figma_focused()
  local window = hl.get_active_window()

  if not window or not window.class then
    return false
  end

  return window.class:match("[Ff]igma") ~= nil
end

-- Both, not either-or, and deliberately so. keyd has to drop Control to emit
-- an unmodified Meta+Tab and put it back afterwards, so there is a sub-
-- millisecond window per tap in which Control is up -- and Meta is down for
-- precisely that window. Asking about both means no 30ms tick can ever land in
-- the gap and read the chord as released mid-cycle.
local function ws_mod_held()
  if ws_ctrl_mode then
    return hl.is_key_down("Control_L") or hl.is_key_down("Control_R")
        or hl.is_key_down("Super_L") or hl.is_key_down("Super_R")
  end

  return hl.is_key_down("Super_L") or hl.is_key_down("Super_R")
end

local function ws_watch()
  if not ws_watching then return end
  if ws_mod_held() then
    hl.timer(ws_watch, { timeout = 30, type = "oneshot" })
  else
    ws_watching = false
    ws_hud_takes_clicks(false)
    ws_exec("commit") -- SUPER let go -> focus the highlighted window
  end
end

local function ws_step(action)
  return function()
    ws_exec(action)
    if not ws_watching then
      -- Sampled once, as the strip opens, rather than per tick. The HUD is a
      -- layer surface and never takes focus, so Figma stays the active window
      -- for as long as the strip is up and this answer stays true -- and
      -- sampling it later would race the commit, which changes focus.
      ws_ctrl_mode = ws_figma_focused()
      ws_watching = true
      ws_hud_takes_clicks(true)
      hl.timer(ws_watch, { timeout = 30, type = "oneshot" })
    end
  end
end

hl.unbind("SUPER + TAB")
hl.unbind("SUPER + SHIFT + TAB")
o.bind("SUPER + TAB", "Window switcher: next", ws_step("next"))
o.bind("SUPER + SHIFT + TAB", "Window switcher: previous", ws_step("prev"))
