#!/bin/bash
# Undo everything overrides/apply.sh did. Idempotent.
# Sudo is needed by two steps near the end: removing the keyd config apply.sh
# installed, and removing the Chromium managed-policy file. Everything else is
# user-level. keyd itself is never uninstalled -- this script did not install it.
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
# Both names: io.eject.window-switcher is what apply.sh linked before the
# manifest id changed, and a machine applied at that time still has it.
[[ -L ~/.config/omarchy/plugins/cllpse.window-switcher ]] && rm -f ~/.config/omarchy/plugins/cllpse.window-switcher
[[ -L ~/.config/omarchy/plugins/io.eject.window-switcher ]] && rm -f ~/.config/omarchy/plugins/io.eject.window-switcher

say "Removing xkb us-danish-letters symbols file"
rm -f ~/.config/xkb/symbols/us-danish-letters

say "Removing SF + Comic Code fonts + fontconfig drop-ins"
rm -rf ~/.local/share/fonts/SF
rm -rf ~/.local/share/fonts/ComicCode
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
# Drop-ins this repo shipped once and no longer does. The loop above walks the
# REPO directory, so a file deleted from the repo is invisible to it and the
# installed copy would survive a revert. Keep this list in step with the
# matching one in apply.sh step 7c.
for f in 10-cllpse-macos-font-rendering.conf; do
  t=~/.config/environment.d/$f
  [[ -e $t ]] && { rm -f "$t"; say "removed retired drop-in $f"; }
done

strip_fenced ~/.config/ghostty/config
strip_fenced ~/.config/hypr/hyprland.lua
strip_fenced ~/.config/hypr/looknfeel.lua
strip_fenced ~/.config/hypr/bindings.lua
strip_fenced ~/.config/hypr/input.lua
strip_fenced ~/.bashrc
strip_fenced ~/.config/git/config
# Chromium's device-pixel-ratio flag (apply.sh step 7d). Omitting this left
# --force-device-scale-factor=1 in place after a full revert, so the browser UI
# stayed at 0.8x forever with nothing in the repo still pointing at the cause.
strip_fenced ~/.config/chromium-flags.conf

# The other half of that pair: page zoom. Same rule as the font — put back what
# was recorded at first apply, and with nothing recorded clear the key rather
# than inventing a zoom, which hands the setting back to Chromium's own default.
# Skipped entirely if Chromium is running; the script says so and changes
# nothing, since Chromium rewrites Preferences from memory when it exits.
if [[ -x $HERE/chromium/default-zoom.py ]]; then
  if [[ -s $STATE/previous-chromium-zoom ]]; then
    prev_zoom="$(<"$STATE/previous-chromium-zoom")"
    say "restoring Chromium default page zoom: ${prev_zoom}%"
    "$HERE/chromium/default-zoom.py" "$prev_zoom" || true
    rm -f "$STATE/previous-chromium-zoom"
  else
    say "clearing Chromium default page zoom (its own default applies)"
    "$HERE/chromium/default-zoom.py" --reset || true
  fi
fi

restore ~/.config/bat/config
restore ~/.config/lazygit/config.yml
restore ~/.config/lsd/config.yaml
restore ~/.config/lsd/colors.yaml
restore ~/.config/yazi/theme.toml
restore ~/.config/lazydocker/config.yml
restore ~/.config/gh-dash/config.yml
restore ~/.config/Cursor/User/settings.json

say "Removing starship theme-set hook"
[[ -L ~/.config/omarchy/hooks/theme-set.d/starship-colors.sh ]] && rm -f ~/.config/omarchy/hooks/theme-set.d/starship-colors.sh
restore ~/.config/starship.toml

say "Removing Cursor chrome theme-set hook"
[[ -L ~/.config/omarchy/hooks/theme-set.d/cursor-chrome.sh ]] && rm -f ~/.config/omarchy/hooks/theme-set.d/cursor-chrome.sh
# The chrome lives in settings.json, which `restore` below puts back wholesale.

say "Removing yazi previewer theme-set hook"
[[ -L ~/.config/omarchy/hooks/theme-set.d/yazi-syntax.sh ]] && rm -f ~/.config/omarchy/hooks/theme-set.d/yazi-syntax.sh
rm -f ~/.config/yazi/cllpse-macos.tmTheme

say "Removing hunk theme-set hook"
[[ -L ~/.config/omarchy/hooks/theme-set.d/hunk-colors.sh ]] && rm -f ~/.config/omarchy/hooks/theme-set.d/hunk-colors.sh
restore ~/.config/hunk/config.toml

