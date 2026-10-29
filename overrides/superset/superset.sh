#!/bin/bash
# Superset: no opaque square behind seven file icons in the Changes tree
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh:
#   superset.sh           patch app.asar (idempotent)
#   superset.sh --revert  put the stray path back (../revert.sh calls this)
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

ASAR="$HOME/Applications/superset/resources/app.asar"

if [[ ! -f $ASAR ]]; then
  skip "Superset not found ($ASAR) — skipped its icon fix"
  exit 0
fi

mode=apply
[[ ${1:-} == --revert ]] && mode=revert

# The whole job, in python because the file is 1 GB of binary. -I: no
# environment or cwd on the import path. Prints "<patched> <already> <total>"
# for the direction asked, or exits 1 and says why.
#
# Same-length swap: the asar header holds every file's offset and size, so a
# file that changes length means a repack. A comment of the stray path's own
# length changes nothing the header says.
patch() { # $1 file to patch (a copy), $2 apply|revert
  python3 -I - "$1" "$2" <<'PY'
import mmap, re, sys
path, mode = sys.argv[1], sys.argv[2]
STRAY = b'<path d="M0 0h24v24H0z"/>'
MARK = b'<!--cllpse stray path -->'
assert len(STRAY) == len(MARK), (len(STRAY), len(MARK))
# Only an icon whose root is fill="none": there the path is invisible as an
# <img> and wrong only once the root tag is stripped. Anything else keeps it.
HEAD = rb'(<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="[^"]*">)'
src, dst = (STRAY, MARK) if mode == 'apply' else (MARK, STRAY)
with open(path, 'r+b') as f, mmap.mmap(f.fileno(), 0) as m:
    todo = [x.end() - len(src) for x in re.finditer(HEAD + re.escape(src), m)]
    done = len(re.findall(HEAD + re.escape(dst), m))
    for at in todo:
        m[at:at + len(dst)] = dst
    m.flush()
print(len(todo), done)
PY
}

# A running Superset has the asar open and reads from it by offset, so it is
# never written in place (fonts/ learned this when Ghostty died): a copy, which
# on Btrfs shares the extents until the patch touches them, then a rename. The
# old inode stays valid for whoever has it open, and a restart picks the new one.
tmp=$(mktemp "$ASAR.XXXXXX")
trap 'rm -f "$tmp"' EXIT
cp --reflink=auto --preserve=mode "$ASAR" "$tmp"
read -r changed already < <(patch "$tmp" "$mode")

case $mode in
  apply)
    if (( changed > 0 )); then
      mv -f "$tmp" "$ASAR"
      say "Superset -> $changed stray icon paths blanked in app.asar ($already already were)"
      if pgrep -xu "$USER" superset >/dev/null; then skip "restart Superset to see it"; fi
    elif (( already > 0 )); then
      skip "Superset: already patched ($already)"
    else
      skip "Superset: no stray icon path found — fixed upstream, or the icons moved; superset/README.md"
    fi ;;
  revert)
    if (( changed > 0 )); then
      mv -f "$tmp" "$ASAR"
      say "Superset: $changed stray icon paths put back"
    else
      skip "Superset: nothing of ours in app.asar"
    fi ;;
esac
