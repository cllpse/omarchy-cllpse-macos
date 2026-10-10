#!/bin/bash
# Chromium: flags, page zoom and a neutral UI, and the managed policy (sudo)
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

# See README.md (1)
_mode="${1:-all}"
_want() { [[ $_mode == all || $_mode == "$1" ]]; }

if _want user; then

# See README.md (2)
if [[ -f "$HERE/chromium/chromium-flags.conf" ]]; then
  # Ours is inside the fenced block. A copy outside it would either be passed
  # twice or, as Omarchy-era `=1` lines are, a whole number, which turns off
  # Chromium's fractional-scale fix.
  _fence="/^# >>> $MARK >>>\$/,/^# <<< $MARK <<<\$/"
  if [[ -f ~/.config/chromium-flags.conf ]] &&
     sed "${_fence}d" ~/.config/chromium-flags.conf | grep -q '^--force-device-scale-factor='; then
    sed -i "${_fence}!{/^--force-device-scale-factor=/d}" ~/.config/chromium-flags.conf
    skip "dropped a --force-device-scale-factor line outside our block (chromium/README.md (2))"
  fi
  sync_fenced ~/.config/chromium-flags.conf "$HERE/chromium/chromium-flags.conf"

# See README.md (3)
  if [[ -f ~/.config/chromium-flags.conf ]]; then
    for _switch in --enable-features --disable-features; do
      _ours="$(grep -m1 "^$_switch=" "$HERE/chromium/chromium-flags.conf" || true)"
      _stock="$(sed "/$MARK/,\$d" ~/.config/chromium-flags.conf | grep -m1 "^$_switch=" || true)"
      [[ -n $_stock ]] || continue
      _missing=""
      while IFS= read -r _feat; do
        [[ -n $_feat ]] || continue
        [[ ",${_ours#*=}," == *",$_feat,"* ]] || _missing+=" $_feat"
      done < <(tr ',' '\n' <<<"${_stock#*=}")
      [[ -n $_missing ]] &&
        skip "Omarchy's $_switch names${_missing} — add it to chromium/chromium-flags.conf or the last line wins and drops it"
    done
  fi
fi

# See README.md (4)
if [[ -x "$HERE/chromium/default-zoom.py" ]]; then
  # 100 / the UI scale in chromium-flags.conf, so page content is back at the
  # monitor scale: 105.263% for 0.95. Printed with %g, as
  # `default-zoom.py --print` reports it, so record_prior recognises the value
  # as ours on a re-run.
  _zoom="$(awk -F= '/^--force-device-scale-factor=/ { printf "%g", 100 / $2; exit }' \
    "$HERE/chromium/chromium-flags.conf")"
  [[ -n $_zoom ]] || _zoom=100
  record_prior "$STATE/previous-chromium-zoom" \
    "$("$HERE/chromium/default-zoom.py" --print 2>/dev/null || true)" "$_zoom"
  say "Chromium default page zoom -> ${_zoom}%"
  "$HERE/chromium/default-zoom.py" "$_zoom" || true
fi

# See README.md (5)
if [[ -x "$HERE/chromium/neutral-theme.py" ]]; then
# See README.md (6)
  _prev_theme="$("$HERE/chromium/neutral-theme.py" --print 2>/dev/null || true)"
  case "$_prev_theme" in st=1,gs=1|st=1,gs=) _prev_theme="" ;; esac
  record_prior "$STATE/previous-chromium-theme" "$_prev_theme" ""
  say "Chromium UI -> neutral (system theme + grayscale), not the policy's cyan"
  "$HERE/chromium/neutral-theme.py" || true
fi
fi

if _want policy; then
# See README.md (7)
if [[ -f "$HERE/chromium/policies-managed.json" &&
      -d /etc/chromium/policies/managed && ! -L /etc/chromium/policies/managed ]]; then
  dest=/etc/chromium/policies/managed/cllpse-macos.json
  if [[ -f $dest ]] && cmp -s "$HERE/chromium/policies-managed.json" "$dest"; then
    skip "Chromium managed policy already current"
  else
    say "Chromium managed policy -> $dest (sudo)"
    sudo install -m644 "$HERE/chromium/policies-managed.json" "$dest"
    if command -v chromium >/dev/null 2>&1 && pgrep -x chromium >/dev/null; then
      chromium --refresh-platform-policy --no-startup-window &>/dev/null || true
      skip "reloaded the running Chromium's managed policy (no relaunch needed)"
    fi
  fi
fi


fi
