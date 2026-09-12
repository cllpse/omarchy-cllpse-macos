# Shell extras for cllpse-macos. Appended to ~/.bashrc by overrides/apply.sh.

# fzf, coloured from the ACTIVE Omarchy palette instead of pinned hex, so the
# picker follows `omarchy theme set` -- each new shell reads whatever theme is
# current. Layout flags (rounded borders, no prompt/pointer/separator/scrollbar,
# zero padding, info on the right) are fixed; only the colours are derived.
_cllpse_fzf_colors() {
  local toml="$HOME/.local/state/omarchy/current/theme/colors.toml"
  [[ -r $toml ]] || return 1

  local -A c=()
  local line k v
  # One pass, in the shell itself. This runs on EVERY interactive shell, and the
  # awk it replaces cost a fork+exec plus a subshell for the process
  # substitution: measured 2.4ms against 1.4ms here, for byte-identical output
  # on both themes' colors.toml and on the no-theme fallback path. Takes the
  # first quoted value on each line, so a trailing `# comment` is ignored; a
  # line with no quoted value is skipped, the way awk's match() guard did.
  #
  # It also fixes an edge case the awk got wrong: awk took the key as $1, the
  # first WHITESPACE-separated field, so an unspaced `background="#222222"`
  # made the key the entire `background="#222222"` token. The real key then
  # looked unset, and the guard below dropped the whole palette to the ANSI
  # fallback. Omarchy writes the spaced form, so no shipped file hit this.
  while IFS= read -r line || [[ -n $line ]]; do
    [[ $line == *=* ]] || continue
    k=${line%%=*}; k=${k//[[:space:]]/}
    case $k in
      mode|foreground|dark_foreground|accent|background|dark_background|darker_background|lighter_background) ;;
      *) continue ;;
    esac
    v=${line#*=}
    [[ $v == *\"*\"* ]] || continue
    v=${v#*\"}; v=${v%%\"*}
    c[$k]=$v
  done < "$toml"

  # Without these three there is no palette worth using; fall back to ANSI.
  [[ -n ${c[foreground]:-} && -n ${c[background]:-} && -n ${c[accent]:-} ]] || return 1

  # White is the lightest surface macOS has, so in light mode
  # lighter_background collapses onto background. Step the other way there for
  # the selected row and the border -- the same choice the theme's
  # shell.launcher.toml makes for its selected-background.
  local sel border
  if [[ ${c[mode]:-dark} == light ]]; then
    sel=${c[dark_background]:-${c[background]}}
    border=${c[darker_background]:-${c[background]}}
  else
    sel=${c[lighter_background]:-${c[background]}}
    border=${c[lighter_background]:-${c[background]}}
  fi

  local fg=${c[foreground]} bg=${c[background]} ac=${c[accent]}
  local mut=${c[dark_foreground]:-$fg}

  # Role assignment mirrors the hand-tuned original: plain text and the
  # non-accent chrome take `foreground`, everything that marks the current
  # selection takes `accent`, and secondary text takes the muted label colour.
  printf '%s' \
    "--color=fg:$fg,fg+:$ac,bg:$bg,bg+:$sel " \
    "--color=hl:$fg,hl+:$ac,info:$mut,marker:$fg " \
    "--color=prompt:$fg,spinner:$fg,pointer:$ac,header:$mut " \
    "--color=gutter:$bg,border:$border,label:$fg,query:$ac"
}

# Terminal-palette fallback: fzf --color takes -1 (terminal default) or a colour
# NUMBER, never a name. 4=blue, 2=green, 8=bright-black.
_cllpse_fzf_fallback='--color=fg:-1,bg:-1,fg+:-1,bg+:-1,hl:4,hl+:4,info:4,prompt:4,pointer:4,spinner:4,header:4,marker:2,border:8'

FZF_DEFAULT_OPTS="$(_cllpse_fzf_colors || printf '%s' "$_cllpse_fzf_fallback")"
FZF_DEFAULT_OPTS+=' --border=rounded --border-label= --preview-window=border-rounded'
FZF_DEFAULT_OPTS+=' --padding=0 --margin=0 --prompt= --marker= --pointer= --separator= --scrollbar= --info=right'
export FZF_DEFAULT_OPTS
unset -f _cllpse_fzf_colors
unset _cllpse_fzf_fallback

# lsd for ls (icons + colour, inherits the same ANSI palette). Guarded so a
# machine without lsd installed keeps a working `ls` instead of a broken alias.
command -v lsd >/dev/null 2>&1 && alias ls="lsd -a"

# lsd's built-in filetype palette is a fixed 256-colour table, so none of it
# follows `omarchy theme set` the way the terminal's own text does. Pointing
# every filetype at a basic ANSI slot (0-15) instead makes it track whatever
# each theme's terminal template (alacritty.toml.tpl etc.) currently paints
# that slot -- same trick the fzf ANSI fallback above uses, and the
# ../lsd/colors.yaml override (metadata columns: user/group/size/date/etc.,
# which lsd reads from its own config rather than LS_COLORS) does the rest.
# Bold/underline styling and the colour groupings (pipe+socket, block+char
# device) match lsd's own defaults; only the indices moved off 256-colour.
export LS_COLORS="${LS_COLORS:+$LS_COLORS:}di=01;34:ln=04;34:ex=01;32:pi=01;36:so=01;36:bd=01;33:cd=01;33:or=01;31:mi=01;31"

# Claude Code requests terminal mouse reporting for its own click/hover/scroll
# support. Tried CLAUDE_CODE_DISABLE_MOUSE_CLICKS=1 to let a plain click-drag
# fall through to Ghostty's native selection while keeping wheel-scroll --
# confirmed NOT to work: xterm-style mouse reporting is all-or-nothing at the
# protocol level (no "wheel events only" mode), so Claude still enables full
# reporting to get scroll, Ghostty still sees it as active, and a plain drag
# still doesn't select -- it only cost Claude's own click handling too. Real
# fix is Shift+drag (see mouse-shift-capture above): it's the standard
# terminal-wide escape hatch for exactly this conflict (same mechanism tmux/
# vim mouse-mode users rely on), guaranteed to make a native selection no
# matter what the app wants, without touching scroll or Claude's own mouse UI.

# Tool aliases. Each is guarded on the tool the way the `ls` alias above is:
# apply.sh installs no packages, so an unguarded alias on a machine that lacks
# the tool replaces a working command with a broken one. overrides/README.md's
# "Before running apply.sh" lists where each of these comes from.

# Microsoft Edit as `edit`.
command -v msedit >/dev/null 2>&1 && alias edit="msedit"

# `diff` -> `git diff`, so diffs go through the hunk pager set in
# ../git/pager.conf. This shadows diffutils' /usr/bin/diff in INTERACTIVE shells
# only: bash does not expand aliases in non-interactive shells (expand_aliases is
# off), so apply.sh's own `diff -q` and every other script still reach the real
# binary, and `command diff a b` does too.
command -v git >/dev/null 2>&1 && alias diff="git diff"

# gh-dash TUI as `dash`. gh-dash is a gh EXTENSION, not a binary on PATH, so
# `command -v` can't see it. Test for the extension directory rather than asking
# gh: `gh extension list` measured 34ms here, and this runs on every interactive
# shell -- the same reason the fzf palette above is parsed in-shell instead of
# shelling out to awk.
[[ -d "${XDG_DATA_HOME:-$HOME/.local/share}/gh/extensions/gh-dash" ]] && alias dash="gh dash"

# ytm-player, with a keyring workaround. yt-dlp maps XDG_CURRENT_DESKTOP to a
# Chromium cookie-decryption backend, and its table (cookies.py,
# _get_linux_desktop_environment) knows GNOME/KDE/XFCE/LXQt/Unity/Deepin/
# Pantheon/UKUI/X-Cinnamon -- not Hyprland. An unknown value falls through to
# OTHER, _choose_linux_keyring maps OTHER to BASICTEXT, and BASICTEXT returns
# no key at all because it assumes cookies are v10 (unencrypted). Chromium here
# runs --password-store=gnome-libsecret, so its cookies are v11 and every one
# fails: "cannot decrypt v11 cookies: no key found", 0 of 713 extracted.
#
# That breaks more than `ytm setup`. ytm's own try_auto_refresh() renews an
# expiring YouTube session by re-extracting browser cookies through this same
# yt-dlp path, so on Hyprland a renewal can NEVER succeed and every expiry
# becomes a manual re-signin. Appending GNOME fixes both: the variable is a
# colon-separated priority list, yt-dlp scans every part, and Hyprland stays
# first for everything else that reads it -- portals included. Scoped to this
# one process on purpose, NOT environment.d, which would hand the whole session
# a GNOME identity to satisfy one TUI.
#
# Needs python-secretstorage (extra) for the D-Bus call to
# org.freedesktop.secrets; without it the keyring is chosen but unreadable.
if command -v ytm >/dev/null 2>&1; then
  ytm() { XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-Hyprland}:GNOME" command ytm "$@"; }
fi
