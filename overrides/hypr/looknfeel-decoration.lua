-- Window/shell decoration for cllpse-macos. Can't live in the theme folder:
-- Omarchy 4 strips .lua from git-cloned themes, and none of these have a
-- colors.toml key. Appended to ~/.config/hypr/looknfeel.lua by overrides/apply.sh.
-- Applies on the next Hyprland reload (theme-set, relogin, `hyprctl reload`); the
-- running shell re-reads what it mirrors on `omarchy theme set` /
-- `omarchy-restart-shell`.

-- ── Corner radius ──────────────────────────────────────────────────────────
-- Omarchy 4 defaults to rounding = 0; macOS has rounded window corners. BUILD.md
-- section 5 specifies 26 (macOS Tahoe toolbar-window radius, third-party
-- reported) with 12 as the defensible fallback -- 26 is dramatic on tiled
-- windows. cllpse-macos ships 18; 16 and 14 were earlier values.
--
-- The Omarchy shell (bar, menu, launcher, notifications, OSD) slaves its own
-- surface corner radius to this value: Style.qml runs `hyprctl getoption
-- decoration:rounding` on startup and after `omarchy theme set`. So 18 rounds
-- both the windows and the bar / menu / notifications.
--
-- rounding_power shapes the corner curve (2.0 = plain circular arc, higher =
-- squircle toward Apple's continuous corner). 2.2 -- barely off circular. It is
-- windows-only: the shell's Rectangle.radius ignores it, so the bar and menu
-- stay a pure arc. A stronger squircle (3-3.4) was tried, but Hyprland's border
-- renderer draws the stroke's outer edge under-curved above ~3 and it pinches at
-- the 45 degree corner, so it is kept near circular.
--
-- border_part_of_window = true (the Hyprland default, set explicitly) draws the
-- border inside each window's tile -- the content shrinks to fit -- rather than
-- as its own decoration outside it. `false` was used while rounding_power was
-- high (it curved a thin stroke's corner better); at 2.2 there is nothing to
-- gain, and inside is the tidier model in a tiling WM.
--
-- border_size is 2 (Omarchy's default). BUILD.md section 5's hairline (1) is
-- macOS-faithful but a weak focus cue in a tiling WM.
--
-- gaps_in/gaps_out follow BUILD.md section 5's Apple 8pt layout grid: 12
-- between windows (the grid's `md` step), 24 (2x, the `xxl` step) at the
-- screen edge -- widened from the grid's sm/lg steps (8/16). Omarchy defaults
-- to 5/10.

-- ── Window opacity ──────────────────────────────────────────────────────────
-- default.hypr.windows tags every window +default-opacity, lets the per-app
-- files strip that tag again, then applies opacity = "0.985 0.96" to whatever
-- still carries it. All of that runs during default.hypr.omarchy, which is
-- required before hypr.looknfeel, so repeating the same tag match here lands
-- later in load order and wins the field.
--
-- Match the TAG, not ".*". Omarchy removes default-opacity from things that
-- must not go translucent -- DaVinci Resolve, PiP and webcam overlays, Steam,
-- QEMU, RetroArch, YouTube/Zoom web apps -- and gives browsers their own
-- 1.0/0.985. A ".*" match silently overrides every one of those deliberate
-- exclusions, dimming video and colour-critical windows; matching the tag
-- inherits them all for free.
--
-- Focused windows at 0.99, per BUILD.md section 5 ("macOS windows are opaque")
-- with a hair of glass so focused windows read as the same material as
-- unfocused rather than a flat cutout -- a deliberate deviation from section
-- 5's 1.0/1.0. Unfocused drops further to 0.875, not only as a focus cue.
--
-- blur.ignore_opacity is true, so a window made semi-transparent gets the full
-- blur pass rendered behind it: even the focused window blurs whatever sits
-- beneath it now, and unfocused blurs more. That is the intended look here,
-- glass rather than a flat dim, which is why the dim_inactive block below
-- stays off -- stacking a darkening pass on top of it muddied the result and
-- worked against the effect.
--
-- 0.99/0.875 currently. Focused was 1.0 (fully opaque), then 0.97, then 0.98,
-- before landing here; unfocused alone went through 0.9 and 0.88 on the way
-- to 0.875.
o.window({ tag = "default-opacity" }, { opacity = "0.99 0.875" })

-- ── Browser opacity: same unfocused glass as everything else ───────────────
-- default/hypr/apps/browser.lua strips +default-opacity from every
-- chromium/firefox-based browser and pins them to opacity "1.0 0.985", so the
-- tag-matched rule above never touches them -- browsers stay effectively opaque
-- when unfocused (98.5%) and no blur reads through. Re-match the browser tags
-- directly, after browser.lua has run, so browsers get the same 0.99/0.875
-- frost as the rest of the desktop. browser.lua removes the
-- chromium-based-browser tag from YouTube/Zoom web-app windows, so those stay
-- excluded here too.
o.window({ tag = "chromium-based-browser" }, { opacity = "0.99 0.875" })
o.window({ tag = "firefox-based-browser" }, { opacity = "0.99 0.875" })

-- ── Figma opacity: fully opaque, focused or not ────────────────────────────
-- Figma Desktop (the figma-linux AppImage) is a colour-critical design tool --
-- same rationale Omarchy's own davinci-resolve.lua gives DaVinci Resolve:
-- translucency, and the blur pass rendered behind it, distorts colour work.
-- Not one of Omarchy's stock exclusions (browser/video/DaVinci/PiP/Steam/QEMU/
-- RetroArch), so it still carried our +default-opacity 0.98/0.875 rule above
-- until now. Loosely matched -- ".*[Ff]igma.*" against the class, same idiom
-- as davinci-resolve.lua's ".*[Rr]esolve.*" -- because the live window class
-- is the lowercase "figma-desktop", not the "Figma" its .desktop's
-- StartupWMClass claims. Strip the tag and set opacity explicitly, same
-- belt-and-suspenders as Omarchy's own steam.lua / qemu.lua.
o.window(".*[Ff]igma.*", { tag = "-default-opacity", opacity = "1 1" })

-- ── Blur (global) ─────────────────────────────────────────────────────────
-- BUILD.md section 5 ("NSVisualEffectView is a heavy blur"): vibrancy 0.20
-- ("macOS boosts saturation behind glass"), brightness/contrast 1.0 ("macOS
-- does not darken"). Omarchy ships blur disabled.
--
-- 7/4: effective spread (about size * 2^(passes-1)) is ~56, against ~32 for
-- section 5's original 8/3. This is where a long walk landed. 12/4 (~96), 10/4
-- and 8/4 all read muddy -- the backdrop turning into an undifferentiated wash
-- rather than a suggestion of what sits behind the surface -- while 6/3 (~24)
-- overshot the other way and lost the glass entirely.
--
-- The two knobs are not equivalent, and they do not cost the same. Hyprland's
-- blur is dual-Kawase: `size` scales the sampling OFFSETS, so raising it is
-- essentially free (identical number of texture fetches, just further apart),
-- while each `pass` adds a whole downsample+upsample iteration -- roughly +30%
-- blur work going from 3 to 4, and it scales with how many blurred surfaces are
-- on screen. Trivial on this machine (RTX 3070 Ti driving 6.1 Mpx), but it is
-- the knob that actually costs something.
--
-- The reach is bought with a pass rather than more size on purpose: passes
-- change the character, giving the softer, more diffuse falloff a large macOS
-- material has, where more size just widens the same blur. So when it needed
-- toning down, size came off and the 4th pass stayed -- dropping to 3 passes
-- would have halved the spread and lost that falloff in one move. Size is now
-- below section 5's own figure; easing further is better done by raising the
-- unfocused window opacity (letting less of the blur through) than by shrinking
-- size again, which starts to make the 4th pass pointless.
--
-- Note this is only visible through whatever a surface leaves translucent. At
-- shell.menu/notifications alpha 0.92 just 8% of the backdrop shows, so radius
-- barely registers there -- the bar (0.72) is where it reads. Lowering
-- background-alpha is the stronger lever than widening blur.
--
-- This is only the global engine. On its own it does nothing to the Omarchy
-- shell surfaces -- the per-namespace layer rules below opt each one in.

-- ── Unfocused window dim: OFF, deliberately ────────────────────────────────
-- dim_inactive darkens unfocused windows as a focus cue. It was tried at 0.10
-- and removed: stacked on top of the unfocused opacity below it muddied the
-- result, and darkening works against the effect that opacity is there for.
-- The blur showing through an unfocused window is wanted here, not a side
-- effect to be suppressed -- see the window opacity block above. Set false
-- explicitly (it is also the Hyprland default) so the choice is on the record.
hl.config({
  decoration = {
    dim_inactive = false,
    rounding = 18,
    rounding_power = 2.2,
    border_part_of_window = true,
    blur = {
      enabled = true,
      size = 7,
      passes = 4,
      -- Saturation of the blurred backdrop. BUILD.md section 5 started at 0.20
      -- ("macOS boosts saturation behind glass"); 0.30 pulls more colour
      -- through. Pure shader parameters, no render cost.
      vibrancy = 0.30,
      -- How far vibrancy reaches into dark areas. Hyprland defaults this to 0,
      -- which means dark backdrops get almost no boost -- so the dark theme's
      -- glass read flat next to the light theme's. Matched to vibrancy so both
      -- themes saturate alike.
      vibrancy_darkness = 0.30,
      -- Frosted grain, a touch above Hyprland's 0.0117 default. Worth knowing
      -- how little this shows: at the surface alphas here -- menu 0.92, windows
      -- 0.875 -- only 8-12% of the noisy backdrop is visible, so even 0.2 was
      -- near-indistinguishable from this in a side-by-side. The bar at 0.72 is
      -- the only surface transparent enough for grain to really read.
      noise = 0.02,
      brightness = 1.0,
      contrast = 1.0,
    },
  },
  general = { border_size = 2, gaps_in = 12, gaps_out = 24 },
  -- ── Group bar: OFF ───────────────────────────────────────────────────────
  -- Hyprland draws a row of tabs across the top of a grouped window. macOS has
  -- no equivalent -- window tabbing there is per-app (NSWindow tabs, inside the
  -- app's own titlebar), never a compositor decoration -- and the strip is a
  -- 22px monospace bar that ignores the theme's typography entirely, so it
  -- reads as foreign chrome on every group.
  --
  -- Omarchy's default/hypr/looknfeel.lua styles the bar at length (font_size 12,
  -- monospace, indicator_height/gap, height 22, its own text and fill colours)
  -- but never sets `enabled`, so Hyprland's default of true stands.
  --
  -- Turning it off is the visible half of a choice this repo already made: the
  -- keybind sweep unbinds *every* group bind Omarchy ships -- SUPER+G,
  -- SUPER+ALT+G, the four SUPER+ALT arrows, SUPER+ALT+TAB, SUPER+CTRL+
  -- LEFT/RIGHT, the mouse wheel pair and the ten SUPER+ALT+code:NN slots (see
  -- keybind-unbinds.lua:80-96). With no way to form or navigate a group from
  -- the keyboard, the bar could only ever appear on a group made by a window
  -- rule, and then only as an unstyleable strip.
  --
  -- Grouping itself is untouched -- this hides the bar, it does not disable the
  -- feature. group.col.border_active / border_inactive stay theme-bound (the
  -- generated hyprland.lua sets both from colors.toml), so a group formed some
  -- other way still shows its border cue.
  group = { groupbar = { enabled = false } },
})

-- ── Blur on shell layer surfaces ──────────────────────────────────────────
-- Opt each Omarchy Quickshell surface into the global blur above. Without this
-- the engine never samples through the bar / menu / notifications / OSD / etc.
-- These rules are additive to Omarchy's own no_anim layer rules in
-- default/hypr/apps/omarchy-shell.lua -- they don't replace them.
--
-- ignore_alpha leaves any pixel below that alpha unblurred. It started at 0.1,
-- purely to keep the fully-transparent margin around rounded cards (menu,
-- launcher, polkit, notifications are fullscreen layers with a centred card)
-- from blurring into a rectangle.
--
-- It is now 0.6, which does more work. A card and the scrim behind it are the
-- SAME layer surface, so Hyprland cannot blur them differently -- per layer the
-- only controls are blur on/off and this threshold. Sitting it between the
-- scrims and the cards splits them:
--
--   launcher scrim 0.35, menu scrim 0.25   -> below 0.6, not blurred
--   bar 0.72, launcher 0.85, menu 0.92     -> at or above 0.6, blurred
--
-- so the menu and the window switcher keep their frosted card while the dimmed
-- backdrop stays sharp and the windows behind it remain readable -- which is the
-- point of a switcher. Watch this if any surface alpha changes: a card dropped
-- below 0.6 would silently lose its blur.
--
-- blur_popups extends blur to child dropdowns (bar module menus, panel flyouts).
--
-- window-switcher-hud is our own plugin (omarchy-cllpse-switcher/, symlinked to
-- ~/.config/omarchy/plugins/cllpse.window-switcher). Its card already binds
-- Color.menu.background / .scrim, so once its layer is in the match it blurs
-- exactly like the Omarchy menu.
--
-- Not matched: omarchy-background (the wallpaper itself) and the transient
-- omarchy-bar-drag-ghost / -move-ghost surfaces.
--
-- Inert until the matching shell.toml `background-alpha` drops below 1.0 -- an
-- opaque surface has nothing to blur through. The launcher/menu scrim tuning
-- (whether the dimmed backdrop should also blur) needs a look once alpha is in.
hl.layer_rule({
  match = { namespace = "^omarchy-(bar|menu|notifications|osd|polkit|clipboard|emojis|reminders|image-selector|network-qr|keyboard-panel|lock-preview|window-switcher-hud)$" },
  blur = true,
  blur_popups = true,
  ignore_alpha = 0.6,
})

-- A short fade-in on the keyboard-driven panels, and on our switcher.
--
-- Hyprland fades a layer surface as it maps (`layersIn`, style = fade, ~130ms
-- at our speeds), but Omarchy opts its own panels out of it:
-- `default/hypr/apps/omarchy-shell.lua:5` for the bar and :10 for
-- ^(omarchy-menu|omarchy-image-selector|omarchy-emojis|omarchy-clipboard|
-- omarchy-keyboard-panel)$. That left the panels snapping in while
-- notifications, the OSD, polkit and reminders -- which are NOT in that list --
-- faded, so the shell was inconsistent with itself.
--
-- A later rule wins, so this is re-enabled here rather than by editing
-- Omarchy's file: layer rules accumulate, and ours load after the defaults
-- (user hypr files are read last). Verified by burst-screenshotting the menu's
-- scrim as it opens -- one hard step before this rule, a ~130ms ramp after it.
--
-- What this cannot do is fade the scrim alone. A card and its scrim are one
-- layer surface, so the compositor fades them together; per-surface, fade-or-
-- not is the whole of the control. Duration is `layersIn`'s speed in the
-- animation block below, which is shared with every other animated layer --
-- there is no per-rule duration.
--
-- The bar is deliberately NOT included: it is persistent chrome, so its fade
-- would only ever be seen on a shell restart, and Omarchy keeps it instant for
-- that reason.
hl.layer_rule({
  match = { namespace = "^(omarchy-menu|omarchy-image-selector|omarchy-emojis|omarchy-clipboard|omarchy-keyboard-panel|omarchy-window-switcher-hud)$" },
  no_anim = false,
  animation = "fade",
})

-- The switcher is in the list above, and used not to be.
--
-- It carried its own no_anim rule and faded only its scrim, from Hud.qml
-- (120ms, Easing.OutCubic), so the card could land instantly under the keypress
-- while the dim eased in behind it. The compositor cannot express that -- a
-- card and its scrim are one layer surface -- which was the whole reason for
-- the split.
--
-- The cost was that the switcher became the one surface in the shell moving
-- differently from the rest. Measured against the live config the panels ramp
-- over 133ms on easeOutQuint (layersIn speed 1.33 ds; a note in Hud.qml put it
-- at ~100ms and was wrong, and the 120ms was chosen to sit alongside that
-- figure). More to the point, the switcher's CARD did not ramp at all, and
-- content-there-immediately reads as faster than any curve difference -- which
-- is exactly how it read.
--
-- So it takes the whole-surface fade like everything else, and the Hud.qml
-- Behavior is removed rather than left alone: with no_anim off, a QML fade
-- inside the surface would stack on top of the compositor's.

-- ── Animation speed (3x) ───────────────────────────────────────────────────
-- Can't live in the theme: colors.toml/shell.toml carry no animation keys at
-- all (checked shell.toml.tpl), and the shell's own per-component durations
-- (e.g. Hud.qml's 420ms selection fade) are hardcoded per QML file, not
-- theme-driven either. Hyprland's animation speed is the only lever, so this
-- has to be a hypr override, same as everything else in this file.
--
-- IMPORTANT direction: Hyprland's hl.animation `speed` is inversely
-- proportional to duration -- SMALLER speed = FASTER animation. Verified
-- empirically (burst-screenshotted a window spawn at speed=0.3 vs speed=20;
-- 0.3 finished before the first capture, 20 was still mid pop-in several
-- frames in). Every leaf below is Omarchy's stock speed divided by 3 (3x
-- faster) -- not multiplied by 3, which would have made it 3x *slower* --
-- with a floor of 1: six leaves (windowsOut, fadeIn, fadeOut, layersOut,
-- fadeLayersIn, fadeLayersOut) would have landed at 0.46-0.6 on a straight
-- 1/3 scale and are clamped to 1 instead, rather than let the fastest
-- animations get fast enough to look like a hard cut.
hl.animation({ leaf = "global", enabled = true, speed = 3.33, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 1.8, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 1.26, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 1.37, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 1.01, bezier = "quick" })
hl.animation({ leaf = "fadeSwitch", enabled = false })
hl.animation({ leaf = "layers", enabled = true, speed = 1.27, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 1.33, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = false })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 1.0, bezier = "easeOutQuint", style = "slidevert" })

-- ── Presentation-popup width ───────────────────────────────────────────────
-- The floating terminal Omarchy shows for `omarchy pkg remove` / install /
-- menu actions (class org.omarchy.terminal, title "Omarchy") opens the
-- OMARCHY block-art banner via omarchy-show-logo -- built from U+2580/2584/2588
-- (upper/lower/full block). Ghostty rasterises those solid glyphs with a ~1px
-- inter-cell seam whenever the surface width does not land on a whole device
-- pixel at the monitor's fractional scale. Omarchy's default float size is
-- 875x600 (default/hypr/apps/system.lua, matched on the "floating-window" tag);
-- 875 x 1.25 = 1093.75 px -> seams. Invisible on a dark background, a stark
-- white grid on the light theme's white popup.
--
-- 896 is the nearest width above 875 that is a clean multiple for the cell grid
-- (896 x 1.25 = 1120 px exactly). Verified 2025-09-05 by screenshotting the
-- banner at 875..1000 in 1-4px steps: solid from 896 on, seamed below. This
-- rule loads after default.hypr.omarchy (hyprland.lua requires hypr.looknfeel
-- later), so it wins by file position. Height is left at Omarchy's 600.
--
-- If `omarchy display text size` changes the Ghostty font size, the clean
-- width changes with the cell metrics -- re-sweep and update the 896.
hl.window_rule({ match = { tag = "floating-window", class = "org.omarchy.terminal" }, size = { 896, 600 } })
