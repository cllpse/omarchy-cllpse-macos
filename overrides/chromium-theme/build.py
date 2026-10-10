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
  toolbar icons                       dark_foreground     light #808080  dark #9A9A9A

The toolbar icons are the secondary grey because Chromium derives the line
between the toolbar and the page from them: with a custom theme,
kColorToolbarContentAreaSeparator = AlphaBlend(toolbar_button_icon, toolbar,
0x3A). Black icons on white drew it at #C5C5C5; these draw it at #E2E2E2
(light) and #424242 instead of #595959 (dark). README.md §2.

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
    "toolbar_button_icon": "dark_foreground",
}


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
    missing = sorted({v for v in mapping.values() if v not in palette})
    if missing:
        raise SystemExit(f"build.py: {path} has no {', '.join(missing)}")
    manifest = {
        "manifest_version": 3,
        "name": f"cllpse-macos theme ({mode})",
        "version": version,
        "description": f"Generated from omarchy-cllpse-theme-{mode}/colors.toml by "
                       "overrides/chromium-theme/build.py. Do not edit.",
        "theme": {"colors": {k: rgb(palette[v], v) for k, v in mapping.items()}},
    }
    json.dump(manifest, sys.stdout, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
