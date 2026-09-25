# keyd

An identity config plus the Figma modifier remap. Needs sudo, so it runs late.

## 1. The FIRST package this script has ever depended

The FIRST package this script has ever depended on, and the first system
daemon -- worth stating plainly, because until now apply.sh installed nothing
and needed root for exactly one file. It is not installed here either: keyd
has to be present already, and this step configures it or says why it cannot.

What it is for: Figma checks ctrlKey for deep-select (Cmd+click), canvas zoom
(Cmd+scroll) and its shortcuts, and ignores metaKey off macOS. The forwarder
in macos-shortcuts.lua covers the keys by synthesizing Ctrl, but hl.dsp has no
pointer-button or scroll-axis dispatcher, so click and scroll cannot be
translated at the compositor at all. Remapping the key below the compositor is
the only mechanism left. See that file's own block for the measurements.

Nothing here remaps anything by itself. default.conf is identity-only and
pinned to the Preonic alone (the `*` wildcard would have swept in three
Pulsar 8K dongle interfaces the kernel calls keyboards); the remap exists
solely as a runtime `keyd bind` issued on focus, and dies with the daemon.

## 2. Never clobber a keyd config this repo did

Never clobber a keyd config this repo did not write. A machine may already
be remapping keys for reasons that have nothing to do with us, and silently
replacing that file would be the worst thing this script could do to a
keyboard. Ours is recognised by its first line.

## 3. Validated BEFORE it is handed to /etc

Validated BEFORE it is handed to /etc, because the daemon is the one
thing here that a bad file takes down: keyd exits on a parse error and
exits holding no device, so the failure is a keyboard that has stopped
being remapped rather than a message. `keyd check` needs no root and
prints the offending line.

## 4. The packaged unit has NO restart policy

The packaged unit has NO restart policy, so a keyd segfault is permanent, and
this repo installs `/etc/systemd/system/keyd.service.d/restart.conf` to fix
that. `/usr/lib/systemd/system/keyd.service` is four lines -- `Type=simple`,
`ExecStart=/usr/bin/keyd`, nothing else -- and keyd 2.6.0-5 dumped core here
twice in four days (2026-09-19 19:54:33 and 2026-09-22 17:27:27), both times
within seconds of a config reparse and with a byte-identical stack. The second
one was not noticed for two days and twenty hours.

Nothing about it was loud, by construction. `default.conf` is identity-only, so
**a dead keyd is a stock keyboard** -- the only thing lost is the runtime
`leftmeta = layer(figma)` bind, i.e. Cmd+click and Cmd+scroll in Figma and
nothing else anywhere. There is no symptom until you next reach for a Figma
gesture.

The drop-in's own comments carry the reasoning for `RestartSec=1` and for the
five-in-sixty start limit; the short version is that an unbounded
`Restart=on-failure` would turn a config keyd genuinely cannot survive into a
silent respawn loop that looks exactly like a working service. Past the limit
the unit sits in `failed`, and the helper's notification is the backstop --
which is correctly scoped rather than lazy: it fires when Figma takes focus,
which is the only moment a missing remap costs anything.

Installed before anything else here touches the daemon, so the policy is
already in force for the restart below, and gated on a real difference because
`systemctl daemon-reload` is not free.

## 5. Published ONLY when the file actually changed

Published ONLY when the file actually changed. keyd re-reads `default.conf` at
start and on reload and at no other time, so this step is still the one thing
that publishes an edit to `overrides/keyd/default.conf` -- but an unchanged
file needs no publishing, and poking the daemon regardless is what made every
idempotent re-run of `apply.sh` a roll of the dice against the crash above.
Measured: `default.conf` has changed **three times ever** (2026-09-12 ×2,
2026-09-23), against **fifteen** reloads in the journal — so at least twelve
published nothing and existed only to be a chance to crash. Two of the fifteen
did. Re-run the count with:

```bash
journalctl -u keyd --no-pager -o short-iso \
| grep -E "CONFIG: parsing|Started key remapping" \
| awk '/Started key remapping/ { started=1; next }
       /CONFIG: parsing/ { if (started) { starts++; started=0 }
                           else { reloads++; print "reload: " $1 } }
       END { print "starts: " starts "  reloads: " reloads }'
```

A bare count of `CONFIG: parsing` is **not** that number — keyd logs the same
line at startup, and here 14 of the 29 were starts.

