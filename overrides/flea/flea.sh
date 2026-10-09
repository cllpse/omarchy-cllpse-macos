#!/bin/bash
# Flea as the desktop's file manager: folders, "Show in folder" and file
# dialogs, with its key on SUPER+ALT+SPACE rather than the SUPER+SHIFT+F that
# `flea --default` takes from the Cmd+Shift+F forward.
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. Installs nothing -- flea is an
# AUR package (`omarchy pkg aur add flea-bin`), configured here if present.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

DESKTOP=com.thisisgm.flea.desktop
BINDINGS=~/.config/hypr/bindings.lua
DBUS_USER=~/.local/share/dbus-1/services/org.freedesktop.FileManager1.service
DBUS_PKG=/usr/share/dbus-1/services/com.thisisgm.flea.FileManager1.service
# Flea's own provenance line, verbatim -- see README.md (3) for why it is not ours.
PROVENANCE='# Written by `flea --default`; `flea --default off` removes it.'
KEYS_BEGIN='-- flea --default: begin.'
KEYS_END='-- flea --default: end.'

# See README.md (1)
if ! command -v flea >/dev/null 2>&1 || [[ ! -f /usr/share/applications/$DESKTOP ]]; then
  skip "flea not installed — folders, Show in folder and file dialogs stay as they are"
  skip "  install it with: omarchy pkg aur add flea-bin"
  if grep -qxF -e "-- >>> $MARK: flea >>>" "$BINDINGS" 2>/dev/null; then
    skip "  SUPER+ALT+SPACE is still bound to flea from an earlier run, and does nothing"
  fi
  # The one leftover that is not inert: D-Bus does not fall through to the next
  # FileManager1 claimant when this one cannot start. See README.md (3).
  if [[ -f $DBUS_USER ]] && head -1 "$DBUS_USER" | grep -qxF -e "$PROVENANCE"; then
    _exec=$(sed -n 's/^Exec=//p' "$DBUS_USER")
    if [[ -n $_exec && ! -x $_exec ]]; then
      skip "  Show in folder is BROKEN: $DBUS_USER names $_exec, which is gone"
      skip "    delete it: rm $DBUS_USER"
    fi
  fi
  exit 0
fi

# See README.md (2)
handler=$(xdg-mime query default inode/directory 2>/dev/null || true)
record_prior "$STATE/previous-flea-handler" "$handler" ""

if [[ $handler == "$DESKTOP" ]]; then
  skip "folders already open in Flea"
else
  say "folders (inode/directory) -> Flea, was ${handler:-nothing}"
  xdg-mime default "$DESKTOP" inode/directory
  # xdg-mime default exits 0 whatever it wrote, so the answer is read back.
  now=$(xdg-mime query default inode/directory 2>/dev/null || true)
  [[ $now == "$DESKTOP" ]] ||
    skip "xdg-mime still answers '${now:-nothing}' — check ~/.config/mimeapps.list"
fi

# See README.md (3)
exec_line=$(grep -m1 '^Exec=' "$DBUS_PKG" 2>/dev/null || true)
if [[ -z $exec_line ]]; then
  skip "$DBUS_PKG is missing — Show in folder left to whichever file manager D-Bus reads first"
else
  want=$(printf '%s\n' "$PROVENANCE" '[D-BUS Service]' 'Name=org.freedesktop.FileManager1' "$exec_line")
  if [[ -f $DBUS_USER && "$(<"$DBUS_USER")" == "$want" ]]; then
    skip "Show in folder already answered by Flea"
  else
    say "Show in folder (org.freedesktop.FileManager1) -> Flea"
    # A registration of somebody else's is kept for revert.sh; flea's own,
    # pointing somewhere stale, is not worth keeping.
    if [[ -f $DBUS_USER ]] && ! head -1 "$DBUS_USER" | grep -qxF -e "$PROVENANCE"; then
      backup "$DBUS_USER"
    fi
    mkdir -p "$(dirname "$DBUS_USER")"
    printf '%s\n' "$want" >"$DBUS_USER"
  fi
fi

# See README.md (4)
# Captured rather than streamed: with its output not a terminal, flea leaves the
# portal restart to the caller, and the restart below only happens on a change.
# The `|| true` is load-bearing: with no portals.conf yet -- a fresh machine --
# cat fails, and under pipefail that silently ended the script right here.
portal_sum() { { cat ~/.config/xdg-desktop-portal/*portals.conf 2>/dev/null || true; } | md5sum; }
before=$(portal_sum)
if out=$(flea --picker 2>&1); then
  while IFS= read -r line; do
    case "$line" in
      "xdg-desktop-portal reads this at startup"* | "undo both with"*) ;;
      ?*) skip "$line" ;;
    esac
  done <<<"$out"
  if [[ $(portal_sum) != "$before" ]]; then
    if systemctl --user try-restart xdg-desktop-portal.service >/dev/null 2>&1; then
      skip "xdg-desktop-portal restarted, so file dialogs follow now"
    else
      skip "file dialogs follow once xdg-desktop-portal restarts: systemctl --user restart xdg-desktop-portal"
    fi
  fi
else
  skip "flea --picker failed — file dialogs left as they were:"
  while IFS= read -r line; do [[ -n $line ]] && skip "  $line"; done <<<"$out"
fi

# See README.md (5)
if [[ -f $BINDINGS ]] && grep -qF -e "$KEYS_BEGIN" "$BINDINGS"; then
  if ! grep -qxF -e "$KEYS_END" "$BINDINGS"; then
    skip "flea's keys block in $BINDINGS has no end marker — left alone, remove it by hand"
  else
    record_prior "$STATE/previous-flea-keys" "present" ""
    # Drops the begin..end lines and the one blank line flea put in front of
    # them; every other blank line passes through.
    tmp=$(mktemp)
    awk -v b="$KEYS_BEGIN" -v e="$KEYS_END" '
      index($0, b) == 1 { f = 1; held = 0; next }
      f                 { if ($0 == e) f = 0; next }
      held              { print ""; held = 0 }
      $0 == ""          { held = 1; next }
                        { print }
      END               { if (held) print "" }
    ' "$BINDINGS" >"$tmp"
    if [[ -s $tmp ]]; then
      # Through the original file, not mv, to keep its mode and inode.
      cat "$tmp" >"$BINDINGS"
      say "removed flea --default's keys block: SUPER+SHIFT+F is Cmd+Shift+F again"
    else
      skip "rewriting $BINDINGS came out empty — left untouched"
    fi
    rm -f "$tmp"
  fi
fi

# See README.md (6)
sync_fenced "$BINDINGS" "$HERE/flea/flea-bindings.lua" flea
