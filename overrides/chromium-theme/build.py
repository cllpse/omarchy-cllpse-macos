#!/usr/bin/env python3
"""Render a Chromium theme extension's manifest.json from an Omarchy colors.toml.

The colour mapping lives here and nowhere else. It is the same theme VARIABLE
for both of our themes (decided 2026-10-10: "map the color variable names for
the dark theme 1-1 with what's used in the light theme"), except the
background: dark was then asked to be "a shade lighter (within theme
variables)", which is the next variable up from darker_background. The active
tab then got the same "shade-bump": lighter_background, which in light is the
same #FFFFFF as background, so only dark moves and the name still holds 1-1.

  background (frame + inactive tabs)  light darker_background #E6E6E6
                                      dark  dark_background   #1A1A1A
  active tab + toolbar                lighter_background  light #FFFFFF  dark #282828
  text keys (tabs, toolbar text)      light_foreground    light #000000  dark #FFFFFF
  toolbar icons                       COMPUTED            light #7C7C7E  dark #7B7B7B

The toolbar icons are not a theme variable: they are solved so that the line
between the toolbar and the page comes out IDENTICAL to the address field's
background (asked for 2026-10-10). Chromium derives both from the toolbar
colour, and neither has a key of its own:
  - the line:  kColorToolbarContentAreaSeparator =
               AlphaBlend(toolbar_button_icon, toolbar, 0x3A)    chrome_color_mixer.cc
  - the field: kColorToolbarBackgroundSubtleEmphasis =
               BlendForMinContrast(toolbar, toolbar, target, 1.3) browser_theme_pack.cc
So omnibox_field() reproduces the second exactly (it matches the [202,202,203]
measured under a #E6E6E6 toolbar), and separator_icon() picks the icon whose
23% blend over the toolbar lands on it, per channel, as neutral as possible.
Exact against Chromium 152's code; re-check if those functions change.
Fainter icons, to fade the line further, were tried the same day and set back
(README.md §2).
README.md §2.

Every `_inactive` key equals its focused twin: nothing changes with window
focus (README.md §2). The active tab has no unfocused key at all.

Usage:  build.py <colors.toml> <mode> <version>   manifest JSON on stdout
"""
import json
import sys
import tomllib

# The background's variable, per mode (see the docstring).
BACKGROUND = {"light": "darker_background", "dark": "dark_background"}

# theme.colors key -> colors.toml variable; "@background" is BACKGROUND[mode].
MAPPING = {
    "frame": "@background",
    "frame_inactive": "@background",
    "background_tab": "@background",
    "background_tab_inactive": "@background",
    "toolbar": "lighter_background",
    "tab_text": "light_foreground",
    "tab_background_text": "light_foreground",
    "tab_background_text_inactive": "light_foreground",
    "toolbar_text": "light_foreground",
    "toolbar_button_icon": "@separator_icon",
}


# ── Chromium 152's colour arithmetic, for the computed icon colour ───────────
# ui/gfx/color_utils.cc and chrome/browser/themes/browser_theme_pack.cc.
_GREY900 = (0x20, 0x21, 0x24)    # g_darkest_color
_WHITE = (255, 255, 255)
_MIDPOINT = 0.211692036          # g_luminance_midpoint
_SEPARATOR_ALPHA = 0x3A          # kColorToolbarContentAreaSeparator's blend
_MIN_OMNIBOX_CONTRAST = 1.3      # kMinOmniboxToolbarContrast


def _lum(c):
    def lin(v):
        v /= 255.0
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return 0.2126 * lin(c[0]) + 0.7152 * lin(c[1]) + 0.0722 * lin(c[2])


def _contrast(a, b):
    la, lb = _lum(a) + 0.05, _lum(b) + 0.05
    return la / lb if la > lb else lb / la


def _max_contrast(c):
    return _WHITE if _lum(c) < _MIDPOINT else _GREY900


def _blend(fg, bg, alpha):  # color_utils::AlphaBlend for opaque colours
    if alpha == 0:
        return bg
    if alpha == 255:
        return fg
    a = alpha / 255.0
    return tuple(int(fg[i] * a + bg[i] * (1 - a) + 0.5) for i in range(3))


def omnibox_field(toolbar):
    """kColorToolbarBackgroundSubtleEmphasis under a custom theme."""
    endpoint = _GREY900 if _lum(toolbar) < _MIDPOINT else _WHITE
    target = endpoint if _contrast(toolbar, endpoint) >= _MIN_OMNIBOX_CONTRAST else _max_contrast(endpoint)
    if _contrast(toolbar, toolbar) >= _MIN_OMNIBOX_CONTRAST:
        return toolbar
    best, lo, hi = target, 0, 256
    while lo < hi:  # BlendForMinContrast: the least alpha that reaches 1.3
        mid = (lo + hi) // 2
        c = _blend(target, toolbar, mid)
        if _contrast(c, toolbar) >= _MIN_OMNIBOX_CONTRAST:
            best, hi = c, mid
        else:
            lo = mid + 1
    return best


def separator_icon(toolbar):
    """The toolbar_button_icon whose separator blend equals the omnibox field."""
    want = omnibox_field(toolbar)
    a = _SEPARATOR_ALPHA / 255.0
    hits = [[v for v in range(256) if int(v * a + toolbar[ch] * (1 - a) + 0.5) == want[ch]]
            for ch in range(3)]
    if not all(hits):
        raise SystemExit(f"build.py: no icon colour puts the separator on {want}")
    grey = sum(sum(h) / len(h) for h in hits) / 3  # as neutral as the hits allow
    icon = tuple(min(h, key=lambda v: abs(v - grey)) for h in hits)
    assert _blend(icon, toolbar, _SEPARATOR_ALPHA) == want
    return list(icon)


def rgb(value, name):
    h = value.lstrip("#")
    if len(h) != 6:
        raise SystemExit(f"build.py: {name} = {value!r} is not #RRGGBB")
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]


def main():
    if len(sys.argv) != 4:
        raise SystemExit(__doc__.strip().splitlines()[-1])
    path, mode, version = sys.argv[1:]
    if mode not in BACKGROUND:
        raise SystemExit(f"build.py: mode must be one of {', '.join(BACKGROUND)}")
    with open(path, "rb") as f:
        palette = tomllib.load(f)
    mapping = {k: BACKGROUND[mode] if v == "@background" else v for k, v in MAPPING.items()}
    missing = sorted({v for v in mapping.values() if not v.startswith("@") and v not in palette})
    if missing:
        raise SystemExit(f"build.py: {path} has no {', '.join(missing)}")
    manifest = {
        "manifest_version": 3,
        "name": f"cllpse-macos theme ({mode})",
        "version": version,
        "description": f"Generated from omarchy-cllpse-theme-{mode}/colors.toml by "
                       "overrides/chromium-theme/build.py. Do not edit.",
        "theme": {"colors": {k: rgb(palette[v], v) for k, v in mapping.items() if not v.startswith("@")}},
    }
    colors = manifest["theme"]["colors"]
    colors["toolbar_button_icon"] = separator_icon(tuple(colors["toolbar"]))
    json.dump(manifest, sys.stdout, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
