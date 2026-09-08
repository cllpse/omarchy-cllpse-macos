#!/bin/bash
# Undo everything overrides/apply.sh did. Idempotent.
# No sudo except removing the Chromium managed-policy file apply.sh installed
# (the last step) — everything else here is user-level.
# Only ever restores what this machine had before apply.sh first ran; it never
# picks a font, theme, text size or scale of its own.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

say() { printf '\033[34m▸\033[0m %s\n' "$*"; }

# Delete every fenced overrides block from a file, if present. Matches both
# comment leaders ("#" for shell, "--" for Lua) and an optional ": <suffix>"
# marker (apply.sh's sync_fenced $3) -- bindings.lua carries four separate
# blocks (the plain one plus ": keybinds" / ": macos-shortcuts" /
# ": window-management-mod"), and GNU sed's range address re-arms after each
# closing match, so one pass here removes all of them, not just the first.
strip_fenced() { # $1 target
  [[ -f $1 ]] || return 0
  grep -q 'cllpse-macos overrides' "$1" || return 0
  sed -i '/^\(#\|--\) >>> cllpse-macos overrides.* >>>$/,/^\(#\|--\) <<< cllpse-macos overrides.* <<<$/d' "$1"
  # drop a trailing blank line left behind
  sed -i -e :a -e '/^\n*$/{$d;N;ba}' "$1" 2>/dev/null || true
  say "cleaned overrides block from $1"
}

# Restore a .pre-cllpse backup, else remove the file.
restore() { # $1 target
  if [[ -e $1.pre-cllpse ]]; then mv -f "$1.pre-cllpse" "$1"; say "restored $1"
  elif [[ -e $1 ]]; then rm -f "$1"; say "removed $1"; fi
}

say "Removing theme symlinks"
rm -f ~/.config/omarchy/themes/omarchy-cllpse-theme-dark ~/.config/omarchy/themes/omarchy-cllpse-theme-light

say "Removing window-switcher plugin symlink"
[[ -L ~/.config/omarchy/plugins/cllpse.window-switcher ]] && rm -f ~/.config/omarchy/plugins/cllpse.window-switcher

say "Removing xkb us-danish-letters symbols file"
rm -f ~/.config/xkb/symbols/us-danish-letters

say "Removing SF fonts + fontconfig drop-ins"
rm -rf ~/.local/share/fonts/SF
rm -f ~/.config/fontconfig/conf.d/99-cllpse-macos-ui-font.conf ~/.config/fontconfig/conf.d/99-sf-pro.conf
rm -f ~/.config/fontconfig/conf.d/11-cllpse-macos-hinting.conf ~/.config/fontconfig/conf.d/11-hinting-none.conf
fc-cache -f >/dev/null 2>&1

# Undo the font, don't pick one. Omarchy has no `font reset`, so there are only
# two honest options: put back the font this machine had before apply.sh ran
# (recorded then, in $STATE/previous-font), or — with nothing recorded — delete
# the fonts.conf that omarchy-font-set generates and let fontconfig fall back to
# the packaged default on its own.
STATE="$HOME/.local/state/cllpse-macos"
if [[ -s $STATE/previous-font ]]; then
  prev_font="$(<"$STATE/previous-font")"
  say "restoring pre-existing font: $prev_font"
  omarchy font set "$prev_font" >/dev/null 2>&1 || true
  rm -f "$STATE/previous-font"
else
  # No record: never invent a font name. Removing the generated fonts.conf
  # un-does the fontconfig half; the terminal configs omarchy-font-set edited
  # in place still name SF Mono, and only the user knows what belongs there.
  if [[ -e $HOME/.config/fontconfig/fonts.conf ]]; then
    rm -f "$HOME/.config/fontconfig/fonts.conf"
    say "removed generated ~/.config/fontconfig/fonts.conf (monospace falls back to the packaged default)"
  fi
  say "no pre-existing font recorded — terminal configs may still name SF Mono;"
  say "  set one yourself with:  omarchy font set \"<font>\"   (omarchy font list)"
fi

say "gsettings: reset GTK/GNOME fonts + hinting + window buttons"
for k in font-name document-font-name monospace-font-name font-hinting cursor-theme cursor-size; do
  gsettings reset org.gnome.desktop.interface "$k" 2>/dev/null || true
done
gsettings reset org.gnome.desktop.wm.preferences button-layout 2>/dev/null || true

