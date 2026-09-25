#!/bin/bash
# Undo everything overrides/apply.sh did. Idempotent.
# Sudo is needed by four steps near the end: removing the keyd config apply.sh
# installed, dropping the CPU power limits back to the firmware's own and
# removing their unit, putting /etc/fstab's Btrfs compression level back, and
# removing the Chromium managed-policy file. Everything else is user-level.
# Neither keyd nor ryzenadj is ever uninstalled -- this script did not install
# them.
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

# Figma Desktop's launcher entry (apply.sh step 7e). Note what is deliberately
# NOT undone: step 7e also removes a wrapper around ~/Applications/figma-desktop/
# AppRun if it finds one, and that is not restored here. The wrapper was never
# this repo's to begin with, and putting one back would re-break the path the
# app derives its own desktop entry from. Nothing inside the app directory is
# ours, which is the whole point -- there is nothing there to revert. restore() puts back a
# .pre-cllpse backup if one exists, and otherwise removes the file — which is
# the honest undo here: the AppImage re-creates it on its next launch, with
# upstream's Name=Figma and StartupWMClass=Figma. Removing it means Figma has no
# launcher entry until then, which is the same state a machine that never ran
# apply.sh and never launched Figma is in.
restore ~/.local/share/applications/figma-desktop-appimage.desktop
update-desktop-database ~/.local/share/applications 2>/dev/null || true

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

# And the third: the two theme keys apply.sh sets so Chromium's UI is neutral
# rather than cyan. Same rule again -- restore what was recorded at first apply
# (`--print`'s own format, which this script hands straight back), and with
# nothing recorded delete both keys so Chromium's own theme applies rather than
# this script asserting one. Also skipped while Chromium is running, for the
# same Preferences-from-memory reason.
if [[ -x $HERE/chromium/neutral-theme.py ]]; then
  if [[ -s $STATE/previous-chromium-theme ]]; then
    prev_browser_theme="$(<"$STATE/previous-chromium-theme")"
    say "restoring Chromium theme keys: $prev_browser_theme"
    "$HERE/chromium/neutral-theme.py" "$prev_browser_theme" || true
    rm -f "$STATE/previous-chromium-theme"
  else
    say "clearing Chromium's theme keys (its own theme applies)"
    "$HERE/chromium/neutral-theme.py" --reset || true
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

say "Removing gh-dash theme-set hook"
[[ -L ~/.config/omarchy/hooks/theme-set.d/gh-dash-colors.sh ]] && rm -f ~/.config/omarchy/hooks/theme-set.d/gh-dash-colors.sh
# config.yml is restored in the block above, but the symlink points into this
# repo -- which revert.sh does not delete -- so leaving it behind means the
# next `omarchy theme set` rewrites theme.colors and silently undoes that.

say "Removing starship theme-set hook"
[[ -L ~/.config/omarchy/hooks/theme-set.d/starship-colors.sh ]] && rm -f ~/.config/omarchy/hooks/theme-set.d/starship-colors.sh
restore ~/.config/starship.toml

say "Removing Cursor chrome theme-set hook"
[[ -L ~/.config/omarchy/hooks/theme-set.d/cursor-chrome.sh ]] && rm -f ~/.config/omarchy/hooks/theme-set.d/cursor-chrome.sh
# The chrome lives in settings.json, which `restore` below puts back wholesale.

# Cursor's two layout keys are in state.vscdb, not settings.json, so `restore`
# above does not reach them. Put back only what apply recorded — a recording
# exists only if apply actually found the wrong value and changed it. Nothing
# recorded means the machine was already correct and there is nothing to undo.
# Skipped while Cursor is running, since it rewrites that DB from memory; the
# process NAME is `electron`, so neither `pgrep -x` nor `pgrep -f` can test for
# it and /proc/<pid>/exe is resolved instead.
cursor_running() {
  local p exe
  for p in /proc/[0-9]*; do
    exe=$(readlink "$p/exe" 2>/dev/null) || continue
    case "$exe" in */electron*|*/cursor|*/Cursor) ;; *) continue ;; esac
    grep -qa '/share/cursor/' "$p/cmdline" 2>/dev/null && return 0
  done
  return 1
}

