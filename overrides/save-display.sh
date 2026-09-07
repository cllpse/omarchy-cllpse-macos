#!/bin/bash
# Capture the machine's current display scaling + text size into display.conf,
# which apply.sh restores. Run this after tuning either by hand (or through
# `omarchy display text size`) to make the change the new saved state.
#
# Only the two scale VARIABLES are captured, never monitor topology: output
# names, modes and positions stay whatever each machine's monitors.lua says.
# `omarchy_monitor_scale` / `omarchy_gdk_scale` are stock Omarchy variables --
# they exist in the shipped monitors.lua template -- and the per-monitor
# hl.monitor() lines reference them, so setting them scales every output
# without pinning this machine's hardware into the repo.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$HERE/display.conf"

# shellcheck source=overrides/display-lib.sh
source "$HERE/display-lib.sh"

say() { printf '\033[34m▸\033[0m %s\n' "$*"; }

monitor_scale="$(read_scale omarchy_monitor_scale)"
gdk_scale="$(read_scale omarchy_gdk_scale)"
text_size="$(read_text_size)"

[[ -n $monitor_scale ]] || monitor_scale='"auto"'   # the stock default
[[ -n $gdk_scale ]]     || gdk_scale=2              # the stock default
[[ -n $text_size ]]     || text_size=12             # the stock default

cat >"$CONF" <<EOF
# Saved display scaling + text size, restored by apply.sh.
# Regenerate from the live machine with: ./overrides/save-display.sh
#
# These are the AUTHOR'S values, tuned for a 3840x1600 display. They are a
# preference, not part of the macOS look -- if you are not on similar hardware,
# edit this file (or re-run save-display.sh on your own machine) before
# applying. apply.sh skips any key left empty.
#
#   text-size      px, 9-20. The shell's rem root; 'omarchy display text size'
#                  drives it together with the GTK text-scaling-factor and the
#                  terminal point size, all anchored to 12px.
#   monitor-scale  Hyprland output scale -- a number, or "auto".
#   gdk-scale      integer GDK_SCALE for XWayland/GTK apps.

text-size = $text_size
monitor-scale = $monitor_scale
gdk-scale = $gdk_scale
EOF

say "saved -> overrides/display.conf"
printf '    text-size     %s\n    monitor-scale %s\n    gdk-scale     %s\n' \
  "$text_size" "$monitor_scale" "$gdk_scale"
