-- Window Switcher HUD plugin (cllpse.window-switcher): a macOS-style
-- horizontal strip. Hold SUPER, tap TAB / SHIFT+TAB to move the highlight; the
-- instant SUPER is no longer held the highlighted window is focused and the
-- strip disappears. No timers, no delay.
--
-- Rather than trust a key-release keybind to fire, a lightweight poll asks the
-- compositor "is SUPER still physically down?" every 30ms while the strip is up
-- (hl.is_key_down is a cheap in-process check). The strip is on screen for
-- exactly as long as that stays true.
local ws_summon = "omarchy-shell shell summon cllpse.window-switcher "

local function ws_exec(action)
  hl.dispatch(hl.dsp.exec_cmd(ws_summon .. "'{\"action\":\"" .. action .. "\"}'"))
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
