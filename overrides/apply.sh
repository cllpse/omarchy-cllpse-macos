#!/bin/bash
# Apply the cllpse-macos theme + every system-level override it needs.
# Idempotent. Re-run any time. See revert.sh to undo.
#
#   apply.sh            pick what to run; everything when there is no terminal
#   apply.sh bar        reset the top bar to the declared layout, and nothing else
#   apply.sh --all      everything, no prompt
#   apply.sh --look     only the steps that change how it looks
#   apply.sh <id>...    only these, always in the order below
#   apply.sh --list     every id, and which four need sudo
#
# This script is now an ORCHESTRATOR. Each override owns a script and a README
# in its own directory -- overrides/cursor/cursor.sh and overrides/cursor/
# README.md, and so on -- and this file calls them in the order below. Two
# things are deliberately NOT in a folder:
#
#   * steps that configure the system rather than an app (gsettings, the theme
#     apply, hyprctl reload, the Btrfs mount option). They have no folder to
#     live in and stay inline here.
#   * the ORDER itself, which is the one thing a per-folder script cannot own.
#     Sudo is needed by exactly four steps and they are all late on purpose:
#     8b (keyd), 9 (the Chromium managed policy), 10 (CPU power limits) and
#     11 (Btrfs). chromium/chromium.sh takes a `user`/`policy` argument for
#     precisely this reason -- its two halves run at opposite ends of a run.
#
# Every per-folder script is also runnable on its own. They source lib.sh for
# say/skip/backup/sync_fenced/record_prior, STATE and MARK.
#
# keyd, ryzenadj and tailscale are the three packages this depends on and it
# installs NONE of them -- each step configures its tool if present and says so
# if it is not. Only keyd's step needs sudo; tailscale's is passwordless, since
# Omarchy's own installer already grants this user Tailscale's operator bit.
#
# What each step does, and where to read about it:
#
#   0.   record the pre-existing font and theme, for revert.sh        [inline]
#   1.   symlink both themes + the window-switcher plugin              [inline]
#   2.   SF + Comic Code fonts                                         fonts/
#        fontconfig drop-ins (UI font + hintnone)                      fontconfig/
#   3.   point monospace at SF Mono (omarchy font set)                 [inline]
#   4.   point GTK / GNOME apps at SF Pro / SF Mono (gsettings)        [inline]
#   5.   hinting none: gsettings                                       [inline]
#        hinting none: Ghostty                                         ghostty/
#   5b.  strip GTK window buttons (gsettings)                          [inline]
#   5c.  the Preonic's Danish letters                                  xkb/
#   6.   hypr env + decoration + switcher binds + input,
#        and the keybind allowlist (was 6b)                            hypr/
#   7.   the apps Omarchy doesn't theme:
#          bat/ lazygit/ lsd/ yazi/ lazydocker/ gh-dash/ starship/
#          cursor/ hunk/ ytm/ bash/ git/
#   7b.  restore saved display scaling + text size                     display/
#   7c.  session environment drop-ins                                  environment.d/
#   7d.  Chromium flags, zoom and neutral UI                           chromium/ (user)
#   7e.  Figma Desktop's launcher entry                                applications/
#   7f.  app icons for the menu (repainted + verbatim)                 icons/
#   7f2. post-update repair hook                                       hooks/
#   7h.  Omarchy shell.json: switcher, bar, disabled plugins           omarchy/
#   7i.  Tailscale SSH -- no sshd, no open port                      tailscale/
#   8.   apply the theme                                               [inline]
#   8b.  keyd identity config + Figma modifier remap (sudo)            keyd/
#   8c.  hyprctl reload -- after 8b so the focus handler is seeded
#        against the keyd that is now running                          [inline]
#   9.   Chromium managed policy (sudo)                                chromium/ (policy)
#   10.  CPU power limits (sudo), hardware-gated                       ryzen/
#   11.  Btrfs compression level (sudo) -- last, and the only step
#        that edits a file the machine will not boot without           [inline]


set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

# Run an override's own script. Named rather than globbed: the ORDER is
# load-bearing and a glob would sort it alphabetically.
run() { # $1 folder  $2.. args
  local f="$HERE/$1/${1}.sh"
  [[ -x $f ]] || { skip "missing $1/${1}.sh — skipped"; return 0; }
  "$f" "${@:2}"
}

