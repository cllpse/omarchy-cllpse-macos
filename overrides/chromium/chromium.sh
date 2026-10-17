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
if [[ -x "$HERE/chromium/default-zoom.py" && -e $STATE/previous-chromium-zoom ]]; then
  # No default zoom since 2026-10-16: pages take Chromium's own 100% at the UI
  # scale above. Earlier versions of this step set one (12 x the GTK factor /
  # 13 under the 2x rendering, 105.263% for 0.95 before it) and left this state
  # file behind, so hand it back the way revert.sh does: the zoom recorded
  # before the first apply, or with nothing recorded, no key at all.
  # Preferences cannot be written while Chromium runs, so the record then stays
  # for the next run.
  if pgrep -x chromium >/dev/null; then
    skip "Chromium is running: quit it and re-run to hand back the default page zoom an earlier apply set"
  else
    _prev_zoom="$(<"$STATE/previous-chromium-zoom")"
    if [[ -n $_prev_zoom ]]; then
      say "Chromium default page zoom -> ${_prev_zoom}%, what the machine had before our first apply"
      "$HERE/chromium/default-zoom.py" "$_prev_zoom" || true
    else
      say "Chromium default page zoom -> cleared (Chromium's own 100%)"
      "$HERE/chromium/default-zoom.py" --reset || true
    fi
    rm -f "$STATE/previous-chromium-zoom"
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
