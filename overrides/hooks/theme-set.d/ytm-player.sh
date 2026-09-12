#!/bin/bash
# Sync ytm-player's colors with the active Omarchy theme.
# Installed via: omarchy hook install theme-set <this file>
# Source template: ~/.config/omarchy/themed/ytm-player.toml.tpl
set -euo pipefail

THEME_DIR="$HOME/.local/state/omarchy/current/theme"
SRC="$THEME_DIR/ytm-player.toml"
DEST_DIR="$HOME/.config/ytm-player"

# Nothing to do if ytm-player isn't installed or the template didn't render.
command -v ytm >/dev/null 2>&1 || exit 0
[[ -f $SRC ]] || exit 0

mkdir -p "$DEST_DIR"
cp "$SRC" "$DEST_DIR/theme.toml"

# theme.toml cannot set Textual's `dark` flag, and that flag drives every
# derived contrast token. So flip the base theme to match the Omarchy
# theme's own light/dark mode.
mode=$(sed -n 's/^mode[[:space:]]*=[[:space:]]*"\([a-z]*\)".*/\1/p' "$THEME_DIR/colors.toml" | head -1)
base="textual-dark"
[[ ${mode:-dark} == "light" ]] && base="textual-light"

python3 - "$DEST_DIR/config.toml" "$base" <<'PY'
import pathlib, re, sys

path, base = pathlib.Path(sys.argv[1]), sys.argv[2]
text = path.read_text(encoding="utf-8") if path.exists() else ""
line = f'theme = "{base}"'

header = re.search(r"^\[ui\]\s*$", text, re.M)
if not header:
    text = f"{text.rstrip(chr(10))}\n\n[ui]\n{line}\n" if text.strip() else f"[ui]\n{line}\n"
else:
    start = header.end()
    nxt = re.search(r"^\[", text[start:], re.M)
    end = start + (nxt.start() if nxt else len(text) - start)
    section = text[start:end]
    if re.search(r"^[ \t]*theme[ \t]*=", section, re.M):
        section = re.sub(r"^[ \t]*theme[ \t]*=.*$", line, section, count=1, flags=re.M)
    else:
        section = "\n" + line + section
    text = text[:start] + section + text[end:]

path.write_text(text, encoding="utf-8")
PY