# state file | key | the two values this key is allowed to hold
cursor_layout_keys=(
  "previous-cursor-layout|cursor/unifiedAppLayout|agent editor"
  "previous-cursor-titlebar|cursor/noTitlebarLayout.visibility|hide show"
)

cursor_state=~/.config/Cursor/User/globalStorage/state.vscdb
if [[ -s $cursor_state ]]; then
  for _spec in "${cursor_layout_keys[@]}"; do
    IFS='|' read -r _file _key _valid <<<"$_spec"
    [[ -s $STATE/$_file ]] || continue
    _mode="$(cat "$STATE/$_file")"
    if [[ " $_valid " != *" $_mode "* ]]; then
      say "$_file holds an unknown value ($_mode) — left state.vscdb alone"
    elif ! command -v sqlite3 >/dev/null 2>&1; then
      say "sqlite3 missing — $_key left as-is (recorded: $_mode)"
    elif cursor_running; then
      say "Cursor is running — $_key left as-is; close it and re-run to restore $_mode"
    elif sqlite3 "$cursor_state" \
           "update ItemTable set value='$_mode' where key='$_key';" 2>/dev/null; then
      say "Cursor $_key -> $_mode (restored)"
      rm -f "$STATE/$_file"
    else
      say "could not write $_key — left state.vscdb alone"
    fi
  done
fi

say "Removing yazi previewer theme-set hook"
[[ -L ~/.config/omarchy/hooks/theme-set.d/yazi-syntax.sh ]] && rm -f ~/.config/omarchy/hooks/theme-set.d/yazi-syntax.sh
rm -f ~/.config/yazi/cllpse-macos.tmTheme

say "Removing hunk theme-set hook"
[[ -L ~/.config/omarchy/hooks/theme-set.d/hunk-colors.sh ]] && rm -f ~/.config/omarchy/hooks/theme-set.d/hunk-colors.sh
restore ~/.config/hunk/config.toml

say "Removing ytm-player theme template + hook"
[[ -L ~/.config/omarchy/hooks/theme-set.d/ytm-player.sh ]] && rm -f ~/.config/omarchy/hooks/theme-set.d/ytm-player.sh
[[ -L ~/.config/omarchy/themed/ytm-player.toml.tpl ]] && rm -f ~/.config/omarchy/themed/ytm-player.toml.tpl
# theme.toml is ours whole, so it goes. config.toml is the USER's file -- the
# hook rewrites its [ui] theme line and config-prefs.py sets nine preference
# keys in it -- so restore a backup if apply.sh made one, but never delete it
# the way restore() would when none exists.
rm -f ~/.config/ytm-player/theme.toml
rm -f ~/.local/bin/cllpse-ytm-signin
if [[ -e ~/.config/ytm-player/config.toml.pre-cllpse ]]; then
  restore ~/.config/ytm-player/config.toml
elif [[ -e ~/.config/ytm-player/config.toml ]]; then
  say "left ~/.config/ytm-player/config.toml alone — its [ui] theme may still name textual-light/dark"
fi

