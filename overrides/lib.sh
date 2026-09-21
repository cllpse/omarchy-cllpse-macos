#!/bin/bash
# Shared scaffolding for the per-override scripts in overrides/*/.
#
# Every override script sources this, so each one is runnable on its own
# (`overrides/cursor/cursor.sh`) as well as from apply.sh, which sources this
# once and then calls them in order. Sourcing twice is harmless.
#
# What a caller gets: OVERRIDES, REPO, MARK, and say/skip/backup/sync_fenced.
# A script that needs its OWN directory computes it itself -- $HERE here is
# this file's directory, which is overrides/, not the caller's.

[[ -n ${_CLLPSE_LIB_LOADED:-} ]] && return 0
_CLLPSE_LIB_LOADED=1

OVERRIDES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$OVERRIDES")"
MARK='cllpse-macos overrides'

# Where revert.sh looks for what this machine had BEFORE apply.sh first ran.
# Shared, not step-0-local: the chromium, cursor and omarchy overrides each
# record their own prior value through record_prior below, and each has to be
# runnable on its own, so neither the path nor the helper can live in apply.sh.
STATE="$HOME/.local/state/cllpse-macos"
mkdir -p "$STATE"

say()  { printf '\033[34m▸\033[0m %s\n' "$*"; }
skip() { printf '  \033[2m– %s\033[0m\n' "$*"; }
backup() { [[ -s $1 && ! -e $1.pre-cllpse ]] && { cp "$1" "$1.pre-cllpse"; skip "backed up $1 -> $1.pre-cllpse"; } || true; }

# Current contents of the fenced block in $3 — the lines between, but not
# including, the $1/$2 marker lines.
# NB: the awk variables are openm/closem, not open/close — `close` is a gawk
# builtin and `-v close=...` is a fatal error, which silently emptied the target.
fenced_body() { # $1 open-marker  $2 close-marker  $3 target
  awk -v openm="$1" -v closem="$2" '$0 == openm { f = 1; next } $0 == closem { f = 0 } f' "$3"
}

# Sync a snippet into $1 wrapped in fence markers: replace the block in place if
# it's already there, append it if it isn't. Replacing (rather than the older
# append-once) is what makes a re-run pick up edits to the snippet — otherwise an
# already-applied machine silently keeps the version it first installed.
# Comment leader matches the target: "--" for *.lua, "#" otherwise — a "#" line
# is a syntax error in Lua.
# $3 (optional) distinguishes a second fenced block in a file that already
# carries one under the plain $MARK — e.g. bindings.lua fences in both
# window-switcher-bindings.lua (no $3) and keybind-unbinds.lua ($3=keybinds).
sync_fenced() { # $1 target  $2 snippet-file  $3 marker-suffix
  local mark="$MARK"; [[ -n ${3:-} ]] && mark="$MARK: $3"
  local c='#'; [[ $1 == *.lua ]] && c='--'
  local open="$c >>> $mark >>>" close="$c <<< $mark <<<"
  [[ -e $1 ]] || : >"$1"

  # Match the open marker as a WHOLE LINE, not $mark as a substring. $mark for a
  # plain block ("cllpse-macos overrides") is a prefix of every suffixed one
  # ("cllpse-macos overrides: keybinds"), so a substring test says "the block is
  # already here" when only a SUFFIXED block is. The awk rewrite below then finds
  # no line equal to $open, passes the file through unchanged, and — the output
  # being non-empty — reports success. Net effect: the block is silently never
  # installed. bindings.lua carries four blocks, so it is the file this reaches.
  # The current call order (plain before suffixed) hides it on a fresh machine;
  # deleting the plain block by hand and re-running is enough to surface it.
  #
  # -e is REQUIRED, not stylistic: $open for a .lua target starts with "--",
  # which grep parses as end-of-options (or as a bad option) rather than as a
  # pattern, and the test then never matches. That failure appends a duplicate
  # block on every run instead of updating in place — and it lands only on .lua
  # files, i.e. exactly the ones this guard exists for. The old substring test
  # dodged it by accident: $mark carries no leading dash.
  if ! grep -qxF -e "$open" "$1" 2>/dev/null; then
    { printf '\n%s\n' "$open"; cat "$2"; printf '%s\n' "$close"; } >>"$1"
    say "appended overrides block to $1"
    return
  fi

  if diff -q <(fenced_body "$open" "$close" "$1") "$2" >/dev/null 2>&1; then
    skip "$1 overrides block already up to date"
    return
  fi

  local tmp; tmp=$(mktemp)
  if ! awk -v openm="$open" -v closem="$close" -v snip="$2" '
    $0 == openm  { print; while ((getline line < snip) > 0) print line; close(snip); f = 1; next }
    $0 == closem { f = 0; print; next }
    !f           { print }
  ' "$1" >"$tmp"; then
    rm -f "$tmp"; printf 'error: could not rewrite %s — left untouched\n' "$1" >&2; return 1
  fi
  # Never let a failed/empty rewrite clobber a real config file.
  if [[ ! -s $tmp ]]; then
    rm -f "$tmp"; printf 'error: refusing to write empty %s — left untouched\n' "$1" >&2; return 1
  fi
  # Write through the original file rather than mv, to keep its mode and inode.
  cat "$tmp" >"$1"
  rm -f "$tmp"
  say "updated overrides block in $1"
}

# Record a pre-existing value for revert.sh, once.
#   $1 state-file  $2 value  $3 value-to-refuse
# Written once and never overwritten, so re-running cannot clobber the original
# with our own values; and a value that is already ours is refused outright,
# since recording it would quietly turn revert into a no-op.
record_prior() {
  [[ -e $1 ]] && return 0                      # first apply wins, never overwrite
  [[ -z $2 || $2 == "$3" ]] && return 0         # nothing to record, or it's ours
  printf '%s\n' "$2" >"$1"
  skip "recorded pre-existing $(basename "$1"): $2"
}
