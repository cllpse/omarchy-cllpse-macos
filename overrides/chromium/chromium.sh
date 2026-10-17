#!/bin/bash
# Chromium: flags, page zoom, a neutral UI and the profile avatar, and the
# managed policy (sudo)
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

# See README.md (2)
  # The UI scale is two odd 17ths under the one nearest the GTK factor, which
  # Chromium rounds to 64ths, and it moves by hand with the text size: say so
  # when step 7b's text size has moved the factor away from it.
  _scale="$(grep -m1 '^--force-device-scale-factor=' "$HERE/chromium/chromium-flags.conf" | cut -d= -f2)"
  _factor="$(gsettings get org.gnome.desktop.interface text-scaling-factor 2>/dev/null || true)"
  if [[ -n $_scale && -n $_factor ]]; then
    read -r _have _want < <(awk -v s="$_scale" -v f="$_factor" 'BEGIN {
      g = int(f * 64 + 0.5) / 64; w = 1
      for (n = 1; n <= 61; n += 2) if ((n / 17 - g) ^ 2 < (w / 17 - g) ^ 2) w = n
      printf "%d %d\n", int(s * 17 + 0.5), w - 4 }')
    [[ $_have == "$_want" ]] ||
      skip "chromium-flags.conf's UI scale is $_have/17 but the text size asks for $_want/17: update it (chromium/README.md (2))"
  fi
fi

# See README.md (4)
if [[ -x "$HERE/chromium/default-zoom.py" ]]; then
  # Pages at 1.5 device px per CSS px: 150 / the UI scale in
  # chromium-flags.conf, 110.87% at 23/17. At that 3:2 ratio a resampled image
  # or a 1px line repeats every 3 device px; at the UI scale's own 1.3529 it
  # beat against the pixel grid (test pattern, 2026-10-17). Rounded up to 3
  # places, so the ratio lands just over 1.5 rather than under it, and printed
  # with %g, as `default-zoom.py --print` reports it, so record_prior
  # recognises the value as ours on a re-run.
  _zoom="$(awk -F= '/^--force-device-scale-factor=/ {
      z = 150 / $2 * 1000; r = int(z); if (r < z) r++
      printf "%g", r / 1000; exit }' "$HERE/chromium/chromium-flags.conf")"
  if [[ -n $_zoom ]]; then
    # Earlier versions of this step set 100, 105.263 and 12 x the GTK factor /
    # 13 (102.563 to 143.594), so none of those is the machine's own. The
    # empty file marks the first apply as done when nothing was recorded, and
    # revert.sh reads it as "nothing recorded". Preferences cannot be written
    # while Chromium runs: it rewrites them from memory on exit.
    if pgrep -x chromium >/dev/null; then
      skip "Chromium is running: quit it and re-run to set the default page zoom to ${_zoom}%"
    else
      _prev_zoom="$("$HERE/chromium/default-zoom.py" --print 2>/dev/null || true)"
      case "$_prev_zoom" in 100|105.263|102.563|112.818|133.329|143.594) _prev_zoom="" ;; esac
      record_prior "$STATE/previous-chromium-zoom" "$_prev_zoom" "$_zoom"
      [[ -e $STATE/previous-chromium-zoom ]] || : >"$STATE/previous-chromium-zoom"
      say "Chromium default page zoom -> ${_zoom}%, pages at 1.5 device px per CSS px"
      "$HERE/chromium/default-zoom.py" "$_zoom" || true
    fi
  fi
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

# See README.md (8)
if [[ -f "$HERE/chromium/avatar.png" ]]; then
  # Built-in avatar 55's picture. Chromium reads it at launch and downloads it
  # only when it is missing, so ours stays; safe to write while it runs.
  _avatar=~/.config/chromium/Avatars/avatar_abstract_sandwich.png
  if cmp -s "$HERE/chromium/avatar.png" "$_avatar"; then
    skip "Chromium profile avatar already current"
  else
    say "Chromium profile avatar -> $_avatar (shows after a Chromium restart)"
    mkdir -p "${_avatar%/*}"
    cp "$HERE/chromium/avatar.png" "$_avatar.tmp"
    mv -f "$_avatar.tmp" "$_avatar"
  fi
  _others="$(jq -r '.profile.info_cache // {} | to_entries[]
      | select(.value.avatar_icon != "chrome://theme/IDR_PROFILE_AVATAR_55") | .key' \
    ~/.config/chromium/"Local State" 2>/dev/null | paste -sd, - || true)"
  if [[ -n $_others ]]; then
    skip "another avatar is chosen in $_others: pick the abstract sandwich in Customize profile to show ours"
  fi
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
