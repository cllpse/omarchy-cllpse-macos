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
fi

# See README.md (4)
if [[ -x "$HERE/chromium/default-zoom.py" ]]; then
  # Two parts, multiplied. Geometry: 100% while chromium-flags.conf disables
  # WaylandFractionalScaleV1, since the scale flag then sets the rendering
  # scale and leaves layout alone; otherwise the flag is a UI scale that pages
  # inherit, and 100 / it puts them back at the monitor scale (105.263% for
  # 0.95). Text: web body text is 16 CSS px, which macOS sets against a 13 pt
  # system font, and every app's text here is 12 px times the GTK factor that
  # step 7b's text size has just set, so 12 x factor / 13 keeps macOS's ratio:
  # 112.818% at text size 14 (factor 1.2222). Without a factor, geometry only.
  # Rounded to 3 places and printed with %g, as `default-zoom.py --print`
  # reports it, so record_prior recognises the value as ours on a re-run.
  _factor="$(gsettings get org.gnome.desktop.interface text-scaling-factor 2>/dev/null || true)"
  _zoom="$(awk -F= -v f="$_factor" '
    /^--force-device-scale-factor=/ && scale == "" { scale = $2 }
    /^--disable-features=/ && /[=,]WaylandFractionalScaleV1(,|$)/ { whole = 1 }
    END { if (scale == "") exit
          z = whole ? 100 : 100 / scale
          if (f + 0 > 0) z *= 12 * f / 13
          printf "%g", int(z * 1000 + 0.5) / 1000 }' \
    "$HERE/chromium/chromium-flags.conf")"
  [[ -n $_zoom ]] || _zoom=100
  # Earlier versions of this step set 100 (2026-10-12 to 15) and 105.263
  # (2026-10-11 to 12), so neither is the machine's own. The empty file marks
  # the first apply as done when nothing was recorded: a later text size moves
  # our own value, and without it the old one would be recorded as the
  # machine's. revert.sh reads an empty file as "nothing recorded".
  _prev_zoom="$("$HERE/chromium/default-zoom.py" --print 2>/dev/null || true)"
  case "$_prev_zoom" in 100|105.263) _prev_zoom="" ;; esac
  record_prior "$STATE/previous-chromium-zoom" "$_prev_zoom" "$_zoom"
  [[ -e $STATE/previous-chromium-zoom ]] || : >"$STATE/previous-chromium-zoom"
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
