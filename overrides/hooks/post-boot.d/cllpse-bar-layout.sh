#!/bin/bash
# Restore the declared bar widget order, once per session.
#
# Omarchy's bar lets you DRAG a widget to reorder it, and drag the bar itself to
# another screen edge. There is no setting to turn that off, and this was
# checked rather than assumed: `applyBarConfig` (plugins/bar/Bar.qml) reads
# exactly position / transparent / centerAnchor / layout, `builtinShellConfig`
# (shell.qml) defines no more, and the stock shell.json carries the same four.
# The reorder gate is a CAPABILITY test, not a config key --
#
#   readonly property bool canReorder:
#     root.shell && typeof root.shell.mutateShellConfig === "function"
#
# -- and that function is unconditional on the shell root. So the only ways to
# actually prevent the drag are to patch a pacman-owned file (silently reverted
# by every `omarchy` package upgrade) or to fork the 2,300-line bar plugin and
# select it with bar.id. Both were considered and declined.
#
# What is done instead: the drag is not prevented, it is made free. The layout
# is declarative in overrides/omarchy/shell-bar.json, and this puts it back at
# session start. shell.json is watched live (shell.qml holds a FileView on it
# with watchChanges: true), so the bar re-reads it with no restart and no
# theme-set.
#
# Fired by `omarchy-hook post-boot`, which Omarchy dispatches from
# default/hypr/autostart.lua:13 (`sleep 2 && omarchy-hook post-boot`) -- once
# per Hyprland session, with no scheduling, no timer and no daemon of ours.
#
# --bar-only is the whole reason that flag exists: this touches bar.layout and
# bar.centerAnchor and nothing else. It must not re-assert plugins[],
# bar.transparent or disabledPlugins, because a hook that fires every session
# would then silently undo a plugin the user enabled from Omarchy's own menu.
# The tray's pinned/hidden arrays are carried over by the shared jq in
# omarchy.sh, so they stay this machine's -- there is one implementation of that
# carry-over, not two.
#
# Mid-session there is no event to hang this on (the bar emits none), so an
# accidental drag stands until the next login or until you run:
#   bash ~/Sites/omarchy-cllpse-macos/overrides/omarchy/omarchy.sh --bar-only
set -euo pipefail

# Omarchy runs hooks as `bash "$hook"` against the symlink in
# ~/.config/omarchy/hooks/, so resolve through it to reach the repo.
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"  # overrides/hooks/post-boot.d
OVERRIDES="$(cd "$HERE/../.." && pwd)"

exec bash "$OVERRIDES/omarchy/omarchy.sh" --bar-only