step_state() {
# revert.sh restores what this machine had before apply.sh first ran, rather
# than hardcoding Omarchy's stock font/theme — those are only right on a machine
# that was already stock. Written once and never overwritten, so re-running
# apply.sh can't clobber the original with our own values.
#
# Values that are already ours are refused outright: on a machine where apply.sh
# has run before, `omarchy font current` reports SF Mono, and recording that
# would quietly turn revert into a no-op.
record_prior "$STATE/previous-font" \
  "$(omarchy font current 2>/dev/null || true)" "SFMono Nerd Font Mono"

prior_theme="$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || true)"
case "$prior_theme" in omarchy-cllpse-theme-*) prior_theme="" ;; esac
record_prior "$STATE/previous-theme" "$prior_theme" ""

}

step_symlinks() {
# Both themes are SUBMODULES, like the plugin below. Refuse before symlinking
# rather than after: a theme symlinked at an empty directory is not an error
# Omarchy reports -- `omarchy theme set` finds no colors.toml and the desktop
# keeps whatever it had, with nothing saying why. colors.toml is the file every
# consumer needs, so it is the one to test for.
for _t in dark light; do
  if [[ ! -f "$REPO/omarchy-cllpse-theme-$_t/colors.toml" ]]; then
    printf '\033[31m✗\033[0m %s\n' \
      "omarchy-cllpse-theme-$_t/ is empty — the themes are submodules." >&2
    printf '  %s\n' "Run: git -C \"$REPO\" submodule update --init --recursive" >&2
    exit 1
  fi
done

say "Linking themes into ~/.config/omarchy/themes/"
mkdir -p ~/.config/omarchy/themes
ln -sfn "$REPO/omarchy-cllpse-theme-dark"  ~/.config/omarchy/themes/omarchy-cllpse-theme-dark
ln -sfn "$REPO/omarchy-cllpse-theme-light" ~/.config/omarchy/themes/omarchy-cllpse-theme-light

say "Linking the window-switcher plugin into ~/.config/omarchy/plugins/"
mkdir -p ~/.config/omarchy/plugins
# Legacy folder name, from before the manifest id became cllpse.window-switcher.
# Must go, not merely be superseded: both links point at the SAME repo folder,
# so leaving it behind registers one manifest id under two plugin directories --
# two HUD instances, each registering the same "cllpse-switcher" global shortcut
# appid and each answering next/prev/commit. Removed only if it is a symlink, so
# an unrelated real directory of that name is never touched.
if [[ -L ~/.config/omarchy/plugins/io.eject.window-switcher ]]; then
  rm -f ~/.config/omarchy/plugins/io.eject.window-switcher
  skip "removed the legacy io.eject.window-switcher plugin link"
fi
# The plugin is a SUBMODULE (github.com/cllpse/omarchy-cllpse-plugin-switcher), so it
# is published to the Omarchy marketplace as a repository of its own. A plain
# `git clone` of this repo leaves that directory empty, and the symlink below
# would then point a registered plugin id at nothing: the shell finds no
# manifest, loads no HUD, and says so nowhere. Checked rather than assumed,
# because the failure is silent and the fix is one command.
if [[ ! -f "$REPO/omarchy-cllpse-plugin-switcher/manifest.json" ]]; then
  printf '\033[31m✗\033[0m %s\n' \
    "omarchy-cllpse-plugin-switcher/ is empty — the window-switcher plugin is a submodule." >&2
  printf '  %s\n' "Run: git -C \"$REPO\" submodule update --init --recursive" >&2
  exit 1
fi
ln -sfn "$REPO/omarchy-cllpse-plugin-switcher" ~/.config/omarchy/plugins/cllpse.window-switcher


}

step_monospace() {
if [[ "$(omarchy font current 2>/dev/null)" == "SFMono Nerd Font Mono" ]]; then
  skip "omarchy font already SFMono Nerd Font Mono"
else
  say 'omarchy font set "SFMono Nerd Font Mono"'
  omarchy font set "SFMono Nerd Font Mono" >/dev/null 2>&1 || true
fi
say "fc-match check"
for q in monospace sans-serif; do printf '    %-11s -> %s\n' "$q" "$(fc-match "$q")"; done


}

step_gtk_fonts() {
say "gsettings: GTK/GNOME fonts -> SF Pro / SF Mono"
gsettings set org.gnome.desktop.interface font-name           'SFProText Nerd Font Propo 11'
gsettings set org.gnome.desktop.interface document-font-name  'SFProText Nerd Font Propo 12'
gsettings set org.gnome.desktop.interface monospace-font-name 'SFMono Nerd Font Mono 10'


}

step_hinting() {
# fontconfig side is the 11-cllpse-macos-hinting.conf drop-in from step 2.
# GTK/GNOME and Ghostty each read their own knob:
say "gsettings: GTK/GNOME font-hinting -> none"
gsettings set org.gnome.desktop.interface font-hinting 'none'
}

