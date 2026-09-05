import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// A macOS-style window switcher rendered as a horizontal strip.
//
// Purely visual, keyboard-driven HUD (panel kind, no keyboard grab, fully
// click-through). All control comes from Hyprland keybinds that summon this
// plugin with a small JSON payload:
//
//   SUPER + TAB          -> summon ... '{"action":"next"}'
//   SUPER + SHIFT + TAB  -> summon ... '{"action":"prev"}'
//   SUPER (on release)   -> summon ... '{"action":"commit"}'
//
// omarchy-shell calls open(payload) on every summon, even while the panel is
// already mounted (keepLoaded), so each keypress lands here as an open() call.
Item {
  id: root

  // Injected by omarchy-shell's panel loader.
  property var shell: null
  property var manifest: null

  property bool opened: false
  property int index: 0
  property var wins: []
  // next/prev presses that land before the first window list has loaded, summed
  // (+1 next, -1 prev). Applied as the starting offset once the list is in, so
  // a quick double-tap during that ~10ms window isn't lost.
  property int pendingSteps: 0
  // Set when "commit" arrives while the first window list is still loading (a
  // very fast tap-and-release). Applied the moment the list is in.
  property bool pendingCommit: false
  // Cursor position when the strip opened. Hover only starts steering the
  // highlight once the pointer has actually moved from here, so opening the
  // strip under a resting cursor doesn't yank the selection off index 1.
  property var hoverBase: null

  // "commit" (sent the instant SUPER is released) is the only thing that
  // switches focus. This timer is a last-resort safety net: if that never
  // arrives (e.g. the Lua key poll died), dismiss the strip WITHOUT switching
  // after this long with no next/prev activity, so a stuck HUD can't linger.
  readonly property int idleTimeoutMs: 30000

  readonly property string pluginId: (manifest && manifest.id) || "io.eject.window-switcher"

  function open(payloadJson) {
    var action = "next"
    try {
      var p = JSON.parse(payloadJson || "{}")
      if (p && p.action) action = String(p.action)
    } catch (e) {}

    if (action === "commit") {
      // If the opening list is still loading, remember to commit once it's in.
      if (!root.opened && clientsProc.running) { root.pendingCommit = true; return }
      root.commit()
      return
    }

    if (action !== "next" && action !== "prev") return
    var step = (action === "prev") ? -1 : 1

    if (!root.opened) {
      root.pendingSteps += step
      if (!clientsProc.running) {
        root.pendingCommit = false
        clientsProc.running = true
      }
      return
    }

    var n = root.wins.length
    if (n === 0) { root.dismiss(); return }
    root.index = ((root.index + step) % n + n) % n
    idleTimer.restart()
  }

  // Called by omarchy-shell when it hides the panel.
  function close() {
    root.opened = false
    idleTimer.stop()
  }

  function dismiss() {
    root.opened = false
    root.pendingSteps = 0
    root.pendingCommit = false
    root.hoverBase = null
    idleTimer.stop()
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide(root.pluginId)
  }

  function commit() {
    idleTimer.stop()
    if (root.opened && root.index >= 0 && root.index < root.wins.length) {
      var addr = root.wins[root.index].address
      if (addr) {
        focusProc.command = ["hyprctl", "dispatch",
          "hl.dsp.focus({ window = \"address:" + addr + "\" })"]
        focusProc.running = true
      }
    }
    root.dismiss()
  }

  // Nerd Font FontAwesome codepoints, built from hex so the Private-Use-Area
  // glyphs survive any editor. JetBrainsMono Nerd Font (the menu font) has them.
  function glyphFor(cls) {
    var c = String(cls || "").toLowerCase()
    function has() {
      for (var i = 0; i < arguments.length; i++)
        if (c.indexOf(arguments[i]) !== -1) return true
      return false
    }
    var g = 0xf108 // desktop (generic fallback)
    if (has("ghostty", "alacritty", "kitty", "foot", "wezterm", "xterm", "konsole", "terminal")) g = 0xf120
    else if (has("firefox", "librewolf", "floorp", "zen-browser", "zen_browser", "waterfox")) g = 0xf269
    else if (has("chromium", "chrome", "vivaldi", "brave", "edge", "opera")) g = 0xf268
    else if (has("code", "cursor", "sublime", "jetbrains", "idea", "pycharm", "webstorm", "zed", "vim", "emacs")) g = 0xf121
    else if (has("steam")) g = 0xf1b6
    else if (has("spotify")) g = 0xf001 // music
    else if (has("vlc", "mpv", "celluloid")) g = 0xf008 // film
    else if (has("gimp", "inkscape", "krita")) g = 0xf03e // image
    else if (has("thunderbird")) g = 0xf0e0 // envelope
    else if (has("discord", "slack", "telegram", "signal", "beeper")) g = 0xf086 // comments
    else if (has("nautilus", "thunar", "pcmanfm", "dolphin", "nemo", "files")) g = 0xf07b // folder
    return String.fromCharCode(g)
  }

  Process {
    id: clientsProc
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      id: clientsOut
      waitForEnd: true
      onStreamFinished: root._loadClients(String(text || "[]"))
    }
  }

  Process { id: focusProc }

  function _loadClients(jsonText) {
    var list = []
    try { list = JSON.parse(jsonText) } catch (e) { list = [] }
    if (!Array.isArray(list)) list = []

    var mapped = []
    for (var i = 0; i < list.length; i++) {
      var w = list[i]
      if (!w || w.mapped !== true) continue
      if (!w.workspace || (w.workspace.id | 0) <= 0) continue // skip special / scratchpad
      if (String(w.class || "").toLowerCase() === "org.omarchy.agent") continue // the Omarchy agent terminal (this plugin's own dev window)
      mapped.push(w)
    }
    // Order of appearance: workspace first (ascending id, matching the bar),
    // then left-to-right / top-to-bottom position within that workspace --
    // not MRU. focusHistoryID is only consulted below, to find where the
    // currently focused window landed in this new order.
    mapped.sort(function (a, b) {
      var wa = (a.workspace && a.workspace.id) | 0
      var wb = (b.workspace && b.workspace.id) | 0
      if (wa !== wb) return wa - wb
      var ax = (a.at && a.at[0]) | 0, bx = (b.at && b.at[0]) | 0
      if (ax !== bx) return ax - bx
      var ay = (a.at && a.at[1]) | 0, by = (b.at && b.at[1]) | 0
      return ay - by
    })

    var out = []
    var currentIdx = 0
    for (var j = 0; j < mapped.length; j++) {
      var m = mapped[j]
      if ((m.focusHistoryID | 0) === 0) currentIdx = j
      var t = (m.title && m.title !== "") ? m.title
        : (m.initialTitle && m.initialTitle !== "") ? m.initialTitle
        : "(untitled)"
      out.push({
        address: m.address,
        title: t,
        cls: m.class || m.initialClass || "",
        ws: (m.workspace && m.workspace.name) || ""
      })
    }

    root.wins = out
    if (out.length < 2) { // nothing to switch to
      root.opened = false
      root.pendingSteps = 0
      root.pendingCommit = false
      return
    }

    var n = out.length
    // Start from wherever the currently focused window landed in workspace/
    // position order (not necessarily 0 anymore); the presses so far step
    // off it.
    root.index = ((currentIdx + root.pendingSteps) % n + n) % n
    root.pendingSteps = 0
    root.hoverBase = null
    root.opened = true
    idleTimer.restart()

    // A commit that raced ahead of this load: apply it now.
    if (root.pendingCommit) { root.pendingCommit = false; root.commit() }
  }

  // --- Pointer hover ----------------------------------------------------------
  //
  // The strip is a click-through layer surface, so it gets no Qt hover events.
  // Instead, while it's open, poll the global cursor position and hit-test it
  // against the cells. Moving the pointer over a cell makes it the highlight;
  // releasing SUPER then focuses it, same as with the keyboard.
  Timer {
    id: pollTimer
    running: root.opened
    interval: 40
    repeat: true
    onTriggered: cursorProc.running = true
  }

  Process {
    id: cursorProc
    command: ["hyprctl", "cursorpos", "-j"]
    stdout: StdioCollector {
      id: cursorOut
      waitForEnd: true
      onStreamFinished: {
        try {
          var p = JSON.parse(String(cursorOut.text || "{}"))
          if (typeof p.x === "number" && typeof p.y === "number") root._hover(p.x, p.y)
        } catch (e) {}
      }
    }
  }

  function _hover(cx, cy) {
    if (!root.opened || root.wins.length < 2) return
    if (root.hoverBase === null) { root.hoverBase = { x: cx, y: cy }; return }
    if (Math.abs(cx - root.hoverBase.x) + Math.abs(cy - root.hoverBase.y) < 8) return

    // ListView rect in global (monitor) coordinates. The surface fills the
    // monitor, so surface-local == monitor-local; add the monitor origin.
    var ox = panel.screen ? panel.screen.x : 0
    var oy = panel.screen ? panel.screen.y : 0
    var gx = ox + card.x + list.x
    var gy = oy + card.y + list.y
    if (cy < gy || cy > gy + list.height) return

    var lx = cx - gx + list.contentX
    if (lx < 0) return
    var stride = card.cellW + card.gap
    var idx = Math.floor(lx / stride)
    if (idx < 0 || idx >= root.wins.length) return
    if (lx - idx * stride > card.cellW) return // pointer is in the gap
    root.index = idx
  }

  Timer {
    id: idleTimer
    interval: root.idleTimeoutMs
    repeat: false
    onTriggered: root.dismiss() // safety only — never switches focus
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-window-switcher-hud"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    // Visual only: empty input region, so the strip never intercepts a click.
    mask: Region {}

    // Same dim as the Omarchy menu (Color.menu.scrim = theme bg at ~0.5).
    Rectangle {
      anchors.fill: parent
      color: Color.menu.scrim
    }

    // Card: same chrome as an Omarchy menu — theme menu background, the
    // themed menu border spec, panel padding, shared corner radius.
    BorderSurface {
      id: card
      x: Math.round((parent.width - width) / 2)
      y: Math.round((parent.height - height) / 2)

      readonly property int cellW: Style.space(212)
      readonly property int gap: Style.spacing.xs
      readonly property int rowH: Style.space(104)
      // The window icon runs 1.5x the Omarchy menu's row icon.
      readonly property int iconSize: Math.round(Style.font.iconLarge * 1.5)
      readonly property int stripW: root.wins.length > 0
        ? root.wins.length * cellW + (root.wins.length - 1) * gap
        : 0

      color: Color.menu.background
      radius: Style.cornerRadius
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
      padding: Style.spacing.panelPadding

      width: Math.min(parent.width - Style.gapsOut * 2,
                      card.contentLeftInset + card.contentRightInset + stripW)
      height: card.contentTopInset + card.contentBottomInset + rowH

      ListView {
        id: list
        x: card.contentLeftInset
        y: card.contentTopInset
        width: Math.min(card.width - card.contentLeftInset - card.contentRightInset, card.stripW)
        height: card.rowH
        orientation: ListView.Horizontal
        spacing: card.gap
        interactive: false
        clip: true
        model: root.wins
        currentIndex: root.index
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        // Styled after an Omarchy menu row: selected gets
        // Color.menu.selectedBackground + selectedText, radius = cornerRadius,
        // label in heading/Medium. The icon (card.iconSize) and the workspace
        // line (subtitle, dimmed) both run a step larger than the menu's.
        delegate: Rectangle {
          id: cell
          width: card.cellW
          height: list.height
          radius: Style.cornerRadius
          readonly property bool sel: index === root.index
          color: sel ? Color.menu.selectedBackground : "transparent"

          Column {
            anchors.centerIn: parent
            width: parent.width - Style.space(16)
            spacing: Style.space(3)

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.glyphFor(modelData.cls)
              textFormat: Text.PlainText
              font.family: Style.font.menuFamily
              font.pixelSize: card.iconSize
              color: cell.sel ? Color.menu.selectedText : Color.menu.text
            }
            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: modelData.title
              textFormat: Text.PlainText
              elide: Text.ElideRight
              maximumLineCount: 1
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.heading
              font.weight: Font.Medium
              color: cell.sel ? Color.menu.selectedText : Color.menu.text
            }
            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: "Workspace " + modelData.ws
              textFormat: Text.PlainText
              elide: Text.ElideRight
              maximumLineCount: 1
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.subtitle
              color: Color.menu.text
              opacity: 0.52
            }
          }
        }
      }
    }
  }
}
