#!/bin/bash
# Superset: the shortcuts listed in unbound.txt, unassigned
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh:
#   superset-hotkeys.sh           unbind every id in unbound.txt (idempotent)
#   superset-hotkeys.sh --revert  give those ids back their defaults
# Needs Superset closed: it holds the store's lock, and rewrites its state on exit.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB="$HOME/.config/Superset/Partitions/superset/Local Storage/leveldb"
LIB="$HOME/.cache/cllpse-macos/superset-hotkeys"

if [[ ! -d $DB ]]; then
  skip "Superset has no localStorage yet ($DB) — skipped its shortcuts; run it once first"
  exit 0
fi

mode=apply
[[ ${1:-} == --revert ]] && mode=revert

# A leveldb needs a native module. Installed once, outside the repo.
if [[ ! -d $LIB/node_modules/classic-level ]]; then
  if ! command -v npm >/dev/null; then
    skip "Superset shortcuts: npm not found, cannot fetch classic-level"
    exit 0
  fi
  mkdir -p "$LIB"
  say "Superset shortcuts: fetching classic-level into $LIB"
  npm install --prefix "$LIB" --no-audit --no-fund --silent classic-level
fi

# The writer is the lock test: leveldb refuses to open a store another process
# holds. pgrep on "superset" would not do, since the pty daemon and the host
# service keep that name after the app window is gone.
set +e
out=$(node "$HERE/overrides.cjs" "$LIB" "$DB" "$HERE/unbound.txt" "$mode" 2>&1)
rc=$?
set -e
case $rc in
  0) ;;
  3) skip "Superset is running — quit it, then run: overrides/apply.sh superset-hotkeys"; exit 0 ;;
  *) printf '%s\n' "$out" >&2; exit 1 ;;
esac

read -r changed already <<<"$out"
case $mode in
  apply)
    if (( changed > 0 )); then
      say "Superset -> $changed shortcuts unassigned ($already already were)"
    else
      skip "Superset shortcuts: already unassigned ($already)"
    fi ;;
  revert)
    if (( changed > 0 )); then
      say "Superset: $changed shortcuts back on their defaults"
    else
      skip "Superset: none of our shortcut overrides to remove"
    fi ;;
esac
