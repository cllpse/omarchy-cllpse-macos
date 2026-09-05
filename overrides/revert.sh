#!/bin/bash
# Undo everything overrides/apply.sh did. Idempotent, no sudo.
# Does NOT touch `omarchy display text size` (a pre-existing setting).

set -uo pipefail

say() { printf '\033[34m▸\033[0m %s\n' "$*"; }

# Delete the fenced overrides block from a file, if present. Matches both
# comment leaders ("#" for shell, "--" for Lua).
strip_fenced() { # $1 target
  [[ -f $1 ]] || return 0
  grep -q 'cllpse-macos overrides' "$1" || return 0
  sed -i '/^\(#\|--\) >>> cllpse-macos overrides >>>/,/^\(#\|--\) <<< cllpse-macos overrides <<</d' "$1"
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
[[ -L ~/.config/omarchy/plugins/io.eject.window-switcher ]] && rm -f ~/.config/omarchy/plugins/io.eject.window-switcher

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

say "gsettings: reset GTK/GNOME fonts + hinting"
for k in font-name document-font-name monospace-font-name font-hinting; do
  gsettings reset org.gnome.desktop.interface "$k" 2>/dev/null || true
done

strip_fenced ~/.config/ghostty/config
strip_fenced ~/.config/hypr/hyprland.lua
strip_fenced ~/.config/hypr/looknfeel.lua
strip_fenced ~/.bashrc

restore ~/.config/bat/config
restore ~/.config/lazygit/config.yml

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

echo
say "Done."
say "Relogin to clear OMARCHY_MENU_FONT and the font-cache changes."
