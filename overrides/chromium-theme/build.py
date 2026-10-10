#!/usr/bin/env python3
"""Render a Chromium theme extension's manifest.json from an Omarchy colors.toml.

The colour mapping lives here and nowhere else. It is the same theme VARIABLE
for both of our themes (decided 2026-10-10: "map the color variable names for
the dark theme 1-1 with what's used in the light theme"), except the
background: dark was then asked to be "a shade lighter (within theme
variables)", which is the next variable up from darker_background.

  background (frame + inactive tabs)  light darker_background #E6E6E6
                                      dark  dark_background   #1A1A1A
  active tab + toolbar                background         light #FFFFFF  dark #1E1E1E
  every text and icon key             light_foreground   light #000000  dark #FFFFFF

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
    "toolbar": "background",
    "tab_text": "light_foreground",
    "tab_background_text": "light_foreground",
    "tab_background_text_inactive": "light_foreground",
    "toolbar_text": "light_foreground",
    "toolbar_button_icon": "light_foreground",
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
