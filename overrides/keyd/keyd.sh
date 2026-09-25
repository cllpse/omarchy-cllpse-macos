#!/bin/bash
# keyd: identity config + Figma modifier remap (sudo)
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/
# (not this folder), so every path below reads exactly as it did when this
# lived in apply.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

KEYD_CONF=/etc/keyd/default.conf
KEYD_DROPIN=/etc/systemd/system/keyd.service.d/restart.conf

# See README.md (1)
if command -v keyd >/dev/null 2>&1; then
  say "keyd -> ~/.local/bin/cllpse-figma-keyd + $KEYD_CONF (sudo)"
  mkdir -p ~/.local/bin
  install -m755 "$HERE/keyd/cllpse-figma-keyd" ~/.local/bin/cllpse-figma-keyd

# See README.md (2)
  if [[ -e $KEYD_CONF ]] && ! head -1 "$KEYD_CONF" | grep -q 'installed by overrides/apply.sh'; then
    skip "$KEYD_CONF exists and is not ours — left alone"
    skip "  merge overrides/keyd/default.conf by hand, or move yours aside and re-run"
  elif ! keyd check "$HERE/keyd/default.conf" >/dev/null 2>&1; then
# See README.md (3)
    skip "overrides/keyd/default.conf does not parse — left /etc alone. Run:"
    skip "  keyd check overrides/keyd/default.conf"
  else
# See README.md (4)
    # The restart drop-in goes in FIRST, so the policy is already in force for
    # the restart below it. Gated on a real difference because daemon-reload is
    # not free and a no-op run of this script should touch nothing.
    if cmp -s "$HERE/keyd/keyd.service.d/restart.conf" "$KEYD_DROPIN"; then
      skip "keyd.service restart drop-in already current"
    elif sudo install -Dm644 "$HERE/keyd/keyd.service.d/restart.conf" "$KEYD_DROPIN" \
      && sudo systemctl daemon-reload; then
      skip "installed $KEYD_DROPIN — a keyd segfault now self-heals"
    else
      skip "could not install $KEYD_DROPIN — a keyd crash will stay down"
    fi

# See README.md (5)
    # Publish ONLY on a real change. keyd re-reads default.conf at start and on
    # reload and at no other time, so this is the step that publishes an edit —
    # but an unchanged file needs no publishing, and poking the daemon anyway is
    # what made every idempotent re-run of apply.sh a roll of the dice against
    # the segfault above. Measured: default.conf has changed three times ever,
    # against FIFTEEN reloads in the journal, so at least twelve of them
    # published nothing at all. Counting probe is in README.md (5).
    #
    # The install is GUARDED, unlike every earlier version of this line. With
    # `set -e` a bare `sudo install` that cannot get a password takes the whole
    # script down where it stands -- so the group grant, the daemon start and
    # the smoke test below never run, and the only output is sudo's own error
    # with nothing naming the step it killed. Measured the first time this ran
    # from a session with no TTY. Every other sudo here already degraded to a
    # skip line; this one now matches, and the smoke test at the end gets to
    # report what the chain actually looks like.
    if cmp -s "$HERE/keyd/default.conf" "$KEYD_CONF"; then
      skip "$KEYD_CONF already current — daemon left undisturbed"
    elif ! sudo install -Dm644 "$HERE/keyd/default.conf" "$KEYD_CONF"; then
      skip "could not write $KEYD_CONF — the [figma:C] layer is NOT published"
      skip "  re-run with sudo available: bash overrides/keyd/keyd.sh"
    else
      sudo systemctl restart keyd >/dev/null 2>&1 \
        && skip "published keyd/default.conf and restarted the daemon" \
        || skip "could not restart keyd — run: sudo systemctl restart keyd"
    fi

# See README.md (6)
    # reset-failed before starting, or a unit that exhausted the drop-in's start
    # limit refuses to come up and the step reports a failure it could have
    # cleared. Unconditional, so it also covers "config unchanged, daemon dead" —
    # exactly the state this machine sat in for two days.
    sudo systemctl reset-failed keyd >/dev/null 2>&1 || true
    sudo systemctl enable --now keyd >/dev/null 2>&1 \
      && skip "keyd service enabled and running" \
      || skip "could not start keyd — run: sudo systemctl enable --now keyd"
  fi

# See README.md (7)
  if id -nG | tr ' ' '\n' | grep -qx keyd; then
    skip "already in the keyd group"
  else
    sudo usermod -aG keyd "$USER" \
      && skip "added $USER to the keyd group — this session reaches it via newgrp" \
      || skip "could not add $USER to the keyd group — run: sudo usermod -aG keyd $USER"
  fi

# See README.md (8)
  if [[ -x ~/.local/bin/cllpse-figma-keyd ]] && command -v keyd >/dev/null 2>&1; then
    # `off` is attempted even when `on` failed, so a half-completed test cannot
    # leave leftmeta bound. And the daemon is checked AFTER both, because a bind
    # that returns 0 proves only that keyd was alive when it answered: on
    # 2026-09-22 this test printed success at 17:27:24 and keyd dumped core at
    # 17:27:27. A smoke test that cannot observe the thing it just crashed is
    # the repo's own recurring bug, not a new one.
    #
    # Liveness is checked BEFORE as well as after, and the first check is not
    # redundant: without it a daemon that was already dead going in fails the
    # after-check and gets reported as "the bind was accepted and then it
    # crashed" -- a precise claim about a mechanism that did not occur. Caught
    # by running this step against exactly that state. `died` now means what it
    # says: keyd was up, it took the bind, and it fell over.
    if ! systemctl is-active --quiet keyd; then
      skip "keyd is not running — the Figma remap has nothing to bind against"
      skip "  start it: sudo systemctl enable --now keyd"
    else
      smoke=ok
      ~/.local/bin/cllpse-figma-keyd on  >/dev/null 2>&1 || smoke=bind
      ~/.local/bin/cllpse-figma-keyd off >/dev/null 2>&1 || smoke=bind
      systemctl is-active --quiet keyd                   || smoke=died

      case $smoke in
        ok)   skip "Figma remap reaches keyd (layer bound, released, daemon still up)" ;;
        bind) skip "the Figma remap could NOT be bound — run it by hand to see why:"
              skip "  ~/.local/bin/cllpse-figma-keyd on" ;;
        died) skip "keyd DIED during the smoke test — it was up, it took the bind,"
              skip "  and it crashed. The drop-in should have restarted it; check:"
              skip "  systemctl status keyd && coredumpctl list keyd" ;;
      esac
    fi
  fi
else
  skip "keyd not installed — Figma keeps Ctrl+click / Ctrl+scroll on the pinky"
  skip "  install it with: sudo pacman -S keyd, then re-run this script"
fi
