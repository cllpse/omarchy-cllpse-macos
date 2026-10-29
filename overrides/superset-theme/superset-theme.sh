#!/bin/bash
# Superset: both themes as a light/dark pair of its own custom themes
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh:
#   superset-theme.sh           import both and point Superset's system slots at them
#   superset-theme.sh --print   write the theme pack to stdout, change nothing
#   superset-theme.sh --revert  hand the slots back to Superset's own, remove ours
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

LIGHT_ID=cllpse-macos-light
DARK_ID=cllpse-macos-dark

# Rendered from each theme's colors.toml. Every key it reads must be a hex
# colour, or nothing is printed: a half-filled theme would import with
# Superset's own colours in the gaps and look almost right. -I: no environment
# or cwd on the import path.
pack() {
  python3 -I - "$REPO/omarchy-cllpse-theme-light/colors.toml" \
    "$REPO/omarchy-cllpse-theme-dark/colors.toml" "$LIGHT_ID" "$DARK_ID" <<'PY'
import json, re, sys, tomllib

def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))

def mix(top, bottom, a):
    """`top` at alpha `a` over `bottom`: how macOS cuts its separators and fills
    from textColor, and how colors.toml's `muted` was made."""
    t, b = rgb(top), rgb(bottom)
    return "#%02X%02X%02X" % tuple(round(t[i] * a + b[i] * (1 - a)) for i in range(3))

def rgba(h, a):
    return "rgba(%d, %d, %d, %s)" % (*rgb(h), a)

def build(path, theme_id, name):
    with open(path, "rb") as f:
        C = tomllib.load(f)
    for k, v in C.items():
        if k != "mode" and re.fullmatch(r"#[0-9A-Fa-f]{6}", str(v)) is None and not k.startswith("hyprland_"):
            sys.exit(f"{path}: '{k}' is not a hex colour ({v!r})")
    dark = {"dark": True, "light": False}.get(C.get("mode"))
    if dark is None:
        sys.exit(f"{path}: mode {C.get('mode')!r} is neither light nor dark")
    bg, fg, ink, accent = C["background"], C["foreground"], C["light_foreground"], C["accent"]
    # Light: border == darker_background (#E6E6E6) exactly, which is the check on the rule.
    border = mix(ink, bg, 0.10)
    fill = mix(ink, bg, 0.05)       # hover, secondary and muted surfaces
    fill_hi = mix(ink, bg, 0.10)    # active, pressed
    sidebar, card = C["dark_background"], C["lighter_background"]
    red, green = (C["bright_red"], C["bright_green"]) if dark else (C["red"], C["green"])
    ui = {
        "background": bg, "foreground": fg,
        "card": card, "cardForeground": fg,
        "popover": card, "popoverForeground": fg,
        "primary": accent, "primaryForeground": "#FFFFFF",
        "secondary": fill, "secondaryForeground": fg,
        "muted": fill, "mutedForeground": C["dark_foreground"],
        "accent": fill_hi, "accentForeground": fg,
        "tertiary": sidebar, "tertiaryActive": fill_hi,
        "destructive": red, "destructiveForeground": "#FFFFFF",
        "warning": C["orange"], "warningForeground": "#000000",
        "success": green,
        "border": border, "input": border, "ring": accent,
        "sidebar": sidebar, "sidebarForeground": fg,
        "sidebarPrimary": accent, "sidebarPrimaryForeground": "#FFFFFF",
        "sidebarAccent": fill_hi, "sidebarAccentForeground": fg,
        "sidebarBorder": border, "sidebarRing": accent,
        "chart1": C["blue"], "chart2": C["green"], "chart3": C["orange"],
        "chart4": C["magenta"], "chart5": C["cyan"],
        "highlightMatch": rgba(C["yellow"], 0.35),
        "highlightActive": rgba(C["orange"], 0.55),
        "highlight": accent, "highlightForeground": "#FFFFFF",
    }
    # Ghostty's slots, as Omarchy's ghostty.conf.tpl fills them (README.md).
    terminal = {
        "background": bg, "foreground": fg,
        "cursor": C["bright_foreground"], "cursorAccent": bg,
        "selectionBackground": C["selection"],
        "selectionForeground": C["selection_foreground"],
        "black": bg, "red": C["red"], "green": C["green"], "yellow": C["yellow"],
        "blue": C["blue"], "magenta": C["magenta"], "cyan": C["cyan"], "white": fg,
        "brightBlack": C["muted"],
        "brightRed": C["bright_red"], "brightGreen": C["bright_green"],
        "brightYellow": C["bright_yellow"], "brightBlue": C["bright_blue"],
        "brightMagenta": C["bright_magenta"], "brightCyan": C["bright_cyan"],
        "brightWhite": C["bright_foreground"],
    }
    return {
        "id": theme_id, "name": name, "author": "cllpse",
        "description": "Generated from " + path.split("/")[-2] + "/colors.toml",
        "type": C["mode"], "ui": ui, "terminal": terminal,
    }

light_path, dark_path, light_id, dark_id = sys.argv[1:]
json.dump({"themes": [
    build(light_path, light_id, "cllpse-macos Light"),
    build(dark_path, dark_id, "cllpse-macos Dark"),
]}, sys.stdout, indent=2)
print()
PY
}

mode=apply
case ${1:-} in
  --print) pack; exit ;;
  --revert) mode=revert ;;
  "") ;;
  *) echo "usage: superset-theme.sh [--print|--revert]" >&2; exit 2 ;;
esac

# The CLI is what writes app-state.json and tells a running Superset to reload
# it; the file is Superset's own, held in its memory, so it is never edited here.
SUPERSET="$HOME/.superset/bin/superset"
if [[ ! -x $SUPERSET ]]; then
  skip "Superset CLI not found ($SUPERSET) — skipped its themes"
  exit 0
fi

case $mode in
  apply)
    tmp=$(mktemp --suffix=.json)
    trap 'rm -f "$tmp"' EXIT
    pack >"$tmp"
    say "Superset -> $LIGHT_ID / $DARK_ID (custom themes, system light and dark)"
    "$SUPERSET" settings theme import "$tmp" >/dev/null
    "$SUPERSET" settings theme set system --system-light "$LIGHT_ID" --system-dark "$DARK_ID" >/dev/null
    skip "an open Superset applies it live; light/dark follows 'omarchy theme set'" ;;
  revert)
    # Only slots that are still ours go back to Superset's own: a slot the user
    # has since pointed at something else is theirs.
    state=$("$SUPERSET" settings theme get --json)
    light=$(jq -r '.systemLightThemeId' <<<"$state")
    dark=$(jq -r '.systemDarkThemeId' <<<"$state")
    [[ $light == "$LIGHT_ID" ]] && light=light
    [[ $dark == "$DARK_ID" ]] && dark=dark
    "$SUPERSET" settings theme set system --system-light "$light" --system-dark "$dark" >/dev/null
    for id in "$LIGHT_ID" "$DARK_ID"; do
      "$SUPERSET" settings theme remove "$id" >/dev/null 2>&1 || true
    done
    say "Superset: themes removed, system light/dark -> $light / $dark" ;;
esac