# Flat app icons (apply.sh step 7f). The whole override is one directory we
# created, so removing it hands every app back to its vendor icon; there is no
# backup to restore because nothing pre-existing was replaced.
say "Removing the post-update repair hook"
[[ -L ~/.config/omarchy/hooks/post-update.d/cllpse-macos-repair.sh ]] && rm -f ~/.config/omarchy/hooks/post-update.d/cllpse-macos-repair.sh

say "Removing app icon drop-ins + their theme-set hook"
[[ -L ~/.config/omarchy/hooks/theme-set.d/app-icons.sh ]] && rm -f ~/.config/omarchy/hooks/theme-set.d/app-icons.sh
# BOTH output directories. app-icons.sh writes two -- cllpse-flat (repainted in
# the theme foreground) and cllpse-color (copied verbatim) -- and for a while
# this only knew about the first, because the colour pass was added afterwards
# (89ff73a) and this block was last touched before it (3ee160d). Leaving
# cllpse-color behind is the worst shape a leftover can take here: $HOME/.icons
# is the FIRST directory in the sweeps AppLibrary and the switcher run, so those
# drop-ins go on overriding vendor icons forever, and with the repo reverted
# there is nothing left on the machine to explain why. It also silently defeated
# the rmdir below, which cannot remove a non-empty ~/.icons.
for d in ~/.icons/cllpse-flat ~/.icons/cllpse-color; do
  [[ -d $d ]] || continue
  rm -rf "$d"
  say "removed $d"
done
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
  if jq --arg id cllpse.window-switcher --arg old io.eject.window-switcher \
        --arg prev "$prev_bar" --arg layout "$prev_layout" '
        # Both ids: the plugin declared io.eject.window-switcher before the
        # rename, and apply.sh is the only thing that ever put either there.
        .plugins = ((.plugins // []) | map(select(.id != $id and .id != $old)))
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

# keyd (apply.sh step 8c). Order matters: drop any LIVE remap first, because a
# runtime `keyd bind` outlives both this script and the compositor -- it goes
# only on `keyd bind reset`, a keyd restart or a reboot. Reverting the config
# while leftmeta was still bound to leftcontrol would strand a meta key that
# types Ctrl, with the repo gone and nothing left to explain it.
if command -v keyd >/dev/null 2>&1; then
  keyd bind reset >/dev/null 2>&1 || true
  say "keyd: dropped any live Figma remap"
fi
rm -f ~/.local/bin/cllpse-figma-keyd
# ~/.local/bin is NOT removed even if it ends up empty: it is a standard XDG
# location that predates this repo on this machine, and apply.sh only ever
# mkdir -p'd it. Removing a directory we did not create is the mistake the
# cllpse-color leftover was the mirror image of.

# Only OUR config, identified the same way apply.sh identifies it, and only
# ours: a keyd install that predates this repo keeps whatever it had. The
# service is left enabled on purpose -- this script did not install keyd and
# does not know what else may depend on it now.
keyd_conf=/etc/keyd/default.conf
if [[ -f $keyd_conf ]] && head -1 "$keyd_conf" | grep -q 'installed by overrides/apply.sh'; then
  say "Removing the keyd config this repo installed (needs sudo): $keyd_conf"
  sudo rm -f "$keyd_conf" || say "  could not remove $keyd_conf — remove it yourself"
  sudo systemctl reload keyd >/dev/null 2>&1 || sudo systemctl restart keyd >/dev/null 2>&1 || true
  say "  keyd left installed and enabled — remove it yourself if nothing else needs it:"
  say "    sudo systemctl disable --now keyd && sudo pacman -Rs keyd"
fi
# Group membership is deliberately NOT revoked: the user may have joined the
# keyd group for their own reasons, and dropping someone from a group they
# might rely on is not this script's call. To undo it by hand:
#   sudo gpasswd -d "$USER" keyd

dest=/etc/chromium/policies/managed/cllpse-macos.json
if [[ -f $dest ]]; then
  say "Removing Chromium managed policy (needs sudo): $dest"
  sudo rm -f "$dest" || say "  could not remove $dest — remove it yourself: sudo rm -f $dest"
fi

echo
say "Done."
say "Relogin to clear OMARCHY_MENU_FONT and the font-cache changes."
say "Relaunch Chromium to clear the context-menu policy (or it self-refreshes on the next theme set)."
