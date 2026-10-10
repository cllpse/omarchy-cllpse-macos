#!/bin/bash
# Swap Chromium's theme extension to match the Omarchy theme, live, on every
# `omarchy theme set`.
#
# Omarchy calls `omarchy-hook theme-set <name>` after omarchy-theme-set-browser
# has written its color.json and refreshed the browser, so this runs last. It
# asks the root-owned writer to force-install the light or dark theme
# extension (and keep Omarchy's seed masked), then makes the running Chromium
# re-read policy: Chromium uninstalls the theme that is no longer forced and
# installs the new one, which applies it, with no relaunch.
#
# Only our two themes have an extension. Any other theme turns ours off, which
# hands Chromium back to Omarchy's own colour.
#
# The writer runs through `sudo -n`, the passwordless rule chromium-theme.sh
# installs. Without that rule (apply.sh's chromium-theme step not run) this
# does nothing. See ../../chromium-theme/README.md.
#
# omarchy-hook runs hooks one after another and waits for each, so this one is
# kept short (README.md §7.6): the writer exits 3 when nothing changed and the
# refresh is skipped; Chromium is found through its own SingletonLock instead
# of a /proc scan; and the refresh, a whole Chromium process spawned to send
# one message, is detached rather than waited for.
set -euo pipefail

WRITER=/usr/local/bin/cllpse-chromium-theme-policy
[[ -x $WRITER ]] || exit 0

name=${1:-$(cat ~/.local/state/omarchy/current/theme.name 2>/dev/null || true)}
case $name in
  omarchy-cllpse-theme-light) mode=light ;;
  omarchy-cllpse-theme-dark) mode=dark ;;
  *) mode=off ;;
esac

rc=0
sudo -n "$WRITER" "$mode" || rc=$?
(( rc == 0 )) || exit 0 # 3: already so; anything else: no rule, or it failed

# Running? The lock names "<host>-<pid>"; check that pid is Chromium, so a
# stale lock after a crash cannot pass. Refreshing a Chromium that is not
# running would START one, windowless, which is what this guards against.
lock=$(readlink ~/.config/chromium/SingletonLock 2>/dev/null) || exit 0
[[ $(readlink "/proc/${lock##*-}/exe" 2>/dev/null) == /usr/lib/chromium/chromium ]] || exit 0
setsid -f chromium --refresh-platform-policy --no-startup-window &>/dev/null || true
