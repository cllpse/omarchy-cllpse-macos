#!/bin/bash
# Chromium theme extension: light + dark, swapped live on `omarchy theme set` (sudo)
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. $HERE is bound to overrides/.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"
CT="$HERE/chromium-theme"

WORK="$STATE/chromium-theme"                       # keys + build output, never committed
SHARE=/usr/local/share/cllpse-macos/chromium-theme # what the policy points at, root-owned
WRITER=/usr/local/bin/cllpse-chromium-theme-policy
SUDOERS=/etc/sudoers.d/cllpse-chromium-theme
TEST_MASK=/etc/chromium/policies/managed/zz-cllpse-theme-test.json

if ! command -v chromium >/dev/null 2>&1; then
  skip "Chromium not installed"; exit 0
fi
if [[ ! -d /etc/chromium/policies/managed || -L /etc/chromium/policies/managed ]]; then
  skip "no Chromium managed-policy directory"; exit 0
fi
for _bin in openssl python3; do
  command -v "$_bin" >/dev/null 2>&1 || { skip "$_bin missing -- Chromium theme not built"; exit 0; }
done
# The real binary, not the wrapper: packing needs none of chromium-flags.conf.
CHROMIUM=/usr/lib/chromium/chromium
[[ -x $CHROMIUM ]] || CHROMIUM=$(command -v chromium)

