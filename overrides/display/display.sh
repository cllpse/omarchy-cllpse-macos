#!/bin/bash
# Display scaling + text size
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so paths below read as they did in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

# See README.md
if [[ -f "$HERE/display/display.conf" ]]; then
  # shellcheck source=overrides/display/display-lib.sh
  source "$HERE/display/display-lib.sh"

  want_text="$(conf_get text-size "$HERE/display/display.conf")"
  want_mon="$(conf_get monitor-scale "$HERE/display/display.conf")"
  want_gdk="$(conf_get gdk-scale "$HERE/display/display.conf")"

  # Record the machine's own values once, so revert.sh can put them back.
  record_prior "$STATE/previous-text-size"     "$(read_text_size)"                  "$want_text"
  record_prior "$STATE/previous-monitor-scale" "$(read_scale omarchy_monitor_scale)" "$want_mon"
  record_prior "$STATE/previous-gdk-scale"     "$(read_scale omarchy_gdk_scale)"     "$want_gdk"

  if [[ -n $want_text && "$(read_text_size)" != "$want_text" ]]; then
    say "omarchy display text size $want_text  (shell + GTK factor + terminals)"
    omarchy display text size "$want_text" >/dev/null 2>&1 || true
  else
    skip "text size already $want_text"
  fi

  for pair in "omarchy_monitor_scale:$want_mon" "omarchy_gdk_scale:$want_gdk"; do
    var="${pair%%:*}"; val="${pair#*:}"
    [[ -n $val ]] || continue
    if [[ "$(read_scale "$var")" == "$val" ]]; then
      skip "$var already $val"
    elif write_scale "$var" "$val"; then
      say "$var -> $val  (monitors.lua; takes effect on the next Hyprland reload)"
    else
      skip "$var not found in ~/.config/hypr/monitors.lua — left alone"
    fi
  done
fi
