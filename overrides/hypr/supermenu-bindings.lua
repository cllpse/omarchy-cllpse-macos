-- Supermenu plugin (cllpse.supermenu): SUPER + SPACE opens a Raycast-style
-- launcher over every app and every Omarchy menu entry, ranked by what you
-- actually pick -- macOS's Cmd+Space, where Omarchy put its own menu.
--
-- Delivered over Hyprland's global-shortcuts protocol, NOT by summoning the
-- plugin over IPC. The IPC path (`omarchy-shell shell toggle ...`) is bash ->
-- timeout -> `qs ipc`, and `qs ipc` starts a whole Quickshell binary to deliver
-- one message: 31-35ms per call here, with spikes to 130-166ms (measured for
-- the window switcher, which is why it moved to this channel first).
-- hl.dsp.global() hands the event straight to the plugin's GlobalShortcut
-- (registered in Supermenu.qml, appid "cllpse-supermenu"): no fork, no exec,
-- no Qt startup. Measured end to end, a dispatched toggle has the card on
-- screen in under 20ms including the hyprctl that sent it. Keystrokes are held
-- ~1ms after the shortcut reaches the shell and replayed into the field once the
-- card has the keyboard (20-35ms at 120Hz) -- since supermenu 1.1.0; before it,
-- keys typed in that gap went to the window you were in. The plugin README has
-- the measurements.
--
-- Omarchy's own menu is not removed, only moved off this chord: `omarchy menu`
-- and every script that uses it as a picker prompt still open it. It has no
-- other chord here -- its SUPER + ALT + SPACE is one keybind-allowlist.conf
-- already prunes, and Flea's now (flea/flea-bindings.lua) -- and needs none:
-- every entry it holds is in the supermenu.
-- If the shell is not running the dispatch is a no-op, which is the same
-- outcome the old IPC toggle had.
--
-- Not reachable while Figma is focused, like every SUPER chord the figma:C keyd
-- layer does not carve out -- see the note in macos-shortcuts.lua. TAB and Q are
-- the layer's carve-outs; SPACE is not one, so in Figma this does nothing.
hl.unbind("SUPER + SPACE")
o.bind("SUPER + SPACE", "Supermenu", function()
  hl.dispatch(hl.dsp.global("cllpse-supermenu:toggle"))
end)
