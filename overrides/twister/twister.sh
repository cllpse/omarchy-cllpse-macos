#!/bin/bash
# Midi Fighter Twister: the top-left push cycles its own LED colour, on-device.
#
# See README.md in this directory for what this does and why. Runnable on its
# own, and called by ../apply.sh (opt-in, like ryzen and dsc). $HERE is bound
# to overrides/, as in every other per-override script.
#
#   twister.sh              status; with the custom firmware on, makes sure
#                           bank 4's top-left switch has the colour-cycle action
#   twister.sh build        clone the firmware at the pinned commit, apply the
#                           patch, build -> ~/.cache/cllpse-macos/twister/build/
#   twister.sh flash        back the settings up, jump the Twister into its DFU
#                           bootloader, flash (sudo), restore the settings
#   twister.sh backup       every setting -> $STATE/twister-config-<stamp>.txt
#   twister.sh restore F    replay such a file
#   twister.sh set [TAG] [ACTION]   one switch's action; default 31 10
#   twister.sh switches ACTION [BANK]  the switch action on all 16 encoders of a bank (default 4)
#   twister.sh rotation on|off [BANK]  the LED colour follows the knob, all 16
#                           encoders of a bank (default 4)
#   twister.sh indicators dot|bar|blend|spread [BANK]  the ring's display type, all 16
#   twister.sh --revert     the switch back to CC Hold; the firmware stays
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"
T="$HERE/twister"
SYSEX="$T/twister-sysex"
CACHE="$HOME/.cache/cllpse-macos/twister"
UPSTREAM=https://github.com/DJ-TechTools/Midi_Fighter_Twister_Open_Source
PIN=782f9533b01d4513aa7da4aa789250b7fd69a44b   # 2026-08-24, what the patch applies to
OURS=2026-08-24                                # DEVICE_VERSION of that source, what our build reports
TAG=31      # hex, 1-based: bank*16 + encoder + 1 -> bank 4, encoder 0 (top-left)
ACTION=10   # SW_COLOR_TOGGLE (its first name): a press plays the next animation; 9 = SW_COLOR_CYCLE, the palette cycle

present() { grep -q '"Midi Fighter Twister"' /proc/asound/seq/clients 2>/dev/null; }
fw_date() { timeout 5 "$SYSEX" version 2>/dev/null || true; }
# the switch action of one encoder: field 0x0C of its pull reply
action_of() { # $1 hex tag
  timeout 5 "$SYSEX" send "F0 00 01 79 04 01 $1 F7" --wait 1 2>/dev/null \
    | awk '/^F0 00 01 79 04 00 .. 01 /{for(i=11;i<NF;i+=2) if($i=="0C") print $(i+1)}'
}
# any field of one encoder's pull reply, by its hex tag (0A..19)
field_of() { # $1 hex tag  $2 hex field
  timeout 5 "$SYSEX" send "F0 00 01 79 04 01 $1 F7" --wait 1 2>/dev/null \
    | awk -v f="$2" '/^F0 00 01 79 04 00 .. 0[12] /{for(i=11;i<NF;i+=2) if($i==f) print $(i+1)}'
}
stamp() { date +%Y-%m-%d-%H%M%S; }