And it is a `systemctl restart`, not the `keyd reload` this step used to
prefer. That preference had two good reasons and neither survives here: reload
needs no root, but this step is already in a sudo context by the time it runs;
and reload does not interrupt the grab, but `apply.sh` step 8c reloads Hyprland
straight afterwards anyway, precisely so `macos-shortcuts.lua` re-seeds against
the daemon this step restarted. A restart is also a fresh process rather than
an in-place reparse, which sidesteps the path both crashes came out of --
**that last part is a hypothesis, not a measurement.** Both crashes followed a
reparse within seconds, but only 2 of 15 reloads crashed, so the trigger is
unconfirmed. The change is taken because it costs nothing, not because it is
proven.

`systemctl reload` was never an option either way: the unit has no
`ExecReload`, so `systemctl show keyd -p CanReload` says `no` and the request
only ever fails.

## 6. `reset-failed` before starting

`reset-failed` before starting, or a unit that exhausted the drop-in's start
limit refuses to come up and this step reports a failure it could have cleared
itself. It runs unconditionally, which also covers the state this machine
actually sat in for two days: config unchanged, nothing to publish, daemon
dead. Without it the gate in (5) would correctly decide there was nothing to
do and leave a corpse running nothing.

## 7. `keyd bind` talks to a root-owned socket whose

`keyd bind` talks to a root-owned socket whose group is keyd, so the user
has to be in that group for the focus hook to work without sudo.

A grant does NOT reach the running desktop, and "log out and back in" is
not the fix it looks like. uwsm starts Hyprland as a unit of the systemd
user manager, and with logind's stock `KillUserProcesses=no` that manager
survives a logout -- so every process on the desktop keeps inheriting the
group set the manager was created with. Measured on this machine: two full
graphical logins after the grant, Hyprland's /proc/<pid>/status still read
`Groups: 998 1000`. A reboot is what reseeds it.

Which is why the helper does not wait for one: cllpse-figma-keyd falls back
to `newgrp`, setuid-root and reading /etc/group directly, so the remap works
in this session. The group is still granted, because it is what makes the
fast path (a plain `keyd bind`) work from the next boot on.

## 8. Smoke-test the whole chain

Smoke-test the whole chain, because every link in it fails SILENTLY and the
symptom is at the far end -- Cmd+scroll in Figma simply keeps not zooming.
One `on` proves three things at once: the installed config parsed, it
defines the `figma` layer, and this user can reach keyd's socket. Cheap,
~3ms, and it is the check that was missing when /etc/keyd/default.conf sat
a revision behind the repo for half an hour: the layer had been added to
overrides/keyd/default.conf but never installed, so the focus handler's
`keyd bind 'leftmeta = layer(figma)'` answered `figma is not a valid layer`
and exited 255 into hl.dsp.exec_raw, which discards stderr. Nothing
anywhere said so until the gesture was tried.

Three things about its shape. `off` is attempted **even when `on` failed**, so
a half-completed test cannot walk away leaving leftmeta bound. The daemon's
liveness is asserted **after both**, because a bind returning 0 proves only
that keyd was alive when it answered: on 2026-09-22 this test printed its
success line at 17:27:24 and keyd dumped core at 17:27:27, so `apply.sh`
reported a working chain over a daemon three seconds from death. That is this
repo's own recurring bug -- *a test that aborts early reports zero failures* --
arriving from a new direction, and `died` is a distinct outcome from `bind`
because "the bind was refused" and "the bind was accepted and killed it" want
completely different next steps.

And liveness is checked **before** the test as well, which is not the
redundancy it looks like. Without it, a daemon that was already dead going in
fails the after-check and is reported as *the bind was accepted and then it
crashed* -- a precise, confident claim about a mechanism that never happened.
Found by running this step against exactly that state rather than by reading
it: with keyd down, the run named a crash-during-test that had not occurred.
A wrong diagnosis is worse here than no diagnosis, because the whole reason
this step exists is that the far end of the chain is silent.

It ends with `off` and is immediately followed by 8c's reload, which
re-seeds macos-shortcuts.lua's figma_keyd_on from the live focus -- so this
cannot strand the two out of step even if Figma happens to be focused.

## From the step table

keyd, for Figma alone: an identity `default.conf` pinned to the Preonic that
also *defines* the inert `[figma:C]` layer, the focus helper, and the `keyd`
group grant. Nothing is remapped until Figma takes focus, at which point
`macos-shortcuts.lua` binds `leftmeta = layer(figma)` in the running daemon
and drops it again on blur — Figma reads `ctrlKey` and ignores `metaKey` off
macOS, and Hyprland has no pointer-button or scroll-axis dispatcher to
translate Cmd+click / Cmd+scroll with. Needs **sudo**. keyd re-reads that
config only at start, so this step's `systemctl restart` is the *only* thing
that publishes an edit to `keyd/default.conf`; it ends by binding the layer
and releasing it as a smoke test, because every link in the chain fails
silently

Script: [`keyd.sh`](keyd.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
