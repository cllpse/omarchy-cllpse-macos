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
set -euo pipefail

WRITER=/usr/local/bin/cllpse-chromium-theme-policy
[[ -x $WRITER ]] || exit 0

name=${1:-$(cat ~/.local/state/omarchy/current/theme.name 2>/dev/null || true)}
case $name in
  omarchy-cllpse-theme-light) mode=light ;;
  omarchy-cllpse-theme-dark) mode=dark ;;
  *) mode=off ;;
esac

sudo -n "$WRITER" "$mode" || exit 0

if command -v chromium >/dev/null 2>&1 && pgrep -x chromium >/dev/null; then
  chromium --refresh-platform-policy --no-startup-window &>/dev/null || true
fi
