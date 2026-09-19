#!/bin/bash
# Regenerate gh-dash's theme block from overrides/gh-dash/theme.yml.tpl whenever
# the active Omarchy theme changes.
#
# Same shape, and the same reason, as the hunk hook next to this one: gh-dash
# cannot follow the terminal's ANSI palette. It hands colour strings to termenv,
# which resolves an ANSI index against its own hardcoded table rather than
# leaving slots 0-15 for the terminal to paint -- see theme.yml.tpl for the
# measured SGR output. So the palette is baked in here, on every theme-set.
#
# MERGED rather than written whole, unlike the hunk hook: config.yml also holds
# the user's own prSections / issuesSections / layout, so only theme.colors is
# replaced. PyYAML round-trips the file, so comments and key order elsewhere in
# it are not preserved -- acceptable because gh-dash generates it itself.
set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
TEMPLATE="$HERE/../../gh-dash/theme.yml.tpl"
COLORS="$HOME/.local/state/omarchy/current/theme/colors.toml"
TARGET="${XDG_CONFIG_HOME:-$HOME/.config}/gh-dash/config.yml"
GHDASH_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/gh/extensions/gh-dash"

[[ -f $TEMPLATE ]] || exit 0
[[ -f $COLORS ]] || exit 0
[[ -d $GHDASH_DIR ]] || exit 0

# Probe for an interpreter that can actually import yaml rather than trusting
# `python3` on PATH. On this machine `brew shellenv` puts linuxbrew's
# python@3.14 first and that build has no PyYAML, while the system python does
# (python-yaml, an Arch package) -- so a bare `python3` merge exits 3 and the
# theme silently never lands. Same shadowing that put linuxbrew's node ahead of
# the mise pin; see the note in ../../bash/shell.sh's neighbourhood in ~/.bashrc.
PY=""
for c in python3 /usr/bin/python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  if "$c" -c 'import yaml' >/dev/null 2>&1; then PY="$c"; break; fi
done
if [[ -z $PY ]]; then
  printf 'gh-dash-colors.sh: no python3 with PyYAML found — left %s untouched\n' "$TARGET" >&2
  exit 0
fi

pick() { omarchy-theme-color --file "$COLORS" "$1" 2>/dev/null || true; }

declare -A C=()
for k in accent selection muted dark_background foreground dark_foreground \
         selection_foreground red yellow green; do
  C[$k]="$(pick "$k")"
done

# Anything missing means a palette this template can't fill; leave the existing
# config alone rather than writing a half-themed one.
for k in "${!C[@]}"; do
  [[ ${C[$k]} =~ ^#[0-9A-Fa-f]{6}$ ]] || exit 0
done

out="$(cat "$TEMPLATE")"
for k in "${!C[@]}"; do
  out="${out//\{\{ $k \}\}/${C[$k]}}"
done

# A leftover placeholder means the template grew a key this hook doesn't fill.
# Writing it would hand gh-dash a literal "{{ foo }}" where it wants a colour.
if [[ $out == *'{{'* ]]; then
  printf 'gh-dash-colors.sh: unfilled placeholder in template — left %s untouched\n' "$TARGET" >&2
  exit 1
fi

mkdir -p "${TARGET%/*}"

# The rendered fragment goes via a temp FILE, not a pipe: the python program
# itself arrives on stdin through the heredoc below, so sys.stdin is already
# spent by the time the script runs and a piped fragment reads back as empty.
_frag="$(mktemp)"
trap 'rm -f "$_frag"' EXIT
printf '%s\n' "$out" >"$_frag"

"$PY" - "$TARGET" "$_frag" <<'PYGH'
import sys, io
try:
    import yaml
except ImportError:
    sys.exit(3)
cfg_path, frag_path = sys.argv[1], sys.argv[2]
with io.open(frag_path, encoding="utf-8") as f:
    frag = yaml.safe_load(f) or {}
try:
    with io.open(cfg_path, encoding="utf-8") as f:
        cfg = yaml.safe_load(f) or {}
except FileNotFoundError:
    cfg = {}
if not isinstance(cfg, dict):
    sys.exit(4)
# Replace only the colors sub-tree, so a `theme.ui` block the user set survives.
theme = cfg.get("theme")
if not isinstance(theme, dict):
    theme = {}
theme["colors"] = frag["theme"]["colors"]
cfg["theme"] = theme
with io.open(cfg_path, "w", encoding="utf-8") as f:
    yaml.safe_dump(cfg, f, sort_keys=False, default_flow_style=False, allow_unicode=True)
PYGH