cmd=${1:-status}
case $cmd in
  status)
    if ! present; then skip "no Midi Fighter Twister on the sequencer"; exit 0; fi
    fw=$(fw_date); act=$(action_of "$TAG"); rot=$(field_of "$TAG" 19); ind=$(field_of "$TAG" 16)
    say "Twister firmware $fw; bank 4 top-left: switch action ${act:-?} (0A = animation on press, 09 = colour cycle), colour from rotation ${rot:-?}"
    if [[ $fw != "$OURS" ]]; then
      skip "not the custom build: twister.sh build, then twister.sh flash (sudo)"
    else
      [[ $act == 0A ]] || "$0" switches "$ACTION" 4
      [[ $rot == 01 ]] || "$0" rotation on 4
      [[ $ind == 02 ]] || "$0" indicators blend 4
      skip "bank 4: every knob's turn sets its LED colour, every push plays an animation (every third one on all sixteen); blended-bar indicators"
    fi
    ;;
  build)
    command -v avr-gcc >/dev/null && command -v make >/dev/null \
      || { skip "avr-gcc missing — sudo pacman -S avr-gcc avr-libc dfu-programmer"; exit 1; }
    mkdir -p "$CACHE"
    if [[ ! -d $CACHE/repo/.git ]]; then
      say "cloning the firmware source into $CACHE/repo"
      git clone -q "$UPSTREAM" "$CACHE/repo"
    fi
    git -C "$CACHE/repo" fetch -q origin
    git -C "$CACHE/repo" checkout -q --force "$PIN"
    git -C "$CACHE/repo" apply "$T/color-cycle.patch"
    cp "$T/Makefile.linux" "$CACHE/repo/Makefile.linux"
    say "building (avr-gcc $(avr-gcc -dumpversion))"
    make -C "$CACHE/repo" -f Makefile.linux -j"$(nproc)" >"$CACHE/build.log" 2>&1 \
      || { tail -20 "$CACHE/build.log"; echo "build failed — $CACHE/build.log" >&2; exit 1; }
    say "built $CACHE/repo/build/twister.hex ($(avr-size "$CACHE/repo/build/twister.hex" | awk 'NR==2{print $4}') bytes)"
    ;;
  flash)
    hex="$CACHE/repo/build/twister.hex"
    [[ -s $hex ]] || { skip "nothing built: twister.sh build first"; exit 1; }
    command -v dfu-programmer >/dev/null || { skip "dfu-programmer missing — sudo pacman -S dfu-programmer"; exit 1; }
    present || { skip "no Midi Fighter Twister on the sequencer"; exit 1; }
    bak="$STATE/twister-config-$(stamp).txt"
    "$SYSEX" pull-all >"$bak"
    say "settings backed up to $bak ($(grep -c '^F0' "$bak") messages)"
    say "jumping the Twister into its bootloader"
    "$SYSEX" bootloader
    for _ in $(seq 1 20); do sleep 0.5; sudo dfu-programmer atxmega128a4u get 2>/dev/null | grep -q . && break; done
    sudo dfu-programmer atxmega128a4u get >/dev/null || { echo "no DFU device (03eb:2fde) appeared" >&2; exit 1; }
    sudo dfu-programmer atxmega128a4u erase --force
    sudo dfu-programmer atxmega128a4u flash "$hex"
    sudo dfu-programmer atxmega128a4u launch
    for _ in $(seq 1 30); do sleep 0.5; present && break; done
    present || { echo "the Twister did not come back as MIDI — unplug and replug it" >&2; exit 1; }
    sleep 1
    say "firmware now $(fw_date)"
    # A layout-version change in EEPROM makes the new firmware factory-reset
    # itself (eeprom_init); the backup puts everything back.
    now="$STATE/twister-config-check.txt"; "$SYSEX" pull-all >"$now"
    if ! diff -q <(grep '^F0 00 01 79 04' "$bak" | sed 's/ 40 \(0[12]\) / 00 \1 /') <(grep '^F0 00 01 79 04' "$now") >/dev/null; then
      say "settings were reset by the new firmware — restoring from the backup"
      "$SYSEX" restore "$bak" >/dev/null
    fi
    rm -f "$now"
    "$0" set "$TAG" "$ACTION"
    ;;
  backup)
    f="$STATE/twister-config-$(stamp).txt"; "$SYSEX" pull-all >"$f"; say "wrote $f"
    ;;
  restore)
    "$SYSEX" restore "${2:?backup file}"
    ;;
  set)
    tag=${2:-$TAG}; action=${3:-$ACTION}
    "$SYSEX" set-action "$tag" "$action" >/dev/null
    act=$(action_of "$tag")
    [[ $act == $(printf '%02X' "$action") ]] && say "switch $tag: action $act" || { echo "switch $tag reads back action ${act:-?}, wanted $action" >&2; exit 1; }
    ;;
  switches)
    action=${2:?action}; bank=${3:-4}
    tags=$(for e in $(seq 0 15); do printf '%02X,' $(( (bank-1)*16 + e + 1 )); done); tags=${tags%,}
    got=$("$SYSEX" set-field "$tags" 12 "$action" | awk '/^F0 00 01 79 04 00 .. 01 /{for(i=11;i<NF;i+=2) if($i=="0C") print $(i+1)}' | sort -u | tr '\n' ' ')
    [[ $got == "$(printf '%02X ' "$action")" ]] && say "bank $bank: switch action $action on all 16 encoders" \
      || { echo "bank $bank reads back action: ${got:-nothing} (wanted $action on 16)" >&2; exit 1; }
    ;;
  indicators)
    case ${2:?dot|bar|blend|spread} in dot) v=0;; bar) v=1;; blend) v=2;; spread) v=3;; *) echo "indicators: dot|bar|blend|spread" >&2; exit 2;; esac
    bank=${3:-4}
    tags=$(for e in $(seq 0 15); do printf '%02X,' $(( (bank-1)*16 + e + 1 )); done); tags=${tags%,}
    got=$("$SYSEX" set-field "$tags" 22 "$v" | awk '/^F0 00 01 79 04 00 .. 02 /{for(i=11;i<NF;i+=2) if($i=="16") print $(i+1)}' | sort -u | tr '\n' ' ')
    [[ $got == "$(printf '%02X ' "$v")" ]] && say "bank $bank: indicators = $2 on all 16 encoders" \
      || { echo "bank $bank reads back field 22 as: ${got:-nothing} (wanted $v on 16)" >&2; exit 1; }
    ;;
  rotation)
    state=${2:?on|off}; bank=${3:-4}; v=0; [[ $state == on ]] && v=1
    tags=$(for e in $(seq 0 15); do printf '%02X,' $(( (bank-1)*16 + e + 1 )); done); tags=${tags%,}
    got=$("$SYSEX" set-field "$tags" 25 "$v" | awk '/^F0 00 01 79 04 00 .. 02 /{for(i=11;i<NF;i+=2) if($i=="19") print $(i+1)}' | sort -u | tr '\n' ' ')
    [[ $got == "$(printf '%02X ' "$v")" ]] && say "bank $bank: colour follows rotation = $state on all 16 encoders" \
      || { echo "bank $bank reads back field 25 as: ${got:-nothing} (wanted $v on 16)" >&2; exit 1; }
    ;;
  --revert)
    if present; then "$0" switches 0 4; "$0" rotation off 4; else skip "no Twister attached — nothing to put back"; fi
    skip "the custom firmware stays; the official hex and how to flash it are in twister/README.md"
    ;;
  *) echo "usage: twister.sh [status|build|flash|backup|restore FILE|set [TAG] [ACTION]|--revert]" >&2; exit 2 ;;
esac
