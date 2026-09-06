#!/bin/bash
# Regenerate ~/.config/starship.toml from overrides/starship/starship.toml.tpl
# whenever the active Omarchy theme changes.
#
# Starship has no Omarchy-aware theming of its own -- it isn't one of the
# apps omarchy-theme-set-templates knows about (no starship.toml.tpl in
# /usr/share/omarchy/default/themed/, no omarchy-theme-set-starship script),
# and unlike Ghostty/Alacritty/foot it has no config "import" directive to
# point at a themed file living under ~/.local/state/omarchy/current/theme/
# -- Starship reads one flat TOML file. So instead of a themed/*.tpl (which
# would land inside the theme's own staged folder, not ~/.config/starship.toml),
# this hooks into `omarchy-hook theme-set`, called by omarchy-theme-set right
# after the new theme is staged and live -- the same point
# omarchy-theme-set-foot/-tmux/-claude/etc. run at, just from user space
# (~/.config/omarchy/hooks/theme-set.d/, symlinked here by apply.sh) instead
# of Omarchy's own bin/.
#
# Only `accent` is substituted -- the same hue that drives Hyprland's active
# border gradient (see looknfeel-decoration.lua) -- replacing every literal
# "cyan" the stock prompt hardcodes, so the prompt's accent tracks the same
# colour as everything else in the theme.
set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
TEMPLATE="$HERE/../../starship/starship.toml.tpl"
COLORS="$HOME/.local/state/omarchy/current/theme/colors.toml"
TARGET="$HOME/.config/starship.toml"

[[ -f $TEMPLATE ]] || exit 0
[[ -f $COLORS ]] || exit 0

accent="$(omarchy-theme-color --file "$COLORS" accent 2>/dev/null || true)"
[[ $accent =~ ^#[0-9A-Fa-f]{6}$ ]] || exit 0

sed "s|{{ accent }}|$accent|g" "$TEMPLATE" >"$TARGET"
