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

say 'omarchy font set "JetBrainsMono Nerd Font"  (Omarchy default)'
omarchy font set "JetBrainsMono Nerd Font" >/dev/null 2>&1 || true

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

echo
say "Done. Pick another theme:  omarchy theme set <name>"
say "Relogin to clear OMARCHY_MENU_FONT and the font-cache changes."
