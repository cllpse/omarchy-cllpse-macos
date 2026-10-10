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

# See README.md (§7.1): build and pack each mode.
mkdir -p "$WORK"; chmod 700 "$WORK"
for mode in light dark; do
  toml="$REPO/omarchy-cllpse-theme-$mode/colors.toml"
  key="$WORK/$mode.pem"
  if [[ ! -f $key ]]; then
    (umask 077; openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$key" 2>/dev/null)
    say "Chromium theme: generated the $mode signing key ($key, never committed)"
  fi
  id=$(openssl pkey -in "$key" -pubout -outform DER 2>/dev/null | sha256sum | cut -c1-32 | tr '0-9a-f' 'a-p')

  # The version moves only when the colours do: hash a render with a fixed one.
  sum=$("$CT/build.py" "$toml" "$mode" 0 | sha256sum | cut -d' ' -f1)
  n=$(cat "$WORK/$mode.n" 2>/dev/null || echo 0)
  changed=0
  [[ $sum == "$(cat "$WORK/$mode.sum" 2>/dev/null || true)" ]] || { n=$((n + 1)); changed=1; }
  version="1.0.$n"
  if (( changed )) || [[ ! -f $WORK/$mode.crx ]]; then
    rm -rf "${WORK:?}/$mode" "$WORK/$mode.crx"
    mkdir -p "$WORK/$mode"
    "$CT/build.py" "$toml" "$mode" "$version" >"$WORK/$mode/manifest.json"
    _profile=$(mktemp -d)
    "$CHROMIUM" --pack-extension="$WORK/$mode" --pack-extension-key="$key" \
      --user-data-dir="$_profile" --no-message-box >/dev/null 2>&1 || true
    rm -rf "$_profile"
    [[ -f $WORK/$mode.crx ]] || { echo "chromium-theme: packing $mode failed" >&2; exit 1; }
    printf '%s\n' "$sum" >"$WORK/$mode.sum"
    printf '%s\n' "$n" >"$WORK/$mode.n"
    say "Chromium theme: packed $mode $version ($id)"
  fi
  printf '%s\n' "$id" >"$WORK/$mode.id"
  cat >"$WORK/$mode.xml" <<EOF
<?xml version='1.0' encoding='UTF-8'?>
<gupdate xmlns='http://www.google.com/update2/response' protocol='2.0'>
  <app appid='$id'>
    <updatecheck codebase='file://$SHARE/$mode.crx' version='$version' />
  </app>
</gupdate>
EOF
done

# See README.md (§7.2): the passwordless rule names the four invocations.
printf '%s\n' \
  "# Written by omarchy-cllpse-macos overrides/chromium-theme/chromium-theme.sh." \
  "# Lets the theme-set hook swap Chromium's theme extension without a prompt." \
  "$USER ALL=(root) NOPASSWD: $WRITER light, $WRITER dark, $WRITER both, $WRITER off" \
  >"$WORK/sudoers"

# See README.md (§7.3): install root-owned, only what differs.
_stale=()
_new_build=0
for f in light.crx light.xml light.id dark.crx dark.xml dark.id; do
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
for _arg in light dark both off; do _granted "$_arg" || { _stale+=(sudoers); break; }; done
[[ -e $TEST_MASK ]] && _stale+=(test-mask)

if (( ${#_stale[@]} == 0 )); then
  skip "Chromium theme already installed ($SHARE, $WRITER, $SUDOERS)"
else
  say "Chromium theme -> $SHARE, $WRITER, $SUDOERS (sudo): ${_stale[*]}"
  sudo visudo -cqf "$WORK/sudoers" ||
    { echo "chromium-theme: sudo visudo -c failed (no sudo, or the rule is invalid)" >&2; exit 1; }
  sudo install -d -m 755 -o root -g root "$SHARE"
  for f in light.crx light.xml light.id dark.crx dark.xml dark.id; do
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

# See README.md (§7.4, §7.5): get both themes installed in the running
# Chromium before the hook forces one. A swap re-enables an installed theme,
# which raises no "Installed theme" bar; only a fresh install does, so these
# installs (and their bars) happen here, once, rather than on a theme switch.
#   - A new build first goes through `off`: the policy names the same ids, so a
#     refresh alone changes nothing and the new version would wait for an
#     update check. Unlisting uninstalls; `both` then installs the new version.
#   - `both` lists the two themes as installed-but-optional. Each install applies
#     its theme and disables the one before, which policy allows for optional.
_refresh() { chromium --refresh-platform-policy --no-startup-window &>/dev/null || true; }
_installed() { compgen -G "$HOME/.config/chromium/*/Extensions/$1" >/dev/null; }
if (( ${#_stale[@]} )) && pgrep -x chromium >/dev/null; then
  if (( _new_build )) && sudo -n "$WRITER" off 2>/dev/null; then
    _refresh; sleep 3
    skip "unlisted the old builds so Chromium installs the new ones"
  fi
  if sudo -n "$WRITER" both 2>/dev/null; then
    _refresh
    for _ in $(seq 1 40); do
      _installed "$(<"$WORK/light.id")" && _installed "$(<"$WORK/dark.id")" && break
      sleep 0.5
    done
    sleep 2
    skip "both themes installed in Chromium (an \"Installed theme\" bar now is expected, once)"
  fi
fi

# The hook, then the current theme's mode, now.
mkdir -p ~/.config/omarchy/hooks/theme-set.d
ln -sfn "$HERE/hooks/theme-set.d/chromium-theme.sh" ~/.config/omarchy/hooks/theme-set.d/chromium-theme.sh
"$HERE/hooks/theme-set.d/chromium-theme.sh" ||
  skip "chromium-theme.sh could not apply the current mode"
