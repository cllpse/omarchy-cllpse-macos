# Shell extras for cllpse-macos. Appended to ~/.bashrc by overrides/apply.sh.

# fzf, coloured from the ACTIVE Omarchy palette instead of pinned hex, so the
# picker follows `omarchy theme set` -- each new shell reads whatever theme is
# current. Layout flags (rounded borders, no prompt/pointer/separator/scrollbar,
# zero padding, info on the right) are fixed; only the colours are derived.
_cllpse_fzf_colors() {
  local toml="$HOME/.local/state/omarchy/current/theme/colors.toml"
  [[ -r $toml ]] || return 1

  local -A c=()
  local k v
  # One pass: pull the palette keys we need, taking the first quoted value on
  # each line so trailing `# comments` are ignored.
  while read -r k v; do c[$k]=$v; done < <(
    awk '
      /^[[:space:]]*(mode|foreground|dark_foreground|accent|background|dark_background|darker_background|lighter_background)[[:space:]]*=/ {
        key = $1
        if (match($0, /"[^"]*"/)) print key, substr($0, RSTART + 1, RLENGTH - 2)
      }' "$toml"
  )

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
