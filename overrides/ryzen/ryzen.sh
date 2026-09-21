#!/bin/bash
# CPU power limits (sudo)
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

# See README.md (1)
_ryzen_cpu="$(grep -m1 'model name' /proc/cpuinfo || true)"
_ryzen_product="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"
_ryzen_vendor="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
if [[ $_ryzen_cpu != *8745HS* || $_ryzen_vendor != GEEKOM || $_ryzen_product != A8 ]]; then
  skip "CPU power limits skipped — tuned for a Ryzen 7 8745HS in a Geekom A8, this is${_ryzen_cpu:+ ${_ryzen_cpu#*: }}"
elif ! command -v ryzenadj >/dev/null 2>&1; then
  skip "ryzenadj missing — CPU stays at the firmware's 45W (yay -S ryzenadj, then re-run)"
else
  _tdp_changed=0
  for _pair in "ryzen/ryzen-tdp.env:/etc/default/ryzen-tdp" \
               "ryzen/ryzen-tdp.service:/etc/systemd/system/ryzen-tdp.service"; do
    _src="$HERE/${_pair%%:*}"; _dst="${_pair#*:}"
    if [[ -f $_dst ]] && cmp -s "$_src" "$_dst"; then
      skip "$(basename "$_dst") already current"
    else
      say "CPU power limits -> $_dst (sudo)"
      sudo install -m644 -o root -g root "$_src" "$_dst"
      _tdp_changed=1
    fi
  done

  (( _tdp_changed )) && sudo systemctl daemon-reload

# See README.md (2)
  sudo systemctl enable --now ryzen-tdp.service >/dev/null 2>&1 || true
  if [[ -r /sys/kernel/ryzen_smu_drv/pm_table ]]; then
    _tdp_live="$(python3 -c "
import struct
f = struct.unpack('<6f', open('/sys/kernel/ryzen_smu_drv/pm_table','rb').read()[:24])
print('%.0fW sustained, %.0fW burst' % (f[0], f[2]))" 2>/dev/null || true)"
    [[ -n $_tdp_live ]] && skip "SMU reports ${_tdp_live}"
  else
    skip "ryzen_smu not loaded — limits set, but nothing to read them back from"
  fi
fi