# See README.md (§7.1): build and pack the two themes and the switcher.
# Each is rendered with version "0" to hash it, so the version moves only when
# its content does.
_render() { # $1 name  $2 version  $3 out-dir
  case $1 in
    light | dark) "$CT/build.py" "$REPO/omarchy-cllpse-theme-$1/colors.toml" "$1" "$2" >"$3/manifest.json" ;;
    switcher)
      cp "$CT/switcher/background.js" "$CT/switcher/schema.json" "$3/"
      python3 -c 'import json,sys; m=json.load(open(sys.argv[1])); m["version"]=sys.argv[2]; json.dump(m,sys.stdout,indent=2)' \
        "$CT/switcher/manifest.json" "$2" >"$3/manifest.json"
      ;;
  esac
}
mkdir -p "$WORK"; chmod 700 "$WORK"
for name in light dark switcher; do
  key="$WORK/$name.pem"
  if [[ ! -f $key ]]; then
    (umask 077; openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$key" 2>/dev/null)
    say "Chromium theme: generated the $name signing key ($key, never committed)"
  fi
  id=$(openssl pkey -in "$key" -pubout -outform DER 2>/dev/null | sha256sum | cut -c1-32 | tr '0-9a-f' 'a-p')

  _probe=$(mktemp -d); _render "$name" 0 "$_probe"
  sum=$(cd "$_probe" && cat $(ls | sort) | sha256sum | cut -d' ' -f1); rm -rf "$_probe"
  n=$(cat "$WORK/$name.n" 2>/dev/null || echo 0)
  changed=0
  [[ $sum == "$(cat "$WORK/$name.sum" 2>/dev/null || true)" ]] || { n=$((n + 1)); changed=1; }
  version="1.0.$n"
  if (( changed )) || [[ ! -f $WORK/$name.crx ]]; then
    rm -rf "${WORK:?}/$name" "$WORK/$name.crx"
    mkdir -p "$WORK/$name"
    _render "$name" "$version" "$WORK/$name"
    _profile=$(mktemp -d)
    "$CHROMIUM" --pack-extension="$WORK/$name" --pack-extension-key="$key" \
      --user-data-dir="$_profile" --no-message-box >/dev/null 2>&1 || true
    rm -rf "$_profile"
    [[ -f $WORK/$name.crx ]] || { echo "chromium-theme: packing $name failed" >&2; exit 1; }
    printf '%s\n' "$sum" >"$WORK/$name.sum"
    printf '%s\n' "$n" >"$WORK/$name.n"
    say "Chromium theme: packed $name $version ($id)"
  fi
  printf '%s\n' "$id" >"$WORK/$name.id"
  cat >"$WORK/$name.xml" <<EOF
<?xml version='1.0' encoding='UTF-8'?>
<gupdate xmlns='http://www.google.com/update2/response' protocol='2.0'>
  <app appid='$id'>
    <updatecheck codebase='file://$SHARE/$name.crx' version='$version' />
  </app>
</gupdate>
EOF
done
_FILES=(light.crx light.xml light.id dark.crx dark.xml dark.id switcher.crx switcher.xml switcher.id)

# See README.md (§7.2): the passwordless rule names the three invocations.
printf '%s\n' \
  "# Written by omarchy-cllpse-macos overrides/chromium-theme/chromium-theme.sh." \
  "# Lets the theme-set hook swap Chromium's theme extension without a prompt." \
  "$USER ALL=(root) NOPASSWD: $WRITER light, $WRITER dark, $WRITER off" \
  >"$WORK/sudoers"

# See README.md (§7.3): install root-owned, only what differs.
_stale=()
_new_build=0
for f in "${_FILES[@]}"; do
  if ! cmp -s "$WORK/$f" "$SHARE/$f" 2>/dev/null; then
    _stale+=("$f")
    [[ $f == *.crx && -e $SHARE/$f ]] && _new_build=1
  fi
done
cmp -s "$CT/cllpse-chromium-theme-policy" "$WRITER" 2>/dev/null || _stale+=(writer)
# The sudoers file is root-only, so test the rule rather than the file: the
# long listing prints the matched entry's tags, and !authenticate is the grant
# (the same probe Omarchy's omarchy-theme-set-browser-policy uses). Listing
# runs nothing and, under -n, prompts for nothing.
_granted() { sudo -n -l -l "$WRITER" "$1" 2>/dev/null | grep -q '!authenticate'; }
for _arg in light dark off; do _granted "$_arg" || { _stale+=(sudoers); break; }; done
[[ -e $TEST_MASK ]] && _stale+=(test-mask)

if (( ${#_stale[@]} == 0 )); then
  skip "Chromium theme already installed ($SHARE, $WRITER, $SUDOERS)"
else
  say "Chromium theme -> $SHARE, $WRITER, $SUDOERS (sudo): ${_stale[*]}"
  sudo visudo -cqf "$WORK/sudoers" ||
    { echo "chromium-theme: sudo visudo -c failed (no sudo, or the rule is invalid)" >&2; exit 1; }
  sudo install -d -m 755 -o root -g root "$SHARE"
  for f in "${_FILES[@]}"; do
    sudo install -m 644 -o root -g root "$WORK/$f" "$SHARE/$f"
  done
  sudo install -m 755 -o root -g root "$CT/cllpse-chromium-theme-policy" "$WRITER"
  sudo install -m 440 -o root -g root "$WORK/sudoers" "$SUDOERS"
  # The hand-made mask from the 2026-10-10 investigation; ours replaces it.
  if [[ -e $TEST_MASK ]]; then
    sudo rm -f -- "$TEST_MASK"
    skip "removed $TEST_MASK (zz-cllpse-macos-theme.json masks the seed now)"
  fi
fi

# See README.md (§7.4): a new build only reaches a running Chromium through a
# fresh install. The policy names the same ids, so a refresh alone changes
# nothing and the new version would wait for an update check. Unlisting
# everything uninstalls it; the hook below lists it again, Chromium installs
# the new versions, and the switcher re-applies the right theme. Fresh installs
# raise the "Installed theme" bar, once each, here rather than on a switch.
if (( _new_build )) && pgrep -x chromium >/dev/null && sudo -n "$WRITER" off 2>/dev/null; then
  chromium --refresh-platform-policy --no-startup-window &>/dev/null || true
  sleep 3
  skip "unlisted the old builds so Chromium installs the new ones"
fi

# The hook, then the current theme's mode, now.
mkdir -p ~/.config/omarchy/hooks/theme-set.d
ln -sfn "$HERE/hooks/theme-set.d/chromium-theme.sh" ~/.config/omarchy/hooks/theme-set.d/chromium-theme.sh
"$HERE/hooks/theme-set.d/chromium-theme.sh" ||
  skip "chromium-theme.sh could not apply the current mode"
