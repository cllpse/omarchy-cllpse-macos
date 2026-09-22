#!/bin/bash
# Re-establish the links this repo puts inside Omarchy-owned directories, after
# an `omarchy update`.
#
# omarchy-update runs `omarchy-hook post-update` (omarchy-update:49), so this
# fires once per update with no scheduling of our own.
#
# What it is defending against: everything apply.sh installs lives in one of two
# places. Files under ~/.icons/, ~/.local/ and ~/.config/hypr/ are ours alone and
# no Omarchy command touches them. But the *symlinks* live in directories Omarchy
# ships and manages -- ~/.config/omarchy/{hooks,themes,plugins}/ -- and Omarchy
# ships its own content into those (config/omarchy/hooks/theme-set.d/ carries
# .sample files, for instance). A refresh, a migration, or a future install step
# that repopulates one of those directories would take our symlink with it, and
# nothing would report the loss: the icons would just quietly revert to vendor
# logos on the next theme change.
#
# Relinking is idempotent and costs nothing, so it runs unconditionally rather
# than trying to detect damage.
#
# Deliberately NOT rewritten here: ~/.config/omarchy/shell.json (the plugins[]
# entry, bar.transparent, disabledPlugins). That file is machine-level, and
# rewriting it from a hook that fires during an UPDATE is a worse failure mode
# than the one it prevents. Re-run apply.sh if the switcher stops loading.
#
# Bar widget order used to be on that list and no longer is, which is a
# decision reversed on purpose rather than an oversight. The bar is
# drag-reorderable with no setting to disable it (the gate is a capability
# test, not a config key -- see hooks/post-boot.d/cllpse-bar-layout.sh), so an
# accidental drag was permanent. It is now declared in omarchy/shell-bar.json
# and restored at SESSION START by that hook, which is a different moment and a
# narrower write: bar.layout and bar.centerAnchor only, tray pinned/hidden
# carried over. This hook still only re-LINKS it, and rewrites nothing itself.
set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"   # overrides/hooks/post-update.d
OVERRIDES="$(cd "$HERE/../.." && pwd)"                                   # overrides/
REPO="$(cd "$OVERRIDES/.." && pwd)"

link() { # $1 target  $2 link-path
  [[ -e $1 ]] || return 0
  mkdir -p "$(dirname "$2")"
  ln -sfn "$1" "$2"
}

link "$OVERRIDES/hooks/theme-set.d/app-icons.sh"        "$HOME/.config/omarchy/hooks/theme-set.d/app-icons.sh"
link "$OVERRIDES/hooks/theme-set.d/starship-colors.sh"  "$HOME/.config/omarchy/hooks/theme-set.d/starship-colors.sh"
link "$OVERRIDES/hooks/theme-set.d/hunk-colors.sh"      "$HOME/.config/omarchy/hooks/theme-set.d/hunk-colors.sh"
link "$OVERRIDES/hooks/theme-set.d/yazi-syntax.sh"      "$HOME/.config/omarchy/hooks/theme-set.d/yazi-syntax.sh"
link "$OVERRIDES/hooks/theme-set.d/cursor-chrome.sh"    "$HOME/.config/omarchy/hooks/theme-set.d/cursor-chrome.sh"
link "$OVERRIDES/hooks/theme-set.d/gh-dash-colors.sh"   "$HOME/.config/omarchy/hooks/theme-set.d/gh-dash-colors.sh"
link "$OVERRIDES/hooks/theme-set.d/ytm-player.sh"       "$HOME/.config/omarchy/hooks/theme-set.d/ytm-player.sh"
# ytm's hook renders this template, which lives in Omarchy's themed/ directory
# -- also Omarchy's territory, so it is exposed to the same repopulation.
link "$OVERRIDES/themed/ytm-player.toml.tpl"            "$HOME/.config/omarchy/themed/ytm-player.toml.tpl"
link "$OVERRIDES/hooks/post-boot.d/cllpse-bar-layout.sh" \
     "$HOME/.config/omarchy/hooks/post-boot.d/cllpse-bar-layout.sh"
link "$OVERRIDES/hooks/post-update.d/cllpse-macos-repair.sh" \
     "$HOME/.config/omarchy/hooks/post-update.d/cllpse-macos-repair.sh"
link "$REPO/omarchy-cllpse-theme-dark"  "$HOME/.config/omarchy/themes/omarchy-cllpse-theme-dark"
link "$REPO/omarchy-cllpse-theme-light" "$HOME/.config/omarchy/themes/omarchy-cllpse-theme-light"
link "$REPO/omarchy-cllpse-plugin-switcher"                          "$HOME/.config/omarchy/plugins/cllpse.window-switcher"

# An update can also land a new Omarchy whose icons differ, so re-sync rather
# than assuming ~/.icons/ is still current. Cheap: no ImageMagick for the SVGs.
[[ -x $OVERRIDES/hooks/theme-set.d/app-icons.sh ]] && "$OVERRIDES/hooks/theme-set.d/app-icons.sh" || true
