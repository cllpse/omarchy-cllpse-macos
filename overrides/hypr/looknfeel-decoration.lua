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
-- windows. cllpse-macos ships 14, just above that fallback.
--
-- The Omarchy shell (bar, menu, launcher, notifications, OSD) slaves its own
-- surface corner radius to this value: Style.qml runs `hyprctl getoption
-- decoration:rounding` on startup and after `omarchy theme set`. So this one key
-- drives both window and shell rounding.
--
-- rounding_power shapes the corner curve (Hyprland default 2.0 = circular arc;
-- higher = squircle, closer to Apple's continuous corners). 2.2 is a gentle
-- nudge in that direction. Windows only -- the shell's Rectangle.radius is a
-- plain circular arc and ignores it.
--
-- border_size is pinned at 2 (also the Omarchy default). BUILD.md section 5 notes
-- 1 is faithful to the macOS hairline but a weak focus cue in a tiling WM.
--
-- gaps_in/gaps_out follow BUILD.md section 5's Apple 8pt layout grid: 8 between
-- windows, 16 (2x the inner step) at the screen edge. Omarchy defaults to 5/10.

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
-- Focused windows stay fully opaque, per BUILD.md section 5 ("macOS windows are
-- opaque"). Unfocused drop to 0.875 -- a deliberate deviation from section 5's
-- 1.0/1.0, and not only as a focus cue.
--
-- blur.ignore_opacity is true, so a window made semi-transparent gets the full
-- blur pass rendered behind it: an unfocused window blurs whatever sits beneath.
-- That is the intended look here, glass rather than a flat dim, which is why the
-- dim_inactive block below stays off -- stacking a darkening pass on top of it
-- muddied the result and worked against the effect.
--
-- 0.875 currently. 0.9 and 0.88 were both tried on the way here.
o.window({ tag = "default-opacity" }, { opacity = "1.0 0.875" })

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
    rounding = 14,
    rounding_power = 2.2,
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
  general = { border_size = 2, gaps_in = 8, gaps_out = 16 },
})

-- ── Blur on shell layer surfaces ──────────────────────────────────────────
-- Opt each Omarchy Quickshell surface into the global blur above. Without this
-- the engine never samples through the bar / menu / notifications / OSD / etc.
-- These rules are additive to Omarchy's own no_anim layer rules in
-- default/hypr/apps/omarchy-shell.lua -- they don't replace them.
--
-- ignore_alpha = 0.1 keeps the fully-transparent margin around rounded cards
-- (menu, launcher, polkit, notifications are fullscreen layers with a centred
-- card) from blurring into a rectangle. blur_popups extends blur to child
-- dropdowns (bar module menus, panel flyouts).
--
-- window-switcher-hud is our own plugin (omarchy-cllpse-switcher/, symlinked to
-- ~/.config/omarchy/plugins/io.eject.window-switcher). Its card already binds
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
  ignore_alpha = 0.1,
})

-- ── Animation speed (2x) ───────────────────────────────────────────────────
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
-- frames in). Every leaf below is Omarchy's stock speed HALVED (2x faster),
-- not doubled -- doubling the raw number would have made it 2x *slower*.
--
-- Some machines this theme is applied to also run the Omaland settings plugin
-- (bobbynicholas.omaland, not part of this repo), which owns its own "Speed"
-- slider and writes a separate `hl.animation` block further down this same
-- looknfeel.lua. Hyprland resolves duplicate per-leaf calls last-write-wins by
-- file position, so if Omaland's block sits after this one (or gets
-- regenerated later by opening its Settings panel), its value wins instead.
-- That's an accepted tradeoff here -- this block is meant to make cllpse-macos
-- self-sufficient on a machine with no Omaland installed at all, not to
-- coordinate with Omaland where both are present.
hl.animation({ leaf = "global", enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 2.7, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 1.9, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.05, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 0.75, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 0.87, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 0.73, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 1.52, bezier = "quick" })
hl.animation({ leaf = "fadeSwitch", enabled = false })
hl.animation({ leaf = "layers", enabled = true, speed = 1.91, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 2, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 0.75, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 0.9, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 0.7, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = false })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 1.5, bezier = "easeOutQuint", style = "slidevert" })