# App icons (apply.sh step 7f). The whole override is one directory we
# created, so removing it hands every app back to its vendor icon; there is no
# backup to restore because nothing pre-existing was replaced.
say "Removing the post-update repair hook"
[[ -L ~/.config/omarchy/hooks/post-boot.d/cllpse-bar-layout.sh ]] && rm -f ~/.config/omarchy/hooks/post-boot.d/cllpse-bar-layout.sh
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
# Not listed here, deliberately: ~/.config/omarchy/cllpse.window-switcher/icons/,
# where the window-switcher plugin lets a user drop marks of their own. apply.sh
# never creates it and nothing here writes to it, so it is not ours to remove --
# the same rule the keyd config below is left alone under.
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
if [[ -f $HERE/display/display-lib.sh ]]; then
  # shellcheck source=overrides/display/display-lib.sh
  source "$HERE/display/display-lib.sh"

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
# Tailscale SSH (apply.sh step 7i). Turned off again ONLY if it was off before
# this repo touched it. apply.sh records the pref verbatim, so `false` means we
# enabled it and `true` means the machine already had it and it is not ours to
# revoke; nothing recorded (an unreadable prefs blob at apply time) is left alone
# on the same principle. No sudo when the operator bit is held, which is the
# normal case on Omarchy -- omarchy-install-service-tailscale grants it.
if [[ -s $STATE/previous-tailscale-ssh ]] && command -v tailscale >/dev/null 2>&1; then
  prev_ssh="$(<"$STATE/previous-tailscale-ssh")"
  if [[ $prev_ssh != false ]]; then
    say "Tailscale SSH left on — it was already on before apply.sh ran"
    rm -f "$STATE/previous-tailscale-ssh"
  else
    # A revert arriving OVER Tailscale SSH would cut its own connection right
    # here and leave every step below this unrun, so that case is skipped rather
    # than risked -- and the record is KEPT, so running revert.sh again from the
    # machine itself still finishes the job. Detected from SSH_CONNECTION's
    # client address landing in Tailscale's CGNAT range, 100.64.0.0/10, which is
    # the shape of every tailnet IP.
    _ssh_client="${SSH_CONNECTION:-}"; _ssh_client="${_ssh_client%% *}"
    if [[ $_ssh_client =~ ^100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\. ]]; then
      say "Tailscale SSH left ON: this session arrives over the tailnet ($_ssh_client)"
      say "  turning it off now would cut this connection mid-revert. Afterwards, run:"
      say "    tailscale set --ssh=false"
    else
      say "Tailscale SSH -> off (it was off before apply.sh ran)"
      # --accept-risk=lose-ssh: `tailscale set` raises a confirmation for that
      # risk when it judges the change would drop your own session, and this
      # script has nobody to answer it. From a local session it never prompts at
      # all (measured: 38ms, rc=0); the flag guards the case that cannot be
      # reproduced without a second node on the tailnet.
      tailscale set --ssh=false --accept-risk=lose-ssh >/dev/null 2>&1 \
        || sudo -n tailscale set --ssh=false --accept-risk=lose-ssh >/dev/null 2>&1 \
        || say "  could not turn it off — run: sudo tailscale set --ssh=false"
      rm -f "$STATE/previous-tailscale-ssh"
    fi
  fi
fi

rmdir "$STATE" 2>/dev/null || true

# keyd (apply.sh step 8b). Order matters: drop any LIVE remap first, because a
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
  # restart, not reload: the unit has no ExecReload (CanReload=no), so a reload
  # request only ever falls through to this. keyd re-reads its config at start
  # and nowhere else.
  sudo systemctl restart keyd >/dev/null 2>&1 || true
  say "  keyd left installed and enabled — remove it yourself if nothing else needs it:"
  say "    sudo systemctl disable --now keyd && sudo pacman -Rs keyd"
fi

# The restart drop-in is ours outright -- the packaged unit carries no restart
# policy at all -- so it goes back with the rest. Removed on its own terms
# rather than inside the block above: that one is gated on OUR default.conf
# still being in place, and a machine whose keyd config was replaced by hand
# would otherwise keep this file forever, which is the shape of the
# cllpse-color leftover. The directory goes too, but only with rmdir, so a
# drop-in somebody else put there survives.
keyd_dropin=/etc/systemd/system/keyd.service.d/restart.conf
if [[ -f $keyd_dropin ]] && grep -q 'installed by overrides/keyd/keyd.sh' "$keyd_dropin"; then
  say "Removing the keyd restart drop-in this repo installed (needs sudo): $keyd_dropin"
  if sudo rm -f "$keyd_dropin"; then
    sudo rmdir /etc/systemd/system/keyd.service.d 2>/dev/null || true
    sudo systemctl daemon-reload >/dev/null 2>&1 || true
    say "  keyd is back to the packaged unit — a segfault will stay down again"
  else
    say "  could not remove $keyd_dropin — remove it yourself"
  fi