step_gtk_buttons() {
# Hyprland draws no titlebars; the min/max/close a GTK/libadwaita app shows are
# its own client-side decoration, laid out from this key (Nautilus, Files, the
# GNOME apps). ':' = nothing either side of the divider. Omarchy's default is
# 'appmenu:close'. Electron/Qt draw their own controls and ignore this — Cursor
# is handled in step 7. `gsettings reset` (revert.sh) restores the default.
say "gsettings: GTK window buttons -> none"
gsettings set org.gnome.desktop.wm.preferences button-layout ':'


}

step_theme() {
# `omarchy theme set` COPIES the theme folder into
# ~/.local/state/omarchy/current/theme/ — it does not symlink it. So this step
# is also what publishes any edit made to a theme folder (new background, changed
# shell.*.toml) to the live desktop; without it the running shell keeps serving
# the copy made by the last theme-set.
#
# Re-running must not yank a light-mode user back to dark, so an already-active
# cllpse-macos theme is refreshed in place; anything else defaults to dark.
# `omarchy theme set` does not keep the current wallpaper: choose_theme_background
# advances to the NEXT one in the folder every call (next_index = index + 1), so
# without this a re-run walks the background forward each time. Remember it by
# name and put it back afterwards if the new theme still has a file by that name.
# Filename of whatever wallpaper is live right now, or empty if there is none.
current_bg_name() {
  basename "$(readlink -f ~/.local/state/omarchy/current/background 2>/dev/null || true)" 2>/dev/null || true
}

prev_bg="$(current_bg_name)"

current_theme="$(cat ~/.local/state/omarchy/current/theme.name 2>/dev/null || true)"
case "$current_theme" in
  omarchy-cllpse-theme-dark | omarchy-cllpse-theme-light)
    say "omarchy theme set $current_theme  (already active — refreshing the copy)"
    omarchy theme set "$current_theme" >/dev/null 2>&1 || true
    ;;
  *)
    say "omarchy theme set omarchy-cllpse-theme-dark"
    omarchy theme set omarchy-cllpse-theme-dark >/dev/null 2>&1 || true
    ;;
esac

# Look in BOTH directories choose_theme_background enumerates, not just the
# theme's own. omarchy-theme-set builds its list from
# ~/.config/omarchy/backgrounds/<theme>/ as well as the staged theme's
# backgrounds/, and the user-level one sorts FIRST, so it is where a wallpaper
# dropped in by hand actually lives. Checking only the staged copy meant such a
# wallpaper never matched, the restore was skipped in silence, and every apply
# walked the background forward by one -- the exact behaviour this block exists
# to prevent. User-level first, mirroring that sort order.
now_theme="$(cat ~/.local/state/omarchy/current/theme.name 2>/dev/null || true)"
_cands=()
# Only reachable with a theme name; the staged copy below needs none.
if [[ -n $now_theme ]]; then
  _cands+=("$HOME/.config/omarchy/backgrounds/$now_theme/$prev_bg")
fi
_cands+=("$HOME/.local/state/omarchy/current/theme/backgrounds/$prev_bg")

restored_bg=""
if [[ -n $prev_bg ]]; then
  for _cand in "${_cands[@]}"; do
    [[ -f $_cand ]] || continue
    restored_bg="$_cand"; break
  done
fi

if [[ -n $restored_bg ]]; then
  if [[ "$(current_bg_name)" != "$prev_bg" ]]; then
    omarchy theme bg set "$restored_bg" >/dev/null 2>&1 || true
    skip "kept the current background ($prev_bg)"
  fi
fi


}

step_hypr_reload() {
# LAST of the 8s, after keyd, and that order is load-bearing for one thing: a
# reload rebuilds the Lua state, which makes macos-shortcuts.lua re-seed
# `figma_keyd_on` from the current focus and dispatch the helper to match. 8b
# restarts keyd, and a restart drops every runtime bind -- so with the reload
# ahead of it, an apply.sh run with Figma focused left the handler believing
# the remap was on against a daemon that had just reset it, and it stayed that
# way until the Figma focus boundary had been crossed twice. Reloading after
# the restart makes the two agree unconditionally.
#
# Otherwise: belt and braces, NOT a fix for an observed bug -- an earlier version of this
# comment claimed otherwise and was simply wrong. Hyprland's autoreload does
# pick up a change to a require()d module, not just to the config it was
# started with: measured by appending one bind to ~/.config/hypr/bindings.lua
# and watching `hyprctl binds` go 150 -> 151 within three seconds with no
# reload dispatched. The sync_fenced edits above land on their own.
#
# What this still buys is determinism -- apply.sh finishes with the config
# known live rather than depending on a watcher's timing -- and it covers
# `misc:disable_autoreload = true`, which a machine may legitimately set.
#
# Worth knowing if this is ever re-examined: **Hyprland logs nothing on a
# config reload.** Several reloads in a row left zero matching lines in a
# 15,000-line hyprland.log. So an old log with no reload lines in it is not
# evidence that no reload happened, which is exactly the bad inference the
# previous version of this comment was built on.
#
# That a reload suffices is not obvious and was measured too: Lua caches
# modules in package.loaded, so a reload that merely re-ran the top-level file
# would keep a stale bindings.lua. It does not -- a global set through
# `hyprctl eval` before a reload reads back nil after it, so the Lua state is
# rebuilt and every module is re-required from disk.
if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
  say "hyprctl reload  (autoreload already covers this; this makes it deterministic)"
  hyprctl reload >/dev/null 2>&1 || skip "hyprctl reload failed — run it yourself, or relogin"
else
  skip "no running Hyprland — the hypr overrides apply at the next login"
fi


}

