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

## 4. `keyd reload` -- the daemon's own command

`keyd reload` -- the daemon's own command, over the same group-owned
socket `keyd bind` uses, so it needs no root and does not interrupt the
grab. NOT `systemctl reload`: this unit is a bare
`ExecStart=/usr/bin/keyd` with no ExecReload, so
`systemctl show keyd -p CanReload` says no and that request only ever
fails. Either way something has to be asked, since keyd re-reads
default.conf at start or on reload and at no other time -- editing
overrides/keyd/default.conf reaches the daemon here and nowhere else.
The restart is the fallback for a session that does not yet hold the
keyd group (see the grant below); it costs a momentary ungrab.

## 5. `keyd bind` talks to a root-owned socket whose

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

## 6. Smoke-test the whole chain

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
