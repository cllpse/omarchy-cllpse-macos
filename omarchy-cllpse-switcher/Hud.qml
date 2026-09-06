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

  // Friendly app name for the class, shown ahead of the window title as
  // "App Name (title)". Same class-matching idiom as glyphFor, so the two
  // stay in step. Falls back to title-casing the raw class (last segment of
  // a reverse-DNS style class, e.g. "org.gnome.Nautilus") for anything not
  // listed here, rather than leaving the tile unlabelled.
  function nameFor(cls) {
    var c = String(cls || "").toLowerCase()
    function has() {
      for (var i = 0; i < arguments.length; i++)
        if (c.indexOf(arguments[i]) !== -1) return true
      return false
    }
    if (has("ghostty")) return "Ghostty"
    else if (has("alacritty")) return "Alacritty"
    else if (has("kitty")) return "Kitty"
    else if (has("foot")) return "Foot"
    else if (has("wezterm")) return "WezTerm"
    else if (has("xterm")) return "XTerm"
    else if (has("konsole")) return "Konsole"
    else if (has("firefox")) return "Firefox"
    else if (has("librewolf")) return "LibreWolf"
    else if (has("floorp")) return "Floorp"
    else if (has("zen-browser", "zen_browser")) return "Zen"
    else if (has("waterfox")) return "Waterfox"
    else if (has("chromium")) return "Chromium"
    else if (has("chrome")) return "Chrome"
    else if (has("vivaldi")) return "Vivaldi"
    else if (has("brave")) return "Brave"
    else if (has("edge")) return "Edge"
    else if (has("opera")) return "Opera"
    else if (has("cursor")) return "Cursor"
    else if (has("code")) return "VS Code"
    else if (has("sublime")) return "Sublime Text"
    else if (has("jetbrains", "idea")) return "IntelliJ IDEA"
    else if (has("pycharm")) return "PyCharm"
    else if (has("webstorm")) return "WebStorm"
    else if (has("zed")) return "Zed"
    else if (has("vim")) return "Vim"
    else if (has("emacs")) return "Emacs"
    else if (has("steam")) return "Steam"
    else if (has("spotify")) return "Spotify"
    else if (has("vlc")) return "VLC"
    else if (has("mpv")) return "mpv"
    else if (has("celluloid")) return "Celluloid"
    else if (has("gimp")) return "GIMP"
    else if (has("inkscape")) return "Inkscape"
    else if (has("krita")) return "Krita"
    else if (has("thunderbird")) return "Thunderbird"
    else if (has("discord")) return "Discord"
    else if (has("slack")) return "Slack"
    else if (has("telegram")) return "Telegram"
    else if (has("signal")) return "Signal"
    else if (has("beeper")) return "Beeper"
    else if (has("nautilus", "files")) return "Files"
    else if (has("thunar")) return "Thunar"
    else if (has("pcmanfm")) return "PCManFM"
    else if (has("dolphin")) return "Dolphin"
    else if (has("nemo")) return "Nemo"

    var seg = String(cls || "").split(".").pop().replace(/[-_]+/g, " ").trim()
    if (!seg) return ""
    return seg.replace(/\w\S*/g, function (w) {
      return w.charAt(0).toUpperCase() + w.slice(1)
    })
  }

  // Window titles come from arbitrary apps and sometimes carry icon glyphs,
  // emoji or other symbols that don't exist in the menu font and render as
  // tofu boxes. Rather than a Unicode-range regex (whose \p{} property
  // escapes aren't reliably supported by every JS engine build), this is a
  // plain character whitelist checked by String.indexOf -- easy to read and
  // to extend with one more character.
  readonly property string titleWhitelist:
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789æøåÆØÅ" +
    " ,.-:()&'!?"

  function sanitizeTitle(s) {
    var str = String(s || "")
    var out = ""
    for (var i = 0; i < str.length; i++) {
      var ch = str.charAt(i)
      if (root.titleWhitelist.indexOf(ch) !== -1) out += ch
    }
    return out.trim()
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
        ws: String((m.workspace && m.workspace.name) || "").trim()
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
    if (Math.abs(cx - root.hoverBase.x) + Math.abs(cy - root.hoverBase.y) < Style.space(8)) return

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

    // Scrim at the launcher's 0.35 rather than binding Color.menu.scrim (0.25):
    // a switcher wants a touch more separation from the desktop than a menu.
    //
    // Composed here rather than read from the theme because Omarchy 4 has no
    // launcher surface to read. Color.qml exposes bar, popups, tooltip,
    // notifications, menu, polkit, lock and imagePicker -- no launcher -- and
    // nothing in the shell reads `launcher.*` keys at all. What Omarchy calls
    // the launcher is the menu plugin, on Color.menu.*, so the [launcher]
    // section a theme ships is spliced into shell.toml and then ignored. 0.35 is
    // that section's intended value, applied here directly.
    //
    // Built from the live palette background so it still follows theme switches,
    // and kept below the layer rule's ignore_alpha (0.6) in
    // overrides/hypr/looknfeel-decoration.lua so the scrim stays unblurred --
    // the windows being switched between remain readable, while the card above
    // keeps its frost.
    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.35)
    }

    // Card: same chrome as an Omarchy menu — theme menu background, the
    // themed menu border spec, panel padding, shared corner radius.
    BorderSurface {
      id: card
      x: Math.round((parent.width - width) / 2)
      y: Math.round((parent.height - height) / 2)

      readonly property int cellW: Style.space(212)
      readonly property int gap: Style.spacing.xs
      // Same shape as Menu.qml's baseRowHeight/detailRowHeight: a floor, raised
      // if the stacked contents need more. Keeps the cell honest when
      // `omarchy display text size` grows the font tokens.
      readonly property int rowH: Math.max(
        Style.space(104),
        card.iconSize + Style.font.heading + Style.font.title
          + Style.space(3) * 2 + Style.spacing.rowPaddingX * 2)
      // In the menu the icon sits inline beside a label (Style.font.iconLarge);
      // here it's the primary element of a card, so it steps up the type scale
      // to `display` -- the way a macOS Cmd-Tab tile leads with its icon.
      //
      // A token rather than a multiple of iconLarge on purpose. iconLarge is
      // already rounded (fontPx = round(baseSize * mult)), so scaling it rounds
      // a second time and lands on arbitrary sizes that drift with base-size.
      // display is a clean 2.0 rem: exact at every base-size, and ~1.33x
      // iconLarge, which is where the hand-tuned multiplier was heading anyway.
      readonly property int iconSize: Style.font.display
      // Matches the menu's cursor-row border (Menu.qml selectedBorderSpec), so
      // the theme's [menu] selected-border / selected-border-alpha reach the
      // HUD instead of being silently dropped.
      readonly property var selectedBorderSpec:
        Border.surfaceSpec("menu", "selected-border", Color.menu.selectedBorder, 0)
      readonly property int stripW: root.wins.length > 0
        ? root.wins.length * cellW + (root.wins.length - 1) * gap
        : 0
      // Overflow scrim width: the card's own left/right padding (so the
      // fade starts right at the card edge, not inset from it) plus
      // two-thirds of a cell -- enough that a cell sitting right at the edge
      // is fully inside the scrim's opaque run, not just brushed by its
      // fade tail.
      readonly property int scrimW: Math.min(
        card.contentLeftInset + card.cellW * 2 / 3, list.width / 2)

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

        // Styled after an Omarchy menu row (Menu.qml's row delegate): a
        // BorderSurface whose selected state gets Color.menu.selectedBackground
        // + selectedText + the selected-border spec, radius = cornerRadius,
        // label in heading/Medium and the secondary line in title at 0.52
        // (bumped two token steps up from the menu's own bodySmall).
        // Only the icon deliberately departs -- see card.iconSize.
        delegate: BorderSurface {
          id: cell
          width: card.cellW
          height: list.height
          radius: Style.cornerRadius
          readonly property bool sel: index === root.index
          color: sel ? Color.menu.selectedBackground : "transparent"
          borderSpec: sel ? card.selectedBorderSpec : Border.none()

          Column {
            anchors.centerIn: parent
            width: parent.width - Style.spacing.rowPaddingX * 2
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
              text: root.nameFor(modelData.cls) || root.sanitizeTitle(modelData.title)
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
              text: modelData.ws + " – " + root.sanitizeTitle(modelData.title)
              textFormat: Text.PlainText
              elide: Text.ElideRight
              maximumLineCount: 1
              font.family: Style.font.menuFamily
              // Two token steps up from the menu's secondary/detail line
              // (bodySmall) -- still opacity 0.52, just title instead.
              font.pixelSize: Style.font.title
              color: Color.menu.text
              opacity: 0.52
            }
          }
        }
      }

      // Overflow scrims, same idiom as the SUPER+SPACE menu's scroll scrims
      // (Menu.qml) -- just rotated to this strip's horizontal axis instead of
      // the menu's vertical one. Strength tracks how much content is still
      // hidden past each edge rather than a fixed on/off, so it reads
      // correctly the instant the strip opens already scrolled (e.g.
      // currentIdx landed mid-list) with no animation to catch up.
      Rectangle {
        x: list.x
        y: list.y
        height: list.height
        width: card.scrimW
        visible: opacity > 0
        opacity: list.contentWidth > list.width
          ? Math.max(0, Math.min(1, (list.contentX - list.originX) / width))
          : 0
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0; color: Color.menu.background }
          GradientStop { position: 1; color: Util.alpha(Color.menu.background, 0) }
        }
      }

      Rectangle {
        x: list.x + list.width - width
        y: list.y
        height: list.height
        width: card.scrimW
        visible: opacity > 0
        opacity: list.contentWidth > list.width
          ? Math.max(0, Math.min(1, (list.originX + list.contentWidth - list.width - list.contentX) / width))
          : 0
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0; color: Util.alpha(Color.menu.background, 0) }
          GradientStop { position: 1; color: Color.menu.background }
        }
      }
    }
  }
}