step_btrfs() {
# Btrfs compresses every write, and zstd's level decides how hard it works.
# Level 3 -- the kernel's default, which is what a bare `compress=zstd` selects
# -- runs roughly 2-3x slower at compression than level 1 for ~5-10% better
# ratio on mixed data. On this machine that trade is wrong in both directions:
# the disk is 4% full, so the ratio buys nothing, and the CPU is thermally
# capped (step 10), so the watts the compressor takes come straight out of the
# cores. Reads are unaffected -- zstd decompression speed is essentially
# level-independent.
#
# Worth knowing before changing it back and forth: a mount option is not a
# property of the data. It says what to do with INCOMING writes, so existing
# extents keep whatever level they were written at until something rewrites
# them. `btrfs filesystem defragment -r -czstd` would rewrite them, and is
# deliberately NOT run here: on a filesystem with Snapper snapshots it unshares
# extents and can multiply disk usage.
#
# fstab is the one file in this script whose corruption stops the machine
# booting, so: back it up first, rewrite only lines whose FS type field is
# btrfs, and verify the result with `findmnt --verify` before leaving it in
# place -- restoring the backup if that fails.
if [[ -f /etc/fstab ]] && grep -qE '^[^#]*[[:space:]]btrfs[[:space:]].*compress=zstd' /etc/fstab; then
  # One value across every btrfs line, or nothing is touched: a machine that
  # deliberately mounts subvolumes at different levels is not one to flatten,
  # and a mixed reading is also not something revert.sh could put back.
  _btrfs_now="$(grep -E '^[^#]*[[:space:]]btrfs[[:space:]]' /etc/fstab |
                grep -oE 'compress=zstd(:[0-9]+)?' | sort -u)"
  if [[ $(wc -l <<<"$_btrfs_now") -gt 1 ]]; then
    skip "/etc/fstab mounts btrfs at mixed compression levels ($(paste -sd' ' <<<"$_btrfs_now")) — left alone"
  elif [[ $_btrfs_now == "compress=zstd:1" ]]; then
    skip "Btrfs already mounts compress=zstd:1"
  else
    record_prior "$STATE/previous-btrfs-compress" "$_btrfs_now" "compress=zstd:1"
    say "Btrfs compression $_btrfs_now -> compress=zstd:1 in /etc/fstab (sudo)"
    [[ -e /etc/fstab.pre-cllpse ]] || sudo cp -a /etc/fstab /etc/fstab.pre-cllpse
    sudo sed -i -E '/^[^#]*[[:space:]]btrfs[[:space:]]/ s/compress=zstd(:[0-9]+)?/compress=zstd:1/g' /etc/fstab
    if findmnt --verify --fstab >/dev/null 2>&1; then
      # Live too, so this does not wait for a reboot. Each btrfs mount is its
      # own subvol mount and takes the option separately.
      while read -r _mp; do
        sudo mount -o remount,compress=zstd:1 "$_mp" 2>/dev/null &&
          skip "remounted $_mp at zstd:1" ||
          skip "$_mp needs a reboot to pick up zstd:1"
      done < <(findmnt -t btrfs -no TARGET)
    else
      sudo cp -a /etc/fstab.pre-cllpse /etc/fstab
      skip "findmnt --verify rejected the rewritten /etc/fstab — restored the backup, nothing changed"
    fi
  fi
fi