# Remove only the drop-ins this repo ships, by name — never the whole directory.
if [[ -d $HERE/environment.d ]]; then
  for f in "$HERE"/environment.d/*.conf; do
    [[ -e $f ]] || continue
    t=~/.config/environment.d/"$(basename "$f")"
    [[ -e $t ]] && { rm -f "$t"; say "removed $(basename "$f")"; }
  done
fi

strip_fenced ~/.config/ghostty/config
strip_fenced ~/.config/hypr/hyprland.lua
strip_fenced ~/.config/hypr/looknfeel.lua
strip_fenced ~/.config/hypr/bindings.lua
strip_fenced ~/.config/hypr/input.lua
strip_fenced ~/.bashrc

restore ~/.config/bat/config
restore ~/.config/lazygit/config.yml
restore ~/.config/lsd/config.yaml
restore ~/.config/lsd/colors.yaml
restore ~/.config/Cursor/User/settings.json

say "Removing starship theme-set hook"
[[ -L ~/.config/omarchy/hooks/theme-set.d/starship-colors.sh ]] && rm -f ~/.config/omarchy/hooks/theme-set.d/starship-colors.sh
restore ~/.config/starship.toml

# Flat app icons (apply.sh step 7f). The whole override is one directory we
# created, so removing it hands every app back to its vendor icon; there is no
# backup to restore because nothing pre-existing was replaced.
say "Removing the post-update repair hook"
[[ -L ~/.config/omarchy/hooks/post-update.d/cllpse-macos-repair.sh ]] && rm -f ~/.config/omarchy/hooks/post-update.d/cllpse-macos-repair.sh

say "Removing flat app icons + their theme-set hook"
[[ -L ~/.config/omarchy/hooks/theme-set.d/app-icons.sh ]] && rm -f ~/.config/omarchy/hooks/theme-set.d/app-icons.sh
if [[ -d ~/.icons/cllpse-flat ]]; then
  rm -rf ~/.icons/cllpse-flat
  say "removed ~/.icons/cllpse-flat"
fi
rmdir ~/.icons 2>/dev/null || true

# shell.json: undo exactly the keys apply.sh step 7h wrote, rather than restoring
# the .pre-cllpse backup wholesale — the same file carries `idle`, `version` and
# any other plugin's widget config, which move around long after an apply and are
# not ours to roll back.
#
# The switcher's plugins[] entry is always dropped: apply.sh is the only thing
# that puts it there. Everything else goes back only if a pre-apply value was
# recorded — bar.transparent from previous-bar-transparent, and the bar layout /
# centerAnchor / disabledPlugins from previous-bar-layout, which apply.sh writes
# as one blob. Nothing recorded means the machine already matched what we would
# have written, so there is nothing of its own to restore and it is left alone —
# same rule as the font above.
#
# A recorded layout is restored verbatim, tray pins included. That is the state
# the machine was in before the first apply; any pin added since is a casualty,
# and the .pre-cllpse backup is the fallback for recovering one.
shell_json=~/.config/omarchy/shell.json
if [[ -f $shell_json ]]; then
  prev_bar=""
  [[ -s $STATE/previous-bar-transparent ]] && prev_bar="$(<"$STATE/previous-bar-transparent")"
  prev_layout=""
  [[ -s $STATE/previous-bar-layout ]] && prev_layout="$(<"$STATE/previous-bar-layout")"
  _shell=$(mktemp)
  if jq --arg id cllpse.window-switcher --arg prev "$prev_bar" --arg layout "$prev_layout" '
        .plugins = ((.plugins // []) | map(select(.id != $id)))
        | if $prev == "" then . else .bar.transparent = ($prev == "true") end
        | if $layout == "" then . else
            ($layout | fromjson) as $l
            | .bar.layout = $l.layout
            | if $l.centerAnchor == null then del(.bar.centerAnchor)
              else .bar.centerAnchor = $l.centerAnchor end
            # disabledPlugins is absent, not empty, when nothing is disabled —
            # PluginRegistry.qml deletes the key at length 0.
            | if $l.disabled == null then del(.disabledPlugins)
              else .disabledPlugins = $l.disabled end
          end
      ' "$shell_json" >"$_shell" 2>/dev/null && [[ -s $_shell ]]; then
    cat "$_shell" >"$shell_json"
    say "shell.json: dropped the window-switcher plugin entry${prev_bar:+, bar.transparent -> $prev_bar}${prev_layout:+, bar layout + disabledPlugins restored}"
    rm -f "$STATE/previous-bar-transparent" "$STATE/previous-bar-layout"
  else
    say "  could not rewrite $shell_json — left untouched"
  fi
  rm -f "$_shell"
fi

# Display scaling + text size: put back only what was recorded at first apply.
# Nothing recorded means the machine already matched display.conf, so there is
# nothing of its own to restore.
if [[ -f $HERE/display-lib.sh ]]; then
  # shellcheck source=overrides/display-lib.sh
  source "$HERE/display-lib.sh"

  if [[ -s $STATE/previous-text-size ]]; then
    prev="$(<"$STATE/previous-text-size")"
    say "restoring text size: $prev"
    omarchy display text size "$prev" >/dev/null 2>&1 || true
    rm -f "$STATE/previous-text-size"
  fi

  for v in monitor-scale:omarchy_monitor_scale gdk-scale:omarchy_gdk_scale; do
    f="$STATE/previous-${v%%:*}"; var="${v#*:}"
    if [[ -s $f ]]; then
      prev="$(<"$f")"
      say "restoring $var: $prev"
      write_scale "$var" "$prev" || say "  could not write $var — left alone"
      rm -f "$f"
    fi
  done
fi

# Same rule for the theme: restore what was active before, or say so and stop.
# Leaving a cllpse-macos theme "active" after its folder is unlinked is not
# broken — `omarchy theme set` copies the theme into
# ~/.local/state/omarchy/current/theme/, so the desktop keeps rendering from
# that copy; the theme is simply no longer listed in the picker.
if [[ -s $STATE/previous-theme ]]; then
  prev_theme="$(<"$STATE/previous-theme")"
  say "restoring pre-existing theme: $prev_theme"
  omarchy theme set "$prev_theme" >/dev/null 2>&1 || true
  rm -f "$STATE/previous-theme"
else
  say "no pre-existing theme recorded — pick one:  omarchy theme set <name>"
fi
rmdir "$STATE" 2>/dev/null || true

dest=/etc/chromium/policies/managed/cllpse-macos.json
if [[ -f $dest ]]; then
  say "Removing Chromium managed policy (needs sudo): $dest"
  sudo rm -f "$dest" || say "  could not remove $dest — remove it yourself: sudo rm -f $dest"
fi

echo
say "Done."
say "Relogin to clear OMARCHY_MENU_FONT and the font-cache changes."
say "Relaunch Chromium to clear the context-menu policy (or it self-refreshes on the next theme set)."
