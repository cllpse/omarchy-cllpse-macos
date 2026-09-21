# Shared readers/writers for display scaling + text size.
# Sourced by save-display.sh (capture), apply.sh (restore) and revert.sh (undo)
# so the three can't drift apart. Not executable on its own.

DISPLAY_MONITORS="${DISPLAY_MONITORS:-$HOME/.config/hypr/monitors.lua}"
DISPLAY_SHELL_TOML="${DISPLAY_SHELL_TOML:-$HOME/.config/omarchy/shell.toml}"

# `local omarchy_<name> = <value>` -> <value>, trailing comment/space stripped.
read_scale() { # $1 variable-name
  [[ -f $DISPLAY_MONITORS ]] || return 0
  sed -n "s/^[[:space:]]*local[[:space:]]\+$1[[:space:]]*=[[:space:]]*\(.*\)/\1/p" "$DISPLAY_MONITORS" \
    | head -1 | sed 's/[[:space:]]*--.*$//; s/[[:space:]]*$//'
}

# Replace that variable's value in place. Only the one `local` line is touched;
# the hl.monitor() lines that reference it are left alone, so monitor topology
# (outputs, modes, positions) is never rewritten.
write_scale() { # $1 variable-name  $2 value
  [[ -f $DISPLAY_MONITORS ]] || return 1
  grep -qE "^[[:space:]]*local[[:space:]]+$1[[:space:]]*=" "$DISPLAY_MONITORS" || return 1
  local tmp; tmp=$(mktemp)
  sed "s|^\([[:space:]]*local[[:space:]]\+$1[[:space:]]*=[[:space:]]*\).*|\1$2|" \
    "$DISPLAY_MONITORS" >"$tmp" || { rm -f "$tmp"; return 1; }
  # Never let a failed rewrite empty a real config.
  [[ -s $tmp ]] || { rm -f "$tmp"; return 1; }
  cat "$tmp" >"$DISPLAY_MONITORS"
  rm -f "$tmp"
}

# [font] base-size from the machine shell.toml; empty = Omarchy's default.
read_text_size() {
  [[ -f $DISPLAY_SHELL_TOML ]] || return 0
  awk '
    /^[[:space:]]*\[/ { in_font = ($0 ~ /^[[:space:]]*\[font\]([[:space:]]|$)/); next }
    in_font && /^[[:space:]]*base-size[[:space:]]*=/ {
      v = $0; sub(/^[^=]*=[[:space:]]*/, "", v); sub(/[[:space:]]*(#.*)?$/, "", v); print v; exit
    }
  ' "$DISPLAY_SHELL_TOML"
}

# `key = value` from a display.conf, ignoring comments and blank lines.
conf_get() { # $1 key  $2 conf-file
  [[ -f $2 ]] || return 0
  sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\(.*\)/\1/p" "$2" \
    | head -1 | sed 's/[[:space:]]*#.*$//; s/[[:space:]]*$//'
}