echo
say "Done. Follow-ups:"
echo "    • log out / back in (or reboot) for OMARCHY_MENU_FONT (shell popups)"
echo "    • open a new shell for the fzf colours"
echo "    • restart Ghostty / Foot windows for SF Mono + hintnone"
echo "    • relaunch running GTK/Qt apps + the bar for hintnone"
echo "    • light theme:  omarchy theme set omarchy-cllpse-theme-light"
echo "    • the spellcheck/translate/password/autofill/Print/Cast/QR/reading-list policy (9)"
echo "      already refreshed live if Chromium was running — no relaunch needed"
echo "    • Figma's Cmd+click / Cmd+scroll work now — the focus hook reaches keyd"
echo "      through newgrp, since a granted group never reaches a running desktop"
echo "      (the systemd user manager outlives a logout; only a reboot reseeds it)."
echo "    • Btrfs zstd:1 (11) applies to NEW writes only — existing extents keep"
echo "      the level they were written at, and defragmenting to rewrite them"
echo "      would unshare Snapper's snapshot extents, so it is not done here"
echo "    • CPU power limits (10) are live now and reapplied at boot and on resume;"
echo "      systemctl status ryzen-tdp, values in /etc/default/ryzen-tdp"
echo "    • boot splash / login screen (needs sudo, not run by this script):"
echo "        omarchy plymouth set by theme omarchy-cllpse-theme-dark   # or -light"

}

# The look-and-feel subset: the steps that change how the desktop LOOKS.
# Named explicitly rather than inferred from a label, so it can be audited --
# and validated against STEPS at startup, because a typo here would silently
# drop a step from the set rather than fail.
#
# In: fonts and their hinting, the theme itself, Hyprland's decoration (the
# rounding, borders and blur), the bar, the menu's app icons, and the per-app
# theming that makes terminal tools follow the palette.
#
# `hypr` is in as a whole even though the same fenced snippets also carry
# keybinds, the allowlist and mouse tuning: the decoration cannot be taken
# without them.
#
# `bash` is in for the same reason, and it is the one entry whose label does not
# say so. Its fenced block is mostly aliases, but two of its exports are palette:
# FZF_DEFAULT_OPTS is parsed out of the ACTIVE theme's colors.toml on every
# interactive shell, and LS_COLORS moves lsd's filetypes off their fixed
# 256-colour table onto basic ANSI slots so they track whatever each theme's
# terminal template paints. Both follow `omarchy theme set` the way bat/lazygit/
# lsd do, so a look-and-feel run that skipped this left the picker and `ls` on
# whatever the last full run installed. The aliases ride along.
#
# Out: anything not about appearance -- keyboard layout (xkb), `git` (the pager,
# not a palette), session env, the Figma launcher entry, the repair hook, input
# remapping (keyd), and everything needing sudo or the network. Also out, and
# deliberately: `display`, which is a hardware preference rather than a theme
# and can resize everything on screen; and `chromium-user`, whose neutral UI is
# appearance but which also sets page zoom and the device scale factor.
LOOKNFEEL=(
  fonts fontconfig monospace gtk-fonts hinting ghostty gtk-buttons
  hypr
  bat lazygit lsd yazi lazydocker gh-dash starship cursor hunk ytm
  icons omarchy theme
)
# state rides along for the same reason it does with a ticked selection:
# revert.sh needs what the machine had before, recorded on the first run that
# changes anything.
_look_ids() { printf '%s\n' state "${LOOKNFEEL[@]}"; }

# id|note|label|action|needs — execution order, and the menu's order.
STEPS=(
  "bar|optin|Reset the top bar to the declared layout|run:omarchy --bar-only|"
  "figma|optin|Install or update Figma Desktop (network, opt-in)|run:figma --no-apply|applications"
  "state||Record the pre-existing font and theme, for revert.sh|fn:step_state|"
  "symlinks||Symlink both themes + the window-switcher plugin|fn:step_symlinks|"
  "fonts||SF + Comic Code fonts|run:fonts|"
  "fontconfig||fontconfig drop-ins (UI font + hintnone)|run:fontconfig|"
  "monospace||Point monospace at SF Mono (omarchy font set)|fn:step_monospace|fonts"
  "gtk-fonts||Point GTK / GNOME apps at SF Pro / SF Mono|fn:step_gtk_fonts|fonts"
  "hinting||Font hinting -> none (GTK/GNOME side)|fn:step_hinting|"
  "ghostty||Ghostty hinting|run:ghostty|"
  "gtk-buttons||Strip GTK window buttons|fn:step_gtk_buttons|"
  "xkb||Danish letters on the Preonic M0 layer|run:xkb|"
  "hypr||Hyprland env, decoration, binds, input + keybind allowlist|run:hypr|"
  "display||Display scaling + text size|run:display|"
  "bat||bat|run:bat|"
  "lazygit||lazygit|run:lazygit|"
  "lsd||lsd|run:lsd|"
  "yazi||yazi|run:yazi|"
  "lazydocker||lazydocker|run:lazydocker|"
  "gh-dash||gh-dash|run:gh-dash|"
  "starship||starship|run:starship|"
  "cursor||Cursor|run:cursor|"
  "hunk||hunk|run:hunk|"
  "ytm||ytm-player|run:ytm|"
  "bash||bash aliases + fzf|run:bash|"
  "git||git diff through hunk|run:git|"
  "environment.d||Session environment drop-ins|run:environment.d|"
  "chromium-user||Chromium flags, zoom, neutral UI|run:chromium user|"
  "applications||Figma Desktop launcher entry|run:applications|"
  "icons||App icons for the menu|run:icons|"
  "hooks||Post-update repair hook|run:hooks|"
  "omarchy||Omarchy shell.json|run:omarchy|symlinks"
  "tailscale||Tailscale SSH — no sshd, no open port|run:tailscale|"
  "theme||Apply the theme|fn:step_theme|symlinks"
  "keyd|sudo|keyd: Figma modifier remap (sudo)|run:keyd|hypr"
  "hypr-reload|auto|hyprctl reload|fn:step_hypr_reload|"
  "chromium-policy|sudo|Chromium managed policy (sudo)|run:chromium policy|"
  "ryzen|sudo|CPU power limits (sudo)|run:ryzen|"
  "btrfs|sudo|Btrfs compression level (sudo)|fn:step_btrfs|"
)

