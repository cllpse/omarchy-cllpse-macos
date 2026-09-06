-- macOS-parity keyboard shortcuts, built the same way clipboard.lua's
-- "universal copy/paste/cut" already works: intercept the Cmd-style chord
-- globally and synthesize the real keystroke the focused app already
-- understands, rather than trying to teach every app a new one.
--
-- Real macOS splits word-level navigation from line/document-level: Option
-- (Alt) is the word-level modifier, Cmd (Super) is the line/document one.
-- Implemented as that true split rather than putting everything on Alt:
--   ALT + LEFT/RIGHT             word jump            (Ctrl+Left/Right)
--   ALT + SHIFT + LEFT/RIGHT     select word           (Ctrl+Shift+Left/Right)
--   SUPER + LEFT/RIGHT           line start/end        (Home/End)
--   SUPER + SHIFT + LEFT/RIGHT   select to start/end   (Shift+Home/Shift+End)
-- The last two repurpose window-focus-left/right and swap-window-left/right
-- (see keybind-allowlist.conf) -- Cmd took over the line/document role
-- here, and there was no other free slot for those WM actions once it did.
--
-- Word jump / line start-end are never guarded against terminals: Ctrl+
-- Left/Right and Home/End are already the native readline bindings there,
-- same as real macOS Terminal.app.
--
-- Close/undo/redo/save (below) ARE guarded: Ctrl+Z is SIGTSTP in a shell
-- (suspends the foreground job), Ctrl+S is XOFF (freezes terminal output),
-- Ctrl+W deletes the word being typed. Forwarding any of those into a
-- terminal would be actively harmful, so those four do nothing there
-- rather than risk it. Quit is not part of that group -- see its own note
-- further down, it uses a different mechanism entirely.

-- Down/up split (rather than Hyprland's built-in sendshortcut) works around
-- send_shortcut sometimes leaving synthetic key state stuck/repeating --
-- see the same note in clipboard.lua and
-- https://github.com/hyprwm/Hyprland/discussions/14099
local function send_shortcut_once(mods, key)
  return function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))

    hl.timer(function()
      hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
  end
end

-- Duplicated from clipboard.lua rather than shared: each require'd file is
-- its own Lua chunk, so a `local` there isn't visible here.
local function active_window_is_terminal()
  local window = hl.get_active_window()
  if not window then
    return false
  end

  for _, tag in ipairs(window.tags or {}) do
    if tag:gsub("%*$", "") == "terminal" then
      return true
    end
  end

  return false
end

local function unless_terminal(mods, key)
  return function()
    if not active_window_is_terminal() then
      send_shortcut_once(mods, key)()
    end
  end
end

-- Word / line navigation -- safe everywhere, terminals included.
o.bind("ALT + LEFT", "Word jump left (Option+Left)", send_shortcut_once("CTRL", "Left"))
o.bind("ALT + RIGHT", "Word jump right (Option+Right)", send_shortcut_once("CTRL", "Right"))
o.bind("ALT + SHIFT + LEFT", "Select word left (Option+Shift+Left)", send_shortcut_once("CTRL SHIFT", "Left"))
o.bind("ALT + SHIFT + RIGHT", "Select word right (Option+Shift+Right)", send_shortcut_once("CTRL SHIFT", "Right"))

o.bind("SUPER + LEFT", "Line start (Cmd+Left)", send_shortcut_once("", "Home"))
o.bind("SUPER + RIGHT", "Line end (Cmd+Right)", send_shortcut_once("", "End"))
o.bind("SUPER + SHIFT + LEFT", "Select to line start (Cmd+Shift+Left)", send_shortcut_once("SHIFT", "Home"))
o.bind("SUPER + SHIFT + RIGHT", "Select to line end (Cmd+Shift+Right)", send_shortcut_once("SHIFT", "End"))

-- Close/undo/redo/save -- terminal-guarded, see the note above.
o.bind("SUPER + W", "Universal close (Cmd+W)", unless_terminal("CTRL", "W"))
o.bind("SUPER + Z", "Undo (Cmd+Z)", unless_terminal("CTRL", "Z"))
o.bind("SUPER + SHIFT + Z", "Redo (Cmd+Shift+Z)", unless_terminal("CTRL SHIFT", "Z"))
o.bind("SUPER + S", "Save (Cmd+S)", unless_terminal("CTRL", "S"))

-- App shortcuts for Chrome (new tab/reload/new window/print or Quick Open/
-- command palette) -- safe everywhere, no terminal guard needed: none of
-- Ctrl+T (transpose-chars), Ctrl+R (reverse-isearch), Ctrl+N (next-history),
-- Ctrl+P (previous-history) or Ctrl+Shift+P are destructive readline
-- bindings the way Ctrl+Z/W/S are, so there's nothing to protect against.
-- These started as keyboard firmware key overrides, then moved here to
-- match how Z/W/S/Q already work: Hyprland can see the focused app and
-- could add per-app handling later (e.g. the Ctrl+P print-vs-Quick-Open
-- mismatch between a browser and Cursor/VSCode) -- firmware never can.
o.bind("SUPER + T", "New tab (Cmd+T)", send_shortcut_once("CTRL", "T"))
o.bind("SUPER + R", "Reload (Cmd+R)", send_shortcut_once("CTRL", "R"))
o.bind("SUPER + N", "New window (Cmd+N)", send_shortcut_once("CTRL", "N"))
o.bind("SUPER + P", "Print / Quick Open (Cmd+P)", send_shortcut_once("CTRL", "P"))
o.bind("SUPER + SHIFT + P", "Command palette (Cmd+Shift+P)", send_shortcut_once("CTRL SHIFT", "P"))

-- Quit (Cmd+Q). NOT a synthesized Ctrl+Q -- most Linux apps (Chrome, Cursor)
-- don't bind it at all, so it silently did nothing. window.kill() was the
-- other candidate but is a hard kill: confirmed live (killed a focused
-- Figma window in under a second) that it gives the app no chance to
-- intercept and prompt "save changes?" -- unacceptable given how much of
-- this workflow lives in terminals that would die instantly and silently.
-- window.close() sends the same polite close request as clicking the
-- window's own close button, which is what apps actually listen for to
-- show that prompt. No terminal guard needed: this is the same graceful
-- request already used elsewhere, not one of the harmful control
-- characters send_shortcut_once forwards for the others above.
-- Tradeoff: only closes the current window, not every window of the app --
-- there's no WM-level "quit this whole application" for a multi-window app.
o.bind("SUPER + Q", "Quit (Cmd+Q, graceful close)", hl.dsp.window.close())