fi
# Group membership is deliberately NOT revoked: the user may have joined the
# keyd group for their own reasons, and dropping someone from a group they
# might rely on is not this script's call. To undo it by hand:
#   sudo gpasswd -d "$USER" keyd

# Btrfs compression level (apply.sh step 11). Restores the exact token that was
# recorded at first apply -- usually a bare `compress=zstd`, which is the
# kernel's level 3 -- rather than asserting a level of its own, and does nothing
# at all if nothing was recorded. As on the way in, only lines whose FS type is
# btrfs are touched, and the result is verified before it is left in place.
#
# Note this cannot undo the compression of anything written meanwhile: a mount
# option only decides what happens to new writes, so data written at zstd:1
# stays at zstd:1 until it is rewritten.
if [[ -s $STATE/previous-btrfs-compress ]]; then
  prev_compress="$(<"$STATE/previous-btrfs-compress")"
  if [[ $prev_compress =~ ^compress=zstd(:[0-9]+)?$ ]]; then
    say "restoring Btrfs compression in /etc/fstab: $prev_compress (needs sudo)"
    # apply.sh's backup is the true pre-cllpse fstab, so never overwrite it;
    # without one, back up the current file under its own name. Either way the
    # rollback below has to read back the name that was actually written.
    if [[ -e /etc/fstab.pre-cllpse ]]; then
      _fstab_backup=/etc/fstab.pre-cllpse
    else
      _fstab_backup=/etc/fstab.pre-revert
      sudo cp -a /etc/fstab "$_fstab_backup"
    fi
    sudo sed -i -E "/^[^#]*[[:space:]]btrfs[[:space:]]/ s/compress=zstd(:[0-9]+)?/$prev_compress/g" /etc/fstab
    if findmnt --verify --fstab >/dev/null 2>&1; then
      while read -r mp; do
        sudo mount -o "remount,$prev_compress" "$mp" 2>/dev/null ||
          say "  $mp needs a reboot to pick up $prev_compress"
      done < <(findmnt -t btrfs -no TARGET)
      rm -f "$STATE/previous-btrfs-compress"
    else
      sudo cp -a "$_fstab_backup" /etc/fstab
      say "  findmnt --verify rejected the rewritten /etc/fstab — restored the backup"
    fi
  else
    say "recorded Btrfs compression $prev_compress is not a compress=zstd value — left alone"
  fi
fi

# CPU power limits (apply.sh step 10). Disabling the unit does not put the
# limits back -- the SMU keeps whatever was last written until something resets
# it -- so this asks ryzenadj for the firmware's own 45W before removing the
# files. A reboot would do the same thing, but revert.sh should not depend on
# one.
if [[ -f /etc/systemd/system/ryzen-tdp.service ]]; then
  say "Removing the CPU power-limit unit (needs sudo)"
  sudo systemctl disable --now ryzen-tdp.service >/dev/null 2>&1 || true
  if command -v ryzenadj >/dev/null 2>&1; then
    say "restoring the firmware's 45W sustained limit"
    sudo ryzenadj --stapm-limit=45000 --slow-limit=45000 --fast-limit=54000 >/dev/null 2>&1 || true
  fi
  sudo rm -f /etc/systemd/system/ryzen-tdp.service /etc/default/ryzen-tdp
  sudo systemctl daemon-reload
fi

# Removing this file also un-forces the two extensions it pins (uBlock Origin
# Lite, Proton Pass): Chromium uninstalls a force-installed extension once it
# leaves the forcelist, so there is nothing else to clean up here. Anything the
# extensions stored in the profile goes with them.
dest=/etc/chromium/policies/managed/cllpse-macos.json
if [[ -f $dest ]]; then
  say "Removing Chromium managed policy + forced extensions (needs sudo): $dest"
  sudo rm -f "$dest" || say "  could not remove $dest — remove it yourself: sudo rm -f $dest"
fi

echo
say "Done."
say "Relogin to clear OMARCHY_MENU_FONT and the font-cache changes."
say "Relaunch Chromium to clear the context-menu policy and uninstall the forced extensions (or it self-refreshes on the next theme set)."