# ── selection ────────────────────────────────────────────────────────────────
# Running everything stays the default when there is no terminal to ask at, so
# `figma/figma.sh` and any other caller keep working unchanged. With a
# terminal and no arguments you get the picker, whose first entry is Everything.

_field() { printf '%s\n' "${STEPS[@]}" | awk -F'|' -v k="$1" -v n="$2" '$1==k{print $n}'; }
_ids()   { printf '%s\n' "${STEPS[@]}" | cut -d'|' -f1; }
# What a bare --all runs: everything except the opt-in steps. figma reaches
# the NETWORK and installs an application, which apply.sh otherwise never
# does -- and figma.sh finishes by calling `apply.sh --all` itself, so having
# it in --all would recurse.
_auto_ids() { printf '%s\n' "${STEPS[@]}" | awk -F'|' '$2!="optin"{print $1}'; }

_validate_look() {
  local id bad=()
  for id in "${LOOKNFEEL[@]}"; do _ids | grep -qxF -- "$id" || bad+=("$id"); done
  (( ${#bad[@]} == 0 )) || { printf 'apply.sh: LOOKNFEEL names unknown step(s): %s\n' "${bad[*]}" >&2; exit 3; }
}
_validate_look

usage() {
  cat <<EOF
Apply the cllpse-macos theme + the system overrides it needs. Idempotent.

  apply.sh                 pick what to run (everything, if there is no terminal)
  apply.sh bar             reset the top bar to the declared layout, and nothing else
  apply.sh --all           run everything, no prompt
  apply.sh --look          only the look-and-feel steps
  apply.sh <id> [<id>…]    run only these, in the canonical order
  apply.sh --list          show every id
  apply.sh --help          this

Ids are listed by --list, with whatever each one needs. Prerequisites are
added automatically and announced. Four steps need sudo and are marked; skip
those and the run needs no password at all.
EOF
}

list_steps() {
  printf '  %-18s %-5s %-12s %s\n' "ID" "NOTE" "NEEDS" "WHAT"
  local s; for s in "${STEPS[@]}"; do
    IFS='|' read -r id sudo label _ needs <<<"$s"
    printf '  %-18s %-5s %-12s %s\n' "$id" "$sudo" "$needs" "$label"
  done
}

# gum reads its colours from GUM_* in the environment, and Omarchy puts them
# there with hl.env from the theme's generated gum_env.lua -- at SESSION START.
# They are therefore whatever theme was active at login: switch theme afterwards
# and every gum menu keeps the old palette, because you cannot change the
# environment of a process that is already running. Black-on-white under a dark
# theme is exactly that, and it looks fine to anyone who logged in on light.
#
# So read the live file rather than trusting what we inherited. Same source
# Omarchy uses, just resolved now instead of at login, which also means the
# picker follows a theme switch with no relogin.
_load_gum_theme() {
  local f="$HOME/.local/state/omarchy/current/theme/gum_env.lua" k v
  [[ -r $f ]] || return 0
  while IFS='=' read -r k v; do
    [[ -n $k ]] && export "$k=$v"
  done < <(sed -n 's/^[[:space:]]*hl\.env("\([A-Z_0-9]*\)",[[:space:]]*"\([^"]*\)").*/\1=\2/p' "$f")
}

# Menu, in two stages.
#
# Stage one is a SINGLE choice, so Enter acts on whatever is highlighted with no
# Space needed. Stage two is the multi-select, reached only by asking for it.
# One flat list cannot express this: "run everything" has to win over anything
# else ticked beside it, so as a checkbox it either short-circuits the rest or
# is itself ignored.
#
# Both stages emit STEP IDS on stdout, never labels, so the caller does no
# string matching on what the user saw.
choose_steps() {
  _load_gum_theme
  # BAR is first because it is the cheapest and most repeated thing here: the
  # bar is drag-reorderable with no setting to disable it (see omarchy/README.md
  # (5)), so knocking a widget out of place is a thing that just happens, and
  # the fix should be the entry your hand is already on. It writes bar.layout
  # and bar.centerAnchor and nothing else -- no sudo, no theme-set, no restart.
  local BAR="Reset the top bar to the declared layout"
  local LOOK="Look and feel only (fonts, theme, decoration)"
  local EVERY="Run everything" FIGMA="Install or update Figma Desktop" PICK="Choose specific steps…"
  local top

  if command -v gum >/dev/null 2>&1; then
    top=$(gum choose --header "What would you like to do?" "$BAR" "$LOOK" "$FIGMA" "$EVERY" "$PICK" || true)
  else
    printf '  1) %s\n  2) %s\n  3) %s\n  4) %s\n  5) %s\n' "$BAR" "$LOOK" "$FIGMA" "$EVERY" "$PICK" >&2
    local n; read -rp "> " n || true
    case "$n" in 1) top="$BAR" ;; 2) top="$LOOK" ;; 3) top="$FIGMA" ;; 4) top="$EVERY" ;; 5) top="$PICK" ;; *) top="" ;; esac
  fi

  case "$top" in
    "$BAR")   printf 'bar\n'; return 0 ;;
    "$LOOK")  _look_ids; return 0 ;;
    "$EVERY") _auto_ids; return 0 ;;
    "$FIGMA") printf 'figma\n'; return 0 ;;
    "$PICK")  ;;
    *)        return 0 ;;   # cancelled
  esac

  # Stage two: tick as many as you like. The list is everything --all would run;
  # bar and figma are not in it, both having had their own entry above -- the
  # `optin` filter below is what leaves them out, so a new top-level entry only
  # needs that note to stay out of here too.
  local menu=() s id note label
  for s in "${STEPS[@]}"; do
    IFS='|' read -r id note label _ _ <<<"$s"
    [[ $note == optin || $note == auto ]] && continue
    menu+=("$(printf '%-18s %s%s' "$id" "$label" "${note:+  ($note)}")")
  done

  local picked=()
  if command -v gum >/dev/null 2>&1; then
    # Explicit prefixes: the defaults are easy to miss, and with nothing
    # visibly ticked a multi-select reads as a single-choice list.
    mapfile -t picked < <(gum choose --no-limit --height 20 \
      --cursor-prefix "☐ " --unselected-prefix "☐ " --selected-prefix "☑ " \
      --header "Tick as many as you like — SPACE toggles, ENTER runs the batch. Order is fixed." \
      "${menu[@]}" || true)
  else
    local i=1 m
    for m in "${menu[@]}"; do printf '  %2d) %s\n' "$i" "$m" >&2; i=$((i+1)); done
    local reply; read -rp "numbers, space-separated > " reply || true
    for n in $reply; do
      [[ $n =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#menu[@]} )) && picked+=("${menu[$((n-1))]}")
    done
  fi

  (( ${#picked[@]} )) || return 0
  local p
  for p in "${picked[@]}"; do
    [[ -n ${p// } ]] || continue
    printf '%s\n' "${p%% *}"
  done
  # Recording what the machine had BEFORE is only useful if it happens on the
  # first run that changes anything, so it rides along with any selection rather
  # than being something you have to remember to tick.
  printf 'state\n'
}

SELECTED=()
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  -l|--list) list_steps; exit 0 ;;
  -a|--all)  mapfile -t SELECTED < <(_auto_ids) ;;
  --look)    mapfile -t SELECTED < <(_look_ids) ;;
  "")
    if [[ -t 0 && -t 1 ]]; then
      mapfile -t SELECTED < <(choose_steps)
      (( ${#SELECTED[@]} )) || { say "nothing selected — nothing to do"; exit 0; }
    else
      mapfile -t SELECTED < <(_auto_ids)
    fi
    ;;
  -*) printf 'unknown option: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
  *)
    for a in "$@"; do
      if _ids | grep -qxF -- "$a"; then SELECTED+=("$a")
      else printf 'unknown id: %s (see --list)\n' "$a" >&2; exit 2; fi
    done
    ;;
esac

# ── prerequisites ────────────────────────────────────────────────────────────
# Some steps are inert or actively wrong without another one. `monospace` points
# the monospace font at a family `fonts` installs, so on its own it names a font
# that is not there. `theme` asks Omarchy to set a theme `symlinks` puts in
# place. `omarchy` enables a plugin id whose directory is that same symlink.
# `keyd` defines the figma:C layer that hypr's macos-shortcuts.lua is what
# actually binds. `figma` installs the app whose launcher entry `applications`
# corrects, which is why figma.sh normally calls apply.sh itself.
#
# Rather than refuse a selection, pull the missing ones in and say so. The loop
# repeats because a prerequisite can have its own.
_needs_of() { printf '%s\n' "${STEPS[@]}" | awk -F'|' -v k="$1" '$1==k{print $5}' | tr ',' '\n'; }
_want() { local x; for x in "${SELECTED[@]}"; do [[ $x == "$1" ]] && return 0; done; return 1; }

_expand_needs() {
  local added=1 id n
  while (( added )); do
    added=0
    for id in "${SELECTED[@]}"; do
      while read -r n; do
        [[ -n $n ]] || continue
        _want "$n" && continue
        SELECTED+=("$n"); skip "also running $n — $id needs it"; added=1
      done < <(_needs_of "$id")
    done
  done
  # Explicit: the loop's status is whatever its last command left behind, and a
  # bare call under `set -e` would make that the script's fate.
  return 0
}
# Dedupe before expanding. The menu appends `state` unconditionally and you may
# also have ticked it; `apply.sh bat bat` is the same shape. The run loop is
# membership-based so duplicates were harmless, but they made the selection
# misleading to read.
_dedupe() {
  local seen=() x y dup
  for x in "${SELECTED[@]}"; do
    dup=0; for y in "${seen[@]}"; do [[ $x == "$y" ]] && { dup=1; break; }; done
    (( dup )) || seen+=("$x")
  done
  SELECTED=("${seen[@]}")
}
# hypr-reload is not something to choose -- it is how a partial run LANDS.
# A full run already has it in canonical order; a partial one would otherwise
# leave the decoration, binds and input tuning sitting in the config unread.
# Appended after selection so it is never ticked, never forgotten, and still
# runs in its canonical position (last, after keyd) rather than where it was
# added.
#
# Steps that write nothing Hyprland reads are the exception, and `bar` is the
# reason the exception exists: it writes bar.layout into shell.json, which the
# shell holds a live FileView on, so there is no config for a reload to pick up
# and reloading anyway makes the cheapest entry in the menu rebuild the whole
# Lua state for nothing. Listed by id rather than inferred, so adding one is a
# deliberate act -- and only skipped when EVERY selected step is in the list.
# tailscale is the second entry for the same reason: it writes one pref inside
# tailscaled and nothing on disk at all, so `apply.sh tailscale` rebuilding the
# whole Lua state would be pure cost. It is NOT in LOOKNFEEL either -- nothing
# about it is visible.
NO_HYPR_RELOAD=(bar tailscale)
_touches_hypr() {
  local x y hit
  for x in "${SELECTED[@]}"; do
    hit=0; for y in "${NO_HYPR_RELOAD[@]}"; do [[ $x == "$y" ]] && { hit=1; break; }; done
    (( hit )) || return 0
  done
  return 1
}
if (( ${#SELECTED[@]} )) && (( ${#SELECTED[@]} != ${#STEPS[@]} )) && _touches_hypr; then
  SELECTED+=(hypr-reload)
fi

_dedupe
_expand_needs
_dedupe

# ── run ──────────────────────────────────────────────────────────────────────
# Always in STEPS order, never the order they were picked in: several steps only
# work after an earlier one (8c reloads Hyprland against the keyd 8b restarted),
# and letting a menu reorder them would be a silent way to break a run.
# Say what the batch is before running it, in the order it will run, so a
# multi-select that was misread is obvious before anything is written.
if (( ${#SELECTED[@]} != ${#STEPS[@]} )); then
  _plan=()
  for s in "${STEPS[@]}"; do
    IFS='|' read -r id _ _ _ _ <<<"$s"
    _want "$id" && _plan+=("$id")
  done
  say "running ${#_plan[@]} step(s): ${_plan[*]}"
fi

_ran=0
for s in "${STEPS[@]}"; do
  IFS='|' read -r id sudo label action needs <<<"$s"
  _want "$id" || continue
  case "$action" in
    fn:*)  "${action#fn:}" ;;
    run:*) run ${action#run:} ;;
  esac
  _ran=$((_ran+1))
done
(( _ran == ${#STEPS[@]} )) || say "ran $_ran of ${#STEPS[@]} steps"
