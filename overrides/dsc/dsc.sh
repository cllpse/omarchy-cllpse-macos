#!/bin/bash
# DSC bit rate on the TV's link (sudo)
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh only when asked for: the step
# is opt-in, so --all skips it. $HERE is bound to overrides/ (not this folder),
# so paths below read as they would in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

# See README.md (1)
# shellcheck source=overrides/dsc/cllpse-dsc.env
source "$HERE/dsc/cllpse-dsc.env"
_dsc_tv=""
for _d in /sys/class/drm/card*-*; do
  [[ -r $_d/edid && $(<"$_d/status") == connected ]] || continue
  _card=${_d##*/}; _card=${_card%%-*}
  [[ $(readlink -f "/sys/class/drm/$_card/device/driver" 2>/dev/null) == */amdgpu ]] || continue
  read -ra _b < <(od -An -tu1 -j8 -N4 "$_d/edid")
  (( ${#_b[@]} == 4 )) || continue
  _v=$(( _b[0] << 8 | _b[1] )); _id=""
  for _c in 10 5 0; do _id+=$(printf "\\$(printf %03o $(( ((_v >> _c) & 31) + 64 )))"); done
  [[ "$_id:$(( _b[2] | _b[3] << 8 ))" == "$DSC_EDID" ]] && { _dsc_tv=${_d##*/}; break; }
done
_dsc_adapter=0
for _d in /sys/bus/usb/devices/*; do
  [[ -r $_d/idVendor && "$(<"$_d/idVendor"):$(<"$_d/idProduct")" == "$DSC_ADAPTER_USB" ]] && { _dsc_adapter=1; break; }
done

if [[ -z $_dsc_tv ]]; then
  skip "DSC bit rate skipped — no amdgpu output shows the TV it was measured on ($DSC_EDID, the Samsung QN90F's HDMI 2.1 EDID)"
elif (( ! _dsc_adapter )); then
  skip "DSC bit rate skipped — the TV is on ${_dsc_tv#*-}, but not behind the VMM7100 adapter ($DSC_ADAPTER_USB) whose decoder it was tested on"
else
  _dsc_changed=0
  for _spec in "dsc/cllpse-dsc-bpp:/usr/local/bin/cllpse-dsc-bpp:755" \
               "dsc/cllpse-dsc.env:/etc/default/cllpse-dsc:644" \
               "dsc/cllpse-dsc.service:/etc/systemd/system/cllpse-dsc.service:644"; do
    IFS=: read -r _src _dst _mode <<<"$_spec"
    if [[ -f $_dst ]] && cmp -s "$HERE/$_src" "$_dst"; then
      skip "$(basename "$_dst") already current"
    else
      say "DSC bit rate -> $_dst (sudo)"
      sudo install -m"$_mode" -o root -g root "$HERE/$_src" "$_dst"
      _dsc_changed=1
    fi
  done
  (( _dsc_changed )) && sudo systemctl daemon-reload

# See README.md (2)
  sudo systemctl enable cllpse-dsc.service >/dev/null 2>&1 || true
  say "setting it now — the TV blanks for a moment while the link re-modesets"
  sudo systemctl restart cllpse-dsc.service
  for _i in $(seq 20); do
    systemctl is-active --quiet cllpse-dsc.service || break
    sleep 1
  done
  if systemctl is-active --quiet cllpse-dsc.service; then
    skip "still waiting for a mode the rate fits (4K100/4K120); it applies itself once there"
  else
    sudo /usr/local/bin/cllpse-dsc-bpp status | while IFS= read -r _l; do skip "$_l"; done
  fi
fi
