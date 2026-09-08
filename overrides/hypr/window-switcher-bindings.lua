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

local function ws_super_held()
  return hl.is_key_down("Super_L") or hl.is_key_down("Super_R")
end

local function ws_watch()
  if not ws_watching then return end
  if ws_super_held() then
    hl.timer(ws_watch, { timeout = 30, type = "oneshot" })
  else
    ws_watching = false
    ws_exec("commit") -- SUPER let go -> focus the highlighted window
  end
end

local function ws_step(action)
  return function()
    ws_exec(action)
    if not ws_watching then
      ws_watching = true
      hl.timer(ws_watch, { timeout = 30, type = "oneshot" })
    end
  end
end

hl.unbind("SUPER + TAB")
hl.unbind("SUPER + SHIFT + TAB")
o.bind("SUPER + TAB", "Window switcher: next", ws_step("next"))
o.bind("SUPER + SHIFT + TAB", "Window switcher: previous", ws_step("prev"))

-- Click a tile to focus it.
--
-- This cannot be done in the plugin. Hyprland resolves mouse BINDS before
-- handing the button to a layer surface, so the HUD's own input region never
-- sees the press -- verified on this machine: SUPER + left-click over the card
-- started a window drag (SUPER + mouse:272 is Omarchy's "Move window",
-- default/hypr/bindings/tiling.lua:70) and the tile was never hit. Giving the
-- surface a mask does not change that; the bind wins first.
--
-- So the bind itself has to know about the strip. While it is up, SUPER +
-- left-click commits instead of dragging; otherwise it drags exactly as stock.
-- The HUD's own hover handler has already moved the highlight to whatever tile
-- the cursor is over, so committing focuses the tile that was clicked.
--
-- ws_watching is the same flag the key-release poll uses, so this is true for
-- precisely as long as the strip is on screen.
hl.unbind("SUPER + mouse:272")
o.bind("SUPER + mouse:272", "Window switcher: focus tile, else move window", function()
  if ws_watching then
    ws_exec("commit")
  else
    -- Built per press rather than cached at load: a dispatcher value held
    -- across invocations is one more thing that has to be re-entrant, and the
    -- stock bind (tiling.lua:70) constructs it at bind time for a single use.
    hl.dispatch(hl.dsp.window.drag())
  end
end, { mouse = true })
