import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
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
  // A first refresh is in flight and nothing is cached yet. Only ever true
  // before the first list lands -- after that the list is kept warm.
  property bool listPending: false

  // ── Most-recently-used, for back-and-forth ──────────────────────────────────
  //
  // A single tap must return to the window you came from, and a second tap must
  // bring you back -- the alternation every Alt+Tab has. That needs the PREVIOUS
  // focus, which nothing on the compositor side keeps in a usable form here:
  // `activated` only ever says what is focused now, and `lastIpcObject`'s
  // focusHistoryID is a stale snapshot (measured: it sat at 2/1/0 across two
  // focus changes). So the history is kept here, updated from the live
  // `Hyprland.activeToplevel`.
  //
  // Deliberately NOT used for ordering. The tiles stay sorted by workspace and
  // on-screen position; this only moves where the highlight STARTS.
  property string activeAddr: ""
  property string prevAddr: ""

  // "commit" (sent the instant SUPER is released) is the only thing that
  // switches focus. This timer is a last-resort safety net: if that never
  // arrives (e.g. the Lua key poll died), dismiss the strip WITHOUT switching
  // after this long with no next/prev activity, so a stuck HUD can't linger.
  readonly property int idleTimeoutMs: 30000

  // ── Input path ──────────────────────────────────────────────────────────────
  //
  // The keybinds reach this plugin through Hyprland's global-shortcuts protocol
  // rather than by summoning it over IPC, because the IPC path costs a process
  // spawn per keypress. `omarchy-shell shell summon` is bash -> timeout -> `qs
  // ipc`, and `qs ipc` starts a whole Quickshell binary to deliver one message:
  // measured at 31-35ms per press on this machine, with spikes to 130-166ms.
  // That is the sluggishness -- it was paid on every single TAB.
  //
  // A GlobalShortcut is registered here and bound in
  // overrides/hypr/window-switcher-bindings.lua with hl.dsp.global(), so the
  // compositor delivers the key straight to this process over the Wayland
  // protocol. No fork, no exec, no Qt startup.
  //
  // `commit` is a shortcut too, for the same reason: hl.dsp.global is a
  // *dispatcher*, so the Lua key-release poll can dispatch it directly instead
  // of shelling out. The appid carries no dots or colons -- Hyprland parses the
  // binding as "<appid>:<name>".
  readonly property string shortcutAppid: "cllpse-switcher"

  GlobalShortcut {
    appid: root.shortcutAppid
    name: "next"
    description: "Window switcher: next"
    onPressed: root.open('{"action":"next"}')
  }

  GlobalShortcut {
    appid: root.shortcutAppid
    name: "prev"
    description: "Window switcher: previous"
    onPressed: root.open('{"action":"prev"}')
  }

  GlobalShortcut {
    appid: root.shortcutAppid
    name: "commit"
    description: "Window switcher: focus the highlighted window"
    onPressed: root.open('{"action":"commit"}')
  }

  readonly property string pluginId: (manifest && manifest.id) || "io.eject.window-switcher"

  function open(payloadJson) {
    var action = "next"
    try {
      var p = JSON.parse(payloadJson || "{}")
      if (p && p.action) action = String(p.action)
    } catch (e) {}

    if (action === "commit") {
      // Only possible before the list is warm -- see the cold path below.
      if (!root.opened && root.listPending) { root.pendingCommit = true; return }
      root.commit()
      return
    }

    if (action !== "next" && action !== "prev") return
    var step = (action === "prev") ? -1 : 1

    if (!root.opened) {
      // Warm path: the list is already in memory, so opening is synchronous --
      // no process to spawn and nothing to wait for. The rebuild below only
      // does real work on the very first summon; after that _rebuild() finds
      // the list unchanged and leaves the model alone.
      if (root.wins.length < 2) root._rebuild()
      if (root.wins.length >= 2) { root._openStepped(step); return }
      // Cold: nothing cached yet (first summon after a shell restart, or a
      // refresh still in flight). Remember the presses and let _rebuild()
      // apply them the moment the list lands, exactly as before.
      root.pendingSteps += step
      if (!root.listPending) {
        root.listPending = true
        root.pendingCommit = false
        Hyprland.refreshToplevels()
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
    root._rebuild() // unfreeze: catch anything that changed while it was up
  }

  function dismiss() {
    root.opened = false
    root.pendingSteps = 0
    root.pendingCommit = false
    idleTimer.stop()
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide(root.pluginId)
    root._rebuild() // unfreeze: catch anything that changed while it was up
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

  readonly property string flatIconDir: Quickshell.env("HOME") + "/.icons/cllpse-flat/apps/"

  // Nerd Font codepoints, built from hex so the Private-Use-Area glyphs survive
  // any editor. These render in Style.font.menuFamily -- SFProText Nerd Font
  // Propo on this machine, via OMARCHY_MENU_FONT -- so every codepoint here is
  // verified against THAT face, not against the monospace one the terminal uses.
  //
  // Keyed on the window class, which is all a switcher has. overrides/icons/
  // icon-map.conf is keyed on a desktop entry's `Icon=` instead, and the two
  // keyspaces genuinely differ: measured on this machine, 6 of the 23 entries
  // declaring StartupWMClass use a class that is not their icon name, and
  // Chromium's is the literal unsubstituted "@@startup_wm_class". So they stay
  // two maps -- but where both cover an app they MUST agree on the codepoint,
  // or the same program wears one mark in the menu and a different one under
  // SUPER+TAB. Every shared entry below matches icon-map.conf.
  //
  // Order is load-bearing in two places: "obsidian" must be tested before
  // "obs" (OBS Studio) because the former contains the latter, and the
  // specific libreoffice-* classes before the bare "libreoffice".
  function glyphFor(cls) {
    var c = String(cls || "").toLowerCase()
    function has() {
      for (var i = 0; i < arguments.length; i++)
        if (c.indexOf(arguments[i]) !== -1) return true
      return false
    }
    var g = 0xf108 // desktop (generic fallback)
    if (has("ghostty", "alacritty", "kitty", "foot", "wezterm", "xterm", "konsole", "terminal")) g = 0xe795
    else if (has("firefox", "librewolf", "floorp", "zen-browser", "zen_browser", "waterfox")) g = 0xf269
    // Helium is a Chromium fork and belongs in the family bucket. The menu
    // shows its own asterisk instead (icon-map.conf @flatten) because an image
    // can carry a mark that no glyph in the font does; a text cell cannot.
    else if (has("chromium", "chrome", "helium", "vivaldi", "brave", "edge", "opera")) g = 0xf268
    else if (has("code", "cursor", "sublime", "jetbrains", "idea", "pycharm", "webstorm", "zed", "vim", "emacs")) g = 0xf121
    else if (has("steam")) g = 0xf1b6
    else if (has("obsidian")) g = 0xf082e                                  // notebook
    else if (has("obs")) g = 0xf03d                                        // video camera
    else if (has("spotify", "cliamp")) g = 0xf001                          // music
    else if (has("vlc", "mpv", "celluloid", "kdenlive")) g = 0xf008        // film
    else if (has("gimp", "inkscape", "krita", "pinta", "figma")) g = 0xf1fc // paint brush
    else if (has("imv", "eog", "loupe", "gwenview")) g = 0xf03e            // image
    else if (has("evince", "papers", "zathura", "okular")) g = 0xf1c1      // pdf
    else if (has("libreoffice-writer")) g = 0xf1c2
    else if (has("libreoffice-calc")) g = 0xf1c3
    else if (has("libreoffice-impress")) g = 0xf1c4
    else if (has("libreoffice-draw")) g = 0xf1fc
    else if (has("libreoffice-base")) g = 0xf1c0
    else if (has("libreoffice-math")) g = 0xf1ec
    else if (has("libreoffice")) g = 0xf0219                               // document
    else if (has("omacalc", "galculator")) g = 0xf1ec                      // calculator
    else if (has("xournal", "omawrite")) g = 0xf040                        // pencil
    else if (has("localsend")) g = 0xf1e0                                  // share
    else if (has("moonlight")) g = 0xf26c                                  // monitor
    else if (has("qv4l2", "qvidcap", "cheese")) g = 0xf030                 // camera
    else if (has("docker")) g = 0xf308
    else if (has("thunderbird")) g = 0xf0e0                                // envelope
    else if (has("discord", "slack", "telegram", "signal", "beeper")) g = 0xf086 // comments
    else if (has("nautilus", "thunar", "pcmanfm", "dolphin", "nemo", "files")) g = 0xf07b // folder
    // fromCodePoint, NOT fromCharCode: the latter is 16-bit and silently
    // truncates anything above U+FFFF, so the Material Design range this map
    // now uses (0xf0219 -> U+219, 0xf082e -> U+82E) would render as unrelated
    // glyphs with no error.
    return String.fromCodePoint(g)
  }

  // A hand-placed icon for this window's app, if one exists.
  //
  // apply.sh syncs overrides/icons/fallbacks/ into ~/.icons/cllpse-flat/apps/,
  // repainted in the theme foreground, for the Omarchy menu -- which cannot
  // render a glyph at all and would otherwise show the vendor's colour logo.
  // Reusing those files here is what lets the switcher show the same mark the
  // SUPER+SPACE menu does for an app whose logo no glyph depicts.
  //
  // Keyed on the window class, because that is all a switcher has, while the
  // dropped file is named for the desktop entry's `Icon=`. Those agree for most
  // apps but not all (measured: 6 of the 23 entries declaring StartupWMClass use
  // a class that is not their icon name). A drop-in whose name differs from the
  // class simply is not found here and the tile keeps its glyph -- drop a second
  // copy named for the class if you want it in both places.
  //
  // Existence is not tested up front: Image reports status Image.Error for a
  // missing file, and the delegate falls back to the glyph on anything that is
  // not Image.Ready. That covers a machine where apply.sh never ran, an empty
  // fallbacks/ directory, and a name mismatch, with no stat() per tile.
  function flatIconBase(cls) {
    var c = String(cls || "").trim()
    return c.length > 0 ? root.flatIconDir + c : ""
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
    else if (has("helium")) return "Helium"
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
    else if (has("obsidian")) return "Obsidian"
    else if (has("obs")) return "OBS Studio"
    else if (has("figma")) return "Figma"
    else if (has("pinta")) return "Pinta"
    else if (has("imv")) return "Image Viewer"
    else if (has("kdenlive")) return "Kdenlive"
    else if (has("evince", "papers")) return "Document Viewer"
    else if (has("zathura")) return "Zathura"
    else if (has("okular")) return "Okular"
    else if (has("libreoffice-writer")) return "LibreOffice Writer"
    else if (has("libreoffice-calc")) return "LibreOffice Calc"
    else if (has("libreoffice-impress")) return "LibreOffice Impress"
    else if (has("libreoffice-draw")) return "LibreOffice Draw"
    else if (has("libreoffice-base")) return "LibreOffice Base"
    else if (has("libreoffice-math")) return "LibreOffice Math"
    else if (has("libreoffice")) return "LibreOffice"
    else if (has("localsend")) return "LocalSend"
    else if (has("moonlight")) return "Moonlight"
    else if (has("xournal")) return "Xournal++"
    else if (has("cliamp")) return "cliamp"
    else if (has("docker")) return "Docker"
    else if (has("qv4l2", "qvidcap")) return "Qt V4L2"
    else if (has("cheese")) return "Cheese"
    else if (has("omacalc")) return "Omacalc"
    else if (has("omawrite")) return "Omawrite"
    else if (has("omacut")) return "Omacut"

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

  Process { id: focusProc }

  // ── Window list ─────────────────────────────────────────────────────────────
  //
  // Kept warm from Hyprland's event socket rather than rebuilt by shelling out
  // to `hyprctl clients -j` on every summon. Two things made that worth doing:
  //
  //  - The old path spawned a process and parsed its JSON on every open. That
  //    turned out NOT to be the visible cost: end-to-end open latency measured
  //    the same (~40ms) before and after, because it is dominated by the
  //    `omarchy-shell shell summon` spawn in the keybind itself. One less
  //    process per keypress is still worth having, but it is not why this
  //    changed.
  //  - It then assigned `root.wins` unconditionally. Measured with a delegate
  //    lifecycle probe, a repeat open rebuilt a list that was byte-identical
  //    (`same=true`) and still reset the ListView, destroying and recreating
  //    cells. A recreated cell's icon Image starts out `Loading`, so the
  //    delegate falls back to its Nerd Font glyph for a frame or two before the
  //    icon pops in -- the flicker.
  //
  // What is live and what is not, measured against this Quickshell build:
  //
  //  - `Hyprland.rawEvent` is live -- openwindow/closewindow/movewindow/... all
  //    arrive on the event socket as they happen.
  //  - `toplevel.activated` is live, and tracks focus with no refresh at all.
  //  - `toplevel.lastIpcObject` is a SNAPSHOT, not live. Its `focusHistoryID`
  //    sat at 2/1/0 across two focus changes. So the ordering fields (`at`,
  //    `class`, `workspace`) need an explicit refreshToplevels(), and the
  //    focused window has to come from `activated`, never focusHistoryID.
  //  - `Hyprland.toplevels` is populated lazily. In a bare Quickshell instance
  //    it is EMPTY until something calls refreshToplevels(); inside the Omarchy
  //    shell it already held 3 entries by the time this plugin's onCompleted
  //    ran. Both are true, which is why the prime below does BOTH: refresh (for
  //    the empty case) and rebuild (for the already-populated case). Relying on
  //    a valuesChanged signal instead deadlocks the already-populated case --
  //    the signal has already been and gone, and the list stays empty forever.
  //    That was a real bug here, not a hypothetical.
  Component.onCompleted: { Hyprland.refreshToplevels(); root._rebuild() }

  // Events that can change the set of windows or their on-screen order. Focus
  // changes are deliberately absent: `activated` already tracks those live, and
  // refreshing on them would rebuild the list on every commit.
  readonly property var refreshEvents: [
    "openwindow", "closewindow", "movewindow", "movewindowv2",
    "windowtitle", "windowtitlev2", "changefloatingmode", "fullscreen",
    "monitoradded", "monitorremoved"
  ]

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (root.refreshEvents.indexOf(String(event.name)) === -1) return
      refreshDebounce.restart()
    }
  }

  // A single window move emits several events in a burst; coalesce them into
  // one refresh rather than one IPC round-trip each.
  Timer {
    id: refreshDebounce
    interval: 24
    repeat: false
    onTriggered: { Hyprland.refreshToplevels(); rebuildAfterRefresh.restart() }
  }

  // refreshToplevels() rewrites each toplevel's lastIpcObject in place. The
  // values array itself is untouched, so valuesChanged does NOT fire and the
  // rebuild has to be scheduled by hand once the IPC round-trip has landed.
  Timer {
    id: rebuildAfterRefresh
    interval: 40
    repeat: false
    onTriggered: root._rebuild()
  }

  Connections {
    target: Hyprland.toplevels
    function onValuesChanged() { root._rebuild() }
  }

  // Focus history. Only shifts when the focused window actually changes, so
  // re-focusing the same window does not lose the window before it -- otherwise
  // committing to where you already are would erase the thing you wanted to go
  // back to.
  Connections {
    target: Hyprland
    function onActiveToplevelChanged() {
      var t = Hyprland.activeToplevel
      var a = t ? root._addr(t.address) : ""
      if (a === "" || a === root.activeAddr) return
      root.prevAddr = root.activeAddr
      root.activeAddr = a
    }
  }

  // Hyprland's own addresses carry an 0x prefix in the IPC object but not on
  // the toplevel handle. Compared raw, nothing ever matches and every open
  // starts from index 0.
  function _addr(a) {
    var t = String(a || "")
    return t.indexOf("0x") === 0 ? t.substring(2) : t
  }

  function _rebuild() {
    // Frozen while the strip is on screen: a macOS Cmd-Tab list does not
    // reshuffle under the hand holding it, and re-assigning the model mid-open
    // is exactly what made the icons flicker.
    if (root.opened) return

    var vs = Hyprland.toplevels.values
    var mapped = []
    for (var i = 0; i < vs.length; i++) {
      var o = vs[i].lastIpcObject
      if (!o || o.mapped !== true) continue
      if (!o.workspace || (o.workspace.id | 0) <= 0) continue // special / scratchpad
      if (String(o["class"] || "").toLowerCase() === "org.omarchy.agent") continue // this plugin's own dev window
      mapped.push(o)
    }

    // Order of appearance: workspace first (ascending id, matching the bar),
    // then left-to-right / top-to-bottom position within that workspace --
    // not MRU. The focused window is found separately, via `activated`.
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
    for (var j = 0; j < mapped.length; j++) {
      var m = mapped[j]
      var t = (m.title && m.title !== "") ? m.title
        : (m.initialTitle && m.initialTitle !== "") ? m.initialTitle
        : "(untitled)"
      out.push({
        address: m.address,
        title: t,
        cls: m["class"] || m.initialClass || "",
        ws: String((m.workspace && m.workspace.name) || "").trim()
      })
    }

    // The whole point: only touch the model when something actually changed.
    // An unchanged assignment resets the ListView and churns delegates.
    if (!root._sameWins(out, root.wins)) root.wins = out

    if (!root.listPending) return
    root.listPending = false

    // Cold-start presses that landed before the list did.
    if (out.length < 2) { // nothing to switch to
      root.pendingSteps = 0
      root.pendingCommit = false
      return
    }
    root._openStepped(root.pendingSteps)
    if (root.pendingCommit) { root.pendingCommit = false; root.commit() }
  }

  function _sameWins(a, b) {
    if (!a || !b || a.length !== b.length) return false
    for (var i = 0; i < a.length; i++) {
      if (a[i].address !== b[i].address) return false
      if (a[i].title !== b[i].title) return false
      if (a[i].cls !== b[i].cls) return false
      if (a[i].ws !== b[i].ws) return false
    }
    return true
  }

  // Index of the window Hyprland currently has focused. `activated` is live, so
  // this is read at open time rather than baked into the cached list.
  function _activeIndex() {
    var vs = Hyprland.toplevels.values
    var addr = ""
    for (var i = 0; i < vs.length; i++) {
      if (vs[i].activated) { addr = root._addr(vs[i].address); break }
    }
    // Cold fallback. `activated` is only set once Quickshell has seen an
    // activewindow event, so on the very first summon after a shell restart
    // nothing reports it and every window looks unfocused -- which silently
    // opened the strip one step from index 0 instead of from the focused
    // window, and a tap then committed straight back to where it started.
    // focusHistoryID is a stale field in general, but it is accurate in the
    // snapshot we just refreshed, which is exactly this case.
    if (addr === "") {
      for (var k = 0; k < vs.length; k++) {
        var o = vs[k].lastIpcObject
        if (o && (o.focusHistoryID | 0) === 0) { addr = root._addr(o.address); break }
      }
    }
    if (addr === "") return 0
    for (var j = 0; j < root.wins.length; j++) {
      if (root._addr(root.wins[j].address) === addr) return j
    }
    return 0
  }

  // Where the previously focused window sits in the CURRENT positional order,
  // or -1 if it is gone (closed, or on a workspace being filtered out).
  function _mruIndex() {
    if (root.prevAddr === "") return -1
    for (var i = 0; i < root.wins.length; i++) {
      if (root._addr(root.wins[i].address) === root.prevAddr) return i
    }
    return -1
  }

  // Open the strip `step` places from whatever is focused right now.
  function _openStepped(step) {
    var n = root.wins.length
    if (n < 2) return
    var cur = root._activeIndex()
    var k = step | 0
    var idx

    if (k > 0) {
      // The first forward tap goes to the window you came from, which is what
      // makes SUPER+TAB alternate. Any further taps in the same gesture then
      // walk the positional order from there, so the highlight moves along the
      // strip the way it looks like it should rather than hopping around a
      // history the tiles do not show.
      var m = root._mruIndex()
      idx = (m >= 0 && m !== cur) ? m : (cur + 1) % n
      idx = (idx + (k - 1)) % n
    } else {
      // SHIFT+TAB stays purely positional: stepping backwards through a history
      // the strip does not display has no visible meaning.
      idx = ((cur + k) % n + n) % n
    }

    root.index = ((idx % n) + n) % n
    root.pendingSteps = 0
    root.opened = true
    idleTimer.restart()
  }

  // --- Pointer hover ----------------------------------------------------------
  //
  // Real Qt hover events, via the MouseArea over the tile row.
  //
  // This used to poll: `hyprctl cursorpos -j` on a 40ms timer, because the
  // surface was click-through (an empty input region) and so received no Qt
  // pointer events at all. That is 25 process spawns a second, ~3-4ms each,
  // for the entire time the strip is on screen -- burning CPU and adding JSON
  // parsing exactly when the thing needs to feel smooth.
  //
  // Masking the surface to the card (mask: Region { item: card }) gave it a
  // real input region, so hover now arrives for free and the poll is gone.
  // onPositionChanged only fires when the pointer actually moves, which also
  // replaces the old `hoverBase` distance threshold: that existed purely so a
  // cursor resting on a tile at open time would not yank the selection off the
  // keyboard's choice, and a movement-only signal gives that for nothing.

  // Which tile is at `lx`, measured in the ListView's content coordinates.
  // -1 for "none" -- past the end, or in the gap between two cells. Shared by
  // the pointer poll and the click handler so the two can never disagree about
  // what is under the cursor.
  function _cellAt(lx) {
    if (lx < 0) return -1
    var stride = card.cellW + card.gap
    var idx = Math.floor(lx / stride)
    if (idx < 0 || idx >= root.wins.length) return -1
    if (lx - idx * stride > card.cellW) return -1
    return idx
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
    // Click-through everywhere EXCEPT the card: the strip is a full-screen
    // surface, so an unmasked window would eat every click on the desktop
    // behind it. Same idiom Omarchy uses for notification toasts
    // (notifications/Service.qml -- Overlay layer, keyboardFocus None,
    // `mask: Region { item: popupColumn }`), which is the proof that a click
    // does reach a surface set up this way.
    mask: Region { item: card }

    // The SUPER+SPACE menu's own scrim, bound rather than reproduced.
    //
    // This used to compose its own colour at 0.35 -- the value the theme's
    // inert [launcher] section intends -- on the theory that a switcher wants a
    // touch more separation from the desktop than a menu does. Measured against
    // the menu side by side (solving composited = a*background + (1-a)*backdrop)
    // that read 0.37 against the menu's 0.22, and the two surfaces visibly did
    // not match. Aligned deliberately: they are the same kind of overlay and
    // should dim the desktop identically.
    //
    // Binding the role instead of composing a literal is what makes light and
    // dark both correct without a second value here. Color.menu.scrim resolves
    // `scrim` / `scrim-alpha` from each theme's own shell.menu.toml against that
    // theme's palette -- "background" over #1E1E1E in dark, over #FFFFFF in
    // light -- so a theme switch, or a retune of the menu's scrim, carries the
    // switcher with it. Change it in shell.menu.toml, not here.
    //
    // Still below the layer rule's ignore_alpha (0.6) in
    // overrides/hypr/looknfeel-decoration.lua -- 0.25 is further below it than
    // 0.35 was -- so the scrim stays unblurred and the windows being switched
    // between remain readable.
    Rectangle {
      anchors.fill: parent
      color: Color.menu.scrim

      // Fade the scrim, and only the scrim.
      //
      // The compositor cannot do this: a card and its scrim are one layer
      // surface, so `animation = "fade"` on the layer rule fades both together
      // and the card stops landing under the keypress. Animating here instead
      // keeps the card instant -- it maps at full opacity like the menu's --
      // while the full-screen dim eases in behind it.
      //
      // 120ms / OutCubic: a standard short-transition pairing (the compositor's
      // own whole-surface fade on the Omarchy panels measures ~100ms, so this
      // sits alongside it rather than reading as a different kind of motion).
      // The layer rule in overrides/hypr/looknfeel-decoration.lua keeps
      // no_anim on this namespace so the two do not stack.
      //
      // Fade-in only: `opened` going false unmaps the window in the same frame,
      // so there is nothing left on screen for a fade-out to play across.
      opacity: root.opened ? 1 : 0
      Behavior on opacity {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
      }
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
      // Gap between the icon and the title, as one named token. The delegate's
      // Column has a single uniform `spacing` that also sets the title/subtitle
      // gap, and those two lines want to stay a pair -- so the Column keeps its
      // xs and the title tops the rest up with topPadding. Step this along
      // Style.spacing (xs 3 / sm 4 / md 6 / lg 8 / xl 10) to retune; rowH and
      // the padding both derive from it, so there is one place to change.
      readonly property int iconTitleGap: Style.spacing.lg
      readonly property int iconTitleTopUp: Math.max(0, card.iconTitleGap - Style.space(3))

      readonly property int rowH: Math.max(
        Style.space(104),
        card.iconSize + Style.font.heading + Style.font.title
          + Style.space(3) * 2 + card.iconTitleTopUp + Style.spacing.rowPaddingX * 2)
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
        // Retain every cell, even one sitting a fraction of a pixel outside the
        // viewport. Without this the rightmost delegate is culled and rebuilt on
        // each open (measured: destroy 2 / create 2, every time), and a rebuilt
        // cell's icon Image starts out `Loading` -- so it shows its fallback
        // glyph for a frame before the icon appears. Cheap: the strip is a
        // handful of cells, never a long list.
        cacheBuffer: Math.max(card.stripW, 1)
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

            // The mark. Almost always a Nerd Font glyph rendered as text --
            // crisp at this size, and it recolours for free on selection. The
            // exception is an app with a hand-placed icon in
            // overrides/icons/fallbacks/, which the menu also uses -- see
            // flatIconBase() above.
            //
            // That PNG is baked at the theme `foreground`, but a selected tile
            // draws in `selected-text` (#007AFF accent in both our themes), so
            // blitting it as-is would leave the FOCUSED tile showing a grey
            // icon under a blue label. MultiEffect recolours it, exactly the
            // way Omarchy tints symbolic tray icons (Tray.qml:789). Measured at
            // ~0.002 ms per icon, against the handful of tiles a switcher shows.
            //
            // Height tracks the fallback Text's implicitHeight, not iconSize,
            // so swapping a glyph for an image shifts no layout: line height
            // exceeds pixelSize, and rowH above is written against the old
            // stacking.
            Item {
              id: mark
              anchors.horizontalCenter: parent.horizontalCenter
              width: card.iconSize
              height: glyphText.implicitHeight
              readonly property string flatBase: root.flatIconBase(modelData.cls)

              // Two probes rather than one: the sync writes .svg or .png
              // depending on what was dropped in, and Image cannot try a list.
              // The svg is preferred for the same reason the sync prefers it --
              // Qt rasterises a vector at the drawn size instead of scaling a
              // bitmap to it.
              Image {
                id: flatSvg
                source: mark.flatBase.length > 0 ? "file://" + mark.flatBase + ".svg" : ""
                sourceSize.width: Math.ceil(mark.width * Screen.devicePixelRatio)
                sourceSize.height: Math.ceil(mark.height * Screen.devicePixelRatio)
                visible: false
                asynchronous: true
              }

              Image {
                id: flatMark
                // Match the INK, not the canvas. app-icons.sh centres each mark
                // in 200 of 256 px, but a text glyph at pixelSize N fills close
                // to N -- so drawing the PNG into a plain iconSize box renders
                // it visibly smaller than the glyph beside it. Measured on
                // screen: 27px of ink against the Chromium glyph's 33. Scaling
                // the box by 256/200 lines the two up, and as a side effect
                // downscales the 256px master less, which is where most of the
                // softness came from.
                anchors.centerIn: parent
                width: Math.round(card.iconSize * 256 / 200)
                height: width
                source: flatSvg.status === Image.Ready
                  ? flatSvg.source
                  : (mark.flatBase.length > 0 ? "file://" + mark.flatBase + ".png" : "")
                // sourceSize is REQUIRED here, and for a reason that differs by
                // format. For a raster it selects the decode resolution, and
                // leaving it unset simply uses the file's own (256px) -- fine.
                // For a VECTOR it selects the rasterisation resolution, and
                // leaving it unset makes Qt rasterise at the SVG's intrinsic
                // size, which for these sources is 24x24 (simple-icons) or
                // 16x16 (freedesktop symbolic). Those then get scaled UP to the
                // drawn size, which is exactly as blurry as it sounds. Omarchy's
                // own Menu.qml sets it for the same reason.
                sourceSize.width: Math.ceil(width * Screen.devicePixelRatio)
                sourceSize.height: Math.ceil(height * Screen.devicePixelRatio)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                // Kept as a hidden layer so the effect can sample it as a texture.
                visible: false
                layer.enabled: true
              }

              MultiEffect {
                anchors.fill: flatMark
                source: flatMark
                visible: flatMark.status === Image.Ready
                colorization: 1.0
                colorizationColor: cell.sel ? Color.menu.selectedText : Color.menu.text
              }

              Text {
                id: glyphText
                anchors.centerIn: parent
                // Also covers a missing or unreadable PNG: if apply.sh step 7f
                // never ran, every tile simply stays a glyph.
                visible: flatMark.status !== Image.Ready
                text: root.glyphFor(modelData.cls)
                textFormat: Text.PlainText
                font.family: Style.font.menuFamily
                font.pixelSize: card.iconSize
                color: cell.sel ? Color.menu.selectedText : Color.menu.text
              }
            }
            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: root.nameFor(modelData.cls) || root.sanitizeTitle(modelData.title)
              // Tops the Column's uniform xs up to card.iconTitleGap. Counted
              // into card.rowH too, or the taller stack is clipped by the
              // fixed cell height.
              topPadding: card.iconTitleTopUp
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

      // Click a tile to focus that window. Placed after the ListView so it sits
      // above it; the list is `interactive: false`, so nothing below competes
      // for the press. Geometry is copied from the list rather than anchored to
      // it, so `mouse.x` arrives already in list coordinates and the same
      // _cellAt() hit-test serves both this and the pointer poll.
      MouseArea {
        x: list.x
        y: list.y
        width: list.width
        height: list.height
        acceptedButtons: Qt.LeftButton
        // A hand over the tiles, the way any other clickable row reads. Pointer
        // MOTION reaches the surface normally -- it is only the button press
        // that the SUPER + mouse:272 bind takes first -- so the shape applies
        // even though the click itself is delivered by the keybind.
        cursorShape: Qt.PointingHandCursor
        // Moving the pointer over a cell makes it the highlight; releasing
        // SUPER then focuses it, same as with the keyboard.
        hoverEnabled: true
        onPositionChanged: function (mouse) {
          if (!root.opened || root.wins.length < 2) return
          var idx = root._cellAt(mouse.x + list.contentX)
          if (idx < 0) return
          root.index = idx
        }
        onClicked: function (mouse) {
          var idx = root._cellAt(mouse.x + list.contentX)
          if (idx < 0) return
          root.index = idx
          root.commit()
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
