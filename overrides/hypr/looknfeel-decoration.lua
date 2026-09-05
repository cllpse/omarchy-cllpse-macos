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
-- default.hypr.windows tags every window +default-opacity during Omarchy's own
-- require chain (default.hypr.omarchy, required before hypr.looknfeel) and
-- sets opacity = "0.985 0.96" on that tag. Rather than touch the tag, match
-- every window again here: window_rule entries are matched in load order and a
-- later matching rule wins the same field for a given window, same
-- last-write-wins semantics as the animation leaves below -- so this simply
-- overrides Omarchy's 0.985/0.96.
--
-- Deviates from BUILD.md section 5's "macOS windows are opaque" spec (1.0/1.0)
-- by choice: focused stays fully opaque, unfocused windows dim to 0.89 so focus
-- is easier to track at a glance across a tiled layout. Focused windows being
-- 1.0 means no blur shows through a window -- blur stays a shell-surface effect,
-- which is what section 5 wants ("blur belongs on layer surfaces, not windows").
o.window(".*", { opacity = "1.0 0.89" })

-- ── Blur (global) ─────────────────────────────────────────────────────────
-- BUILD.md section 5 ("NSVisualEffectView is a heavy blur"): vibrancy 0.20
-- ("macOS boosts saturation behind glass"), brightness/contrast 1.0 ("macOS
-- does not darken"). Omarchy ships blur disabled.
--
-- size is 12 rather than the 8 section 5 started from. size is the radius per
-- pass and passes is the number of downsample rounds, each roughly doubling the
-- reach, so effective spread is about size * 2^(passes-1): 8/3 ~= 32, 12/3 ~= 48.
-- Widening via size keeps the character of the blur and costs almost nothing;
-- passes = 4 would double the spread again but is markedly more expensive and
-- can band on gradients.
--
-- Note this is only visible through whatever a surface leaves translucent. At
-- shell.menu/notifications alpha 0.92 just 8% of the backdrop shows, so radius
-- barely registers there -- the bar (0.72) is where it reads. Lowering
-- background-alpha is the stronger lever than widening blur.
--
-- This is only the global engine. On its own it does nothing to the Omarchy
-- shell surfaces -- the per-namespace layer rules below opt each one in.
hl.config({
  decoration = {
    rounding = 14,
    rounding_power = 2.2,
    blur = {
      enabled = true,
      size = 12,
      passes = 3,
      vibrancy = 0.20,
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
